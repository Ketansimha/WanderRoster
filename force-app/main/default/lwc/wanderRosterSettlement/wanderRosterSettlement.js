import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getDashboard from '@salesforce/apex/ExpenseSettlementController.getDashboard';
import getExpenseItems from '@salesforce/apex/ExpenseSettlementController.getExpenseItems';
import submitExpenses from '@salesforce/apex/ExpenseSettlementController.submitExpenses';
import financeDecision from '@salesforce/apex/ExpenseSettlementController.financeDecision';
import markSettled from '@salesforce/apex/ExpenseSettlementController.markSettled';
import evaluateReport from '@salesforce/apex/ExpensePolicyChecker.evaluateReport';

export default class WanderRosterSettlement extends LightningElement {
    isLoading = false;
    isLoadingItems = false;
    isSaving = false;

    errorMessage = '';
    reports = [];
    travelRequests = [];
    financeQueue = [];
    expenseItems = [];
    selectedReportId = null;
    selectedTravelRequestId = null;

    totalReports = 0;
    pendingReports = 0;
    approvedReports = 0;
    totalExpenses = 0;

    financeComments = '';
    _itemsRequestId = 0;

    connectedCallback() {
        this.handleRefresh();
    }

    // MANAGER-APPROVED TRAVEL REQUESTS

    get managerApprovedTravelRequests() {
        return this.travelRequests || [];
    }

    // FINANCE QUEUE: ONE ROW PER APPROVED TRAVEL REQUEST

    get managerApprovedReports() {
        return this.financeQueue || [];
    }

    get selectedQueueItem() {
        return this.managerApprovedReports.find(
            item => item.travelRequestId === this.selectedTravelRequestId
        ) || null;
    }

    get selectedReport() {
        return this.selectedQueueItem?.report || null;
    }

    get hasSelectedReport() {
        return Boolean(this.selectedReport);
    }

    get hasSelectedTravelRequest() {
        return Boolean(this.selectedQueueItem);
    }

    get hasReports() {
        return this.managerApprovedReports.length > 0;
    }

    get showEmptyReports() {
        return !this.isLoading &&
            !this.errorMessage &&
            this.managerApprovedReports.length === 0;
    }

    get hasExpenseItems() {
        return this.expenseItems.length > 0;
    }

    get showEmptyItems() {
        return !this.isLoadingItems &&
            this.expenseItems.length === 0;
    }

    get paidReports() {
        return this.managerApprovedReports.filter(
            item => item.report?.Expense_Status__c === 'Paid' || item.report?.Expense_Status__c === 'Reimbursed'
        ).length;
    }

    get reviewRequiredReports() {
        return this.managerApprovedReports.filter(item =>
            item.report && [
                'Policy Violation',
                'Requires Review',
                'Not Checked'
            ].includes(item.report.Policy_Status__c)
        ).length;
    }

    get missingReceiptCount() {
        return this.expenseItems.filter(item =>
            ['Missing', 'Awaiting Receipt'].includes(
                item.Receipt_Status__c
            )
        ).length;
    }

    get lateReceiptCount() {
        return this.expenseItems.filter(
            item => item.Receipt_Status__c === 'Submitted Late'
        ).length;
    }

    // FINANCE DECISION VALIDATION

    get isDecisionDisabled() {
        if (!this.selectedReport || this.isSaving) {
            return true;
        }

        return ![
            'Submitted',
            'Pending Approval'
        ].includes(this.selectedReport.Expense_Status__c);
    }

    get isApproveDisabled() {
        return this.isDecisionDisabled;
    }

    get isRejectDisabled() {
        return this.isDecisionDisabled;
    }

    get decisionDisabledReason() {
        if (!this.selectedQueueItem) {
            return 'Select a travel request first.';
        }

        if (!this.selectedReport) {
            return 'No expense report is linked to this travel request yet.';
        }

        if (this.isSaving) {
            return 'Please wait for the current operation to finish.';
        }

        const status = this.selectedReport.Expense_Status__c;

        if (status === 'Approved') {
            return 'This report is approved. Mark it Paid only after reimbursement.';
        }

        if (status === 'Paid' || status === 'Reimbursed') {
            return 'This report has already been marked Paid.';
        }

        if (status === 'Rejected') {
            return 'This report was rejected.';
        }

        if (!['Submitted', 'Pending Approval', 'Under Review'].includes(status)) {
            return `Report status is "${status || 'Not set'}". Submit eligible Draft expenses before Finance review.`;
        }

        return '';
    }

    get isSubmitExpensesDisabled() {
        if (!this.selectedReport || this.isSaving || this.isLoadingItems) {
            return true;
        }

        return this.selectedReport.Expense_Status__c !== 'Draft' ||
            this.selectedReport.Travel_Request__r?.Travel_Status__c !== 'Approved';
    }

    get isMarkPaidDisabled() {
        return !this.selectedReport ||
            this.isSaving ||
            this.selectedReport.Expense_Status__c !== 'Approved';
    }

    // REFRESH DASHBOARD AND BUILD QUEUE

    async handleRefresh() {
        if (this.isLoading) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        try {
            const data = await getDashboard();

            this.totalReports = data?.totalReports ?? 0;
            this.pendingReports = data?.pendingReports ?? 0;
            this.approvedReports = data?.approvedReports ?? 0;
            this.totalExpenses = data?.totalExpenses ?? 0;

            this.travelRequests = (data?.approvedTravelRequests || []).map(travel => {
                const estimatedCost =
                    travel.Estimated_Total__c ??
                    (travel.Travel_Cost__c || 0) +
                    (travel.Hotel_Cost__c || 0) +
                    (travel.Other_Estimated_Cost__c || 0);

                return {
                    ...travel,
                    travelRequestId: travel.Id,
                    travelRequestName: travel.Name,
                    travelRoute: [
                        travel.Origin__c,
                        travel.Destination__c
                    ].filter(Boolean).join(' → ') || 'Not available',
                    travelStartDate: travel.Start_Date__c || null,
                    travelEndDate: travel.End_Date__c || null,
                    estimatedTravelCost: estimatedCost,
                    displayEstimatedTravelCost: estimatedCost,
                    hasExpenseReport: false,
                    queueStatus: 'Awaiting expense report',
                    queueStatusClass: 'status status-pending',
                    report: null
                };
            });

            this.reports = (data?.reports || []).map(report => {
                const travel = report.Travel_Request__r;
                const riskScore = report.AI_Risk_Score__c;
                const estimatedCost =
                    travel?.Estimated_Total__c ??
                    (travel
                        ? (travel.Travel_Cost__c || 0) +
                          (travel.Hotel_Cost__c || 0) +
                          (travel.Other_Estimated_Cost__c || 0)
                        : null);

                return {
                    ...report,
                    employeeName: report.Employee__r?.Name || 'Not available',
                    travelRequestName: travel?.Name || 'Not available',
                    travelRoute: [
                        travel?.Origin__c,
                        travel?.Destination__c
                    ].filter(Boolean).join(' → ') || 'Not available',
                    travelStartDate: travel?.Start_Date__c || null,
                    travelEndDate: travel?.End_Date__c || null,
                    estimatedTravelCost: estimatedCost,
                    displayEstimatedTravelCost: estimatedCost,
                    hasRiskScore: riskScore !== null && riskScore !== undefined,
                    displayRiskScore: riskScore ?? 'Not scored',
                    displayPolicyStatus: report.Policy_Status__c || 'Not Checked',
                    displayStatus: report.Expense_Status__c || 'Not set',
                    displayAIExplanation: report.AI_Explanation__c || 'No explanation recorded.',
                    statusClass: this.getStatusClass(report.Expense_Status__c)
                };
            });

            // Match each approved travel request with its expense report.
            // Requests without reports remain in the Finance queue.
            const reportByTravelId = new Map();

            this.reports.forEach(report => {
                if (report.Travel_Request__c &&
                    !reportByTravelId.has(report.Travel_Request__c)) {
                    reportByTravelId.set(report.Travel_Request__c, report);
                }
            });

            this.financeQueue = this.travelRequests.map(travel => {
                const report = reportByTravelId.get(travel.Id) || null;

                return {
                    ...travel,
                    report,
                    hasExpenseReport: Boolean(report),
                    employeeName: report?.employeeName || 'Employee not identified',
                    expenseReportName: report?.Name || 'No expense report',
                    expenseAmount: report?.Total_Amount__c ?? null,
                    expenseStatus: report?.Expense_Status__c || 'Not submitted',
                    policyStatus: report?.Policy_Status__c || travel.Policy_Status__c || 'Not Checked',
                    riskScore: report?.AI_Risk_Score__c ?? travel.AI_Risk_Score__c,
                    queueStatus: report
                        ? (report.Expense_Status__c || 'Not submitted')
                        : 'Awaiting expense report',
                    queueStatusClass: report
                        ? this.getStatusClass(report.Expense_Status__c)
                        : 'status status-pending'
                };
            });

            if (this.selectedTravelRequestId) {
                const selected = this.selectedQueueItem;

                if (selected?.report) {
                    this.selectedReportId = selected.report.Id;

                    if (!this.isSaving) {
                        this.financeComments = selected.report.Manager_Comments__c || '';
                    }

                    await this.loadItems(selected.report.Id);
                } else {
                    this.selectedReportId = null;
                    this.expenseItems = [];
                    this.financeComments = '';
                    this._itemsRequestId++;
                    this.isLoadingItems = false;
                }
            }
        } catch (error) {
            this.errorMessage = this.getError(error);
            this.showToast('Unable to load Finance queue', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // SELECT A TRAVEL REQUEST IN THE QUEUE

    async handleSelectReport(event) {
        const travelRequestId = event.currentTarget.dataset.id;

        if (!travelRequestId) {
            this.showToast('Selection failed', 'Travel request ID was not found.', 'error');
            return;
        }

        const queueItem = this.managerApprovedReports.find(
            item => item.travelRequestId === travelRequestId
        );

        if (!queueItem) {
            this.showToast('Request unavailable', 'This approved travel request is not in the Finance queue.', 'warning');
            return;
        }

        this.selectedTravelRequestId = travelRequestId;
        this.selectedReportId = queueItem.report?.Id || null;
        this.expenseItems = [];
        this.financeComments = queueItem.report?.Manager_Comments__c || '';
        this._itemsRequestId++;

        if (!queueItem.report) {
            this.isLoadingItems = false;
            this.showToast(
                'Expense report required',
                'The trip is visible to Finance, but reimbursement cannot be reviewed until an expense report is submitted.',
                'info'
            );
            return;
        }

        await this.loadItems(queueItem.report.Id);
    }

    // LOAD EXPENSE ITEMS

    async loadItems(reportId) {
        const requestId = ++this._itemsRequestId;

        if (!reportId) {
            this.expenseItems = [];
            this.isLoadingItems = false;
            return;
        }

        this.isLoadingItems = true;

        try {
            const items = await getExpenseItems({ reportId });

            if (requestId !== this._itemsRequestId ||
                reportId !== this.selectedReportId) {
                return;
            }

            this.expenseItems = (items || []).map(item => ({
                ...item,
                displayReceiptStatus: item.Receipt_Status__c || 'Not recorded',
                displayVerificationStatus: item.Verification_Status__c || 'Not checked',
                noFlags: !item.Possible_Duplicate__c && !item.Policy_Violation__c
            }));
        } catch (error) {
            if (requestId !== this._itemsRequestId ||
                reportId !== this.selectedReportId) {
                return;
            }

            this.expenseItems = [];
            this.showToast('Unable to load expense items', this.getError(error), 'error');
        } finally {
            if (requestId === this._itemsRequestId) {
                this.isLoadingItems = false;
            }
        }
    }

    // POLICY EVALUATION

    async handleEvaluatePolicy() {
        if (!this.selectedReport) {
            this.showToast('Expense report required', 'Select a travel request that has an expense report.', 'warning');
            return;
        }

        if (this.isSaving) {
            return;
        }

        this.isSaving = true;

        try {
            const result = await evaluateReport({ reportId: this.selectedReport.Id });

            if (!result) {
                throw new Error('Policy evaluation returned no result.');
            }

            const violations = result.violations ?? 0;

            this.showToast(
                'Policy evaluation completed',
                `Status: ${result.policyStatus || 'Not returned'} | Risk: ${result.riskScore ?? 'N/A'}/100 | Violations: ${violations}`,
                violations > 0 ? 'warning' : 'success'
            );

            await this.handleRefresh();
        } catch (error) {
            this.showToast('Policy evaluation failed', this.getError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // SUBMIT EXPENSES

    async handleSubmitExpenses() {
        if (!this.selectedReport) {
            this.showToast('Expense report required', 'An expense report must exist before submission.', 'warning');
            return;
        }

        if (this.isSubmitExpensesDisabled) {
            this.showToast(
                'Submission unavailable',
                'Only Draft reports linked to manager-approved travel requests can be submitted.',
                'warning'
            );
            return;
        }

        this.isSaving = true;

        try {
            await submitExpenses({ reportId: this.selectedReport.Id });
            this.showToast('Expenses submitted', 'The report was submitted for Finance review.', 'success');
            await this.handleRefresh();
        } catch (error) {
            this.showToast('Submission failed', this.getError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // FINANCE COMMENTS

    handleCommentsChange(event) {
        this.financeComments = event.detail.value;
    }

    // APPROVE / REJECT

    async handleApproveReport() {
        await this.makeDecision('Approve');
    }

    async handleRejectReport() {
        await this.makeDecision('Reject');
    }

    async makeDecision(decision) {
        if (!this.selectedReport) {
            this.showToast('Expense report required', 'Finance cannot approve or reject a travel request without an expense report.', 'warning');
            return;
        }

        if (this.isSaving || this.isDecisionDisabled) {
            this.showToast('Decision unavailable', this.decisionDisabledReason, 'warning');
            return;
        }

        this.isSaving = true;

        try {
            await financeDecision({
                reportId: this.selectedReport.Id,
                decision,
                comments: this.financeComments,
                approvedAmount: null
            });

            this.showToast(
                'Finance decision saved',
                decision === 'Approve'
                    ? 'Finance approved the reimbursement.'
                    : 'Finance rejected the reimbursement.',
                'success'
            );

            await this.handleRefresh();
        } catch (error) {
            this.showToast('Finance action failed', this.getError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // MARK AS PAID AFTER ACTUAL REIMBURSEMENT

    async handleMarkPaid() {
        if (!this.selectedReport || this.isSaving || this.isMarkPaidDisabled) {
            this.showToast(
                'Cannot mark as Paid',
                'Select a Finance-approved expense report. Update this status only after reimbursement has actually been made.',
                'warning'
            );
            return;
        }

        this.isSaving = true;

        try {
            await markSettled({ reportId: this.selectedReport.Id });

            this.showToast(
                'Payment status updated',
                'The report is marked Paid. Salesforce did not transfer money.',
                'success'
            );

            await this.handleRefresh();
        } catch (error) {
            this.showToast('Unable to update payment status', this.getError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // STATUS STYLING

    getStatusClass(status) {
        switch (status) {
            case 'Paid':
            case 'Approved':
                return 'status status-success';
            case 'Rejected':
                return 'status status-danger';
            case 'Submitted':
            case 'Pending Approval':
            case 'Draft':
                return 'status status-pending';
            default:
                return 'status';
        }
    }

    // ERROR HANDLING

    getError(error) {
        if (!error) {
            return 'An unexpected error occurred.';
        }

        const body = error.body;

        if (Array.isArray(body)) {
            return body.map(item => item.message).filter(Boolean).join(', ') ||
                'An unexpected error occurred.';
        }

        const messages = [
            body?.message,
            ...(body?.pageErrors || []).map(item => item.message),
            ...(body?.fieldErrors
                ? Object.values(body.fieldErrors).flat().map(item => item.message)
                : []),
            error.message
        ].filter(Boolean);

        return [...new Set(messages)].join(', ') ||
            'An unexpected error occurred.';
    }

    // TOAST NOTIFICATIONS

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}