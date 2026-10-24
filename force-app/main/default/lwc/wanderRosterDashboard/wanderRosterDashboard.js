import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getTravelRequests
    from '@salesforce/apex/WanderRosterDashboardController.getTravelRequests';

import updateTravelStatus
    from '@salesforce/apex/WanderRosterDashboardController.updateTravelStatus';

import createTravelRequest
    from '@salesforce/apex/WanderRosterDashboardController.createTravelRequest';

import submitFinanceReview
    from '@salesforce/apex/WanderRosterDashboardController.submitFinanceReview';

export default class WanderRosterDashboard extends LightningElement {

    // ==========================================
    // NAVIGATION
    // ==========================================

    activePage = 'dashboard';

    handleNavigation(event) {
        const selectedPage = event.currentTarget.dataset.page;

        const validPages = [
            'dashboard',
            'travel',
            'finance',
            'manager',
            'settlement'
        ];

        if (validPages.includes(selectedPage)) {
            this.activePage = selectedPage;
        }
    }

    getNavClass(page) {
        return this.activePage === page
            ? 'nav-item active'
            : 'nav-item';
    }

    get dashboardNavClass() {
        return this.getNavClass('dashboard');
    }

    get travelNavClass() {
        return this.getNavClass('travel');
    }

    get financeNavClass() {
        return this.getNavClass('finance');
    }

    get managerNavClass() {
        return this.getNavClass('manager');
    }

    // NEW: Expense Settlement navigation
    get settlementNavClass() {
        return this.getNavClass('settlement');
    }

    get isDashboardPage() {
        return this.activePage === 'dashboard';
    }

    get isTravelPage() {
        return this.activePage === 'travel';
    }

    get isFinancePage() {
        return this.activePage === 'finance';
    }

    get isManagerPage() {
        return this.activePage === 'manager';
    }

    // NEW: Show the settlement component
    get isSettlementPage() {
        return this.activePage === 'settlement';
    }


    // ==========================================
    // DASHBOARD DATA
    // ==========================================

    travelRequests = [];
    errorMessage = '';
    isLoading = true;
    isProcessing = false;
    wiredTravelRequestsResult;


    // ==========================================
    // TRAVEL REQUEST FORM
    // ==========================================

    origin = '';
    destination = '';
    startDate = '';
    endDate = '';

    travelCost = '';
    hotelCost = '0';
    otherEstimatedCost = '0';

    formErrorMessage = '';

    isSubmitting = false;


    // ==========================================
    // FINANCE COMMENTS
    // ==========================================

    financeCommentsByRequest = {};


    // ==========================================
    // ERROR HANDLING
    // ==========================================

    getErrorMessage(error) {
        if (!error) {
            return 'Unknown error. Check the browser console.';
        }

        if (Array.isArray(error.body)) {
            return error.body
                .map(item => item.message)
                .filter(Boolean)
                .join(', ');
        }

        if (error.body && error.body.message) {
            return error.body.message;
        }

        if (
            error.body &&
            error.body.pageErrors &&
            error.body.pageErrors.length > 0
        ) {
            return error.body.pageErrors
                .map(item => item.message)
                .join(', ');
        }

        if (error.body && error.body.fieldErrors) {
            const messages = [];

            Object.values(error.body.fieldErrors).forEach(errors => {
                errors.forEach(item => {
                    if (item.message) {
                        messages.push(item.message);
                    }
                });
            });

            if (messages.length > 0) {
                return messages.join(', ');
            }
        }

        return error.message ||
            'Salesforce returned an error without a readable message.';
    }


    // ==========================================
    // LOAD TRAVEL REQUESTS
    // ==========================================

    @wire(getTravelRequests)
    wiredTravelRequests(result) {
        this.wiredTravelRequestsResult = result;

        const { data, error } = result;
        this.isLoading = false;

        if (data) {
            this.travelRequests = data;
            this.errorMessage = '';
        } else if (error) {
            console.error('Load travel requests error:', error);

            this.travelRequests = [];
            this.errorMessage = this.getErrorMessage(error);
        }
    }


    // ==========================================
    // TRAVEL FORM INPUT HANDLERS
    // ==========================================

    handleOriginChange(event) {
        this.origin = event.target.value;
    }

    handleDestinationChange(event) {
        this.destination = event.target.value;
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }

    handleTravelCostChange(event) {
        this.travelCost = event.target.value;
        const val = Number(event.target.value);
        if (event.target.value !== '' && (isNaN(val) || val <= 0)) {
            this.formErrorMessage = 'Estimated Travel Cost must be greater than 0. Amount cannot be 0 or negative.';
            event.target.setCustomValidity('Amount must be greater than 0.');
        } else {
            if (this.formErrorMessage.includes('Travel Cost')) {
                this.formErrorMessage = '';
            }
            event.target.setCustomValidity('');
        }
        event.target.reportValidity();
    }

    handleHotelCostChange(event) {
        this.hotelCost = event.target.value;
        const val = Number(event.target.value);
        if (event.target.value !== '' && (isNaN(val) || val < 0)) {
            this.formErrorMessage = 'Hotel cost cannot be negative.';
            event.target.setCustomValidity('Amount cannot be negative.');
        } else {
            if (this.formErrorMessage.includes('Hotel cost')) {
                this.formErrorMessage = '';
            }
            event.target.setCustomValidity('');
        }
        event.target.reportValidity();
    }

    handleOtherEstimatedCostChange(event) {
        this.otherEstimatedCost = event.target.value;
        const val = Number(event.target.value);
        if (event.target.value !== '' && (isNaN(val) || val < 0)) {
            this.formErrorMessage = 'Other estimated cost cannot be negative.';
            event.target.setCustomValidity('Amount cannot be negative.');
        } else {
            if (this.formErrorMessage.includes('Other estimated cost')) {
                this.formErrorMessage = '';
            }
            event.target.setCustomValidity('');
        }
        event.target.reportValidity();
    }


    // ==========================================
    // ESTIMATED TOTAL
    // ==========================================

    get formattedEstimatedTotal() {
        const travel = Number(this.travelCost) || 0;
        const hotel = Number(this.hotelCost) || 0;
        const other = Number(this.otherEstimatedCost) || 0;

        return (travel + hotel + other).toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }


    // ==========================================
    // SUBMIT TRAVEL REQUEST
    // ==========================================

    async handleSubmitTravelRequest(event) {
        if (event) {
            event.preventDefault();
        }

        if (this.isSubmitting) {
            return;
        }

        const origin = (this.origin || '').trim();
        const destination = (this.destination || '').trim();

        const travel = Number(this.travelCost);
        const hotel = Number(this.hotelCost);
        const other = Number(this.otherEstimatedCost);

        if (
            !origin ||
            !destination ||
            !this.startDate ||
            !this.endDate
        ) {
            this.formErrorMessage = 'Enter origin, destination, start date and end date.';
            this.showToast(
                'Missing details',
                this.formErrorMessage,
                'error'
            );
            return;
        }

        if (
            this.travelCost === '' ||
            this.hotelCost === '' ||
            this.otherEstimatedCost === '' ||
            !Number.isFinite(travel) ||
            !Number.isFinite(hotel) ||
            !Number.isFinite(other)
        ) {
            this.formErrorMessage = 'Enter valid numeric amounts for all three cost fields.';
            this.showToast(
                'Invalid costs',
                this.formErrorMessage,
                'error'
            );
            return;
        }

        if (travel < 0 || hotel < 0 || other < 0) {
            this.formErrorMessage = 'Estimated amounts cannot be less than 0.';
            this.showToast(
                'Invalid costs',
                this.formErrorMessage,
                'error'
            );
            return;
        }

        if (travel <= 0) {
            this.formErrorMessage = 'Estimated Travel Cost must be greater than 0. Amount cannot be 0 or negative.';
            this.showToast(
                'Invalid cost',
                this.formErrorMessage,
                'error'
            );
            const input = this.template.querySelector('[name="travelCost"]');
            if (input) {
                input.setCustomValidity('Amount must be greater than 0.');
                input.reportValidity();
            }
            return;
        }

        if ((travel + hotel + other) <= 0) {
            this.formErrorMessage = 'Total estimated cost must be greater than 0. Amount cannot be 0 or negative.';
            this.showToast(
                'Invalid costs',
                this.formErrorMessage,
                'error'
            );
            return;
        }

        if (this.startDate > this.endDate) {
            this.formErrorMessage = 'The end date must be on or after the start date.';
            this.showToast(
                'Invalid dates',
                this.formErrorMessage,
                'error'
            );
            return;
        }

        this.formErrorMessage = '';

        this.isSubmitting = true;

        try {
            await createTravelRequest({
                origin: origin,
                destination: destination,
                startDate: this.startDate,
                endDate: this.endDate,
                travelCost: travel,
                hotelCost: hotel,
                otherEstimatedCost: other
            });

            this.showToast(
                'Request submitted',
                'Your travel request was submitted successfully.',
                'success'
            );

            this.origin = '';
            this.destination = '';
            this.startDate = '';
            this.endDate = '';
            this.travelCost = '';
            this.hotelCost = '0';
            this.otherEstimatedCost = '0';

            const form = this.template.querySelector(
                '.travel-request-form'
            );

            if (form) {
                form.reset();
            }

            await refreshApex(this.wiredTravelRequestsResult);

        } catch (error) {
            console.error('Travel request error:', error);
            this.formErrorMessage = this.getErrorMessage(error);

            this.showToast(
                'Travel Request Failed',
                this.formErrorMessage,
                'error',
                'sticky'
            );
        } finally {
            this.isSubmitting = false;
        }
    }


    // ==========================================
    // STATUS BADGES
    // ==========================================

    getStatusClass(status) {
        if (status === 'Approved') {
            return 'status-badge status-approved';
        }

        if (
            status === 'Pending Approval' ||
            status === 'Pending Finance Review' ||
            status === 'Pending Review' ||
            status === 'Pending'
        ) {
            return 'status-badge status-pending';
        }

        if (status === 'Submitted') {
            return 'status-badge status-submitted';
        }

        if (
            status === 'Rejected' ||
            status === 'Needs Changes'
        ) {
            return 'status-badge status-rejected';
        }

        return 'status-badge';
    }


    // ==========================================
    // TRAVEL REQUEST DISPLAY PROPERTIES
    // ==========================================

    get travelRequestsWithStatus() {
        return this.travelRequests.map(request => {
            const financeCleared =
                request.Finance_Review_Status__c === 'Cleared';

            const managerPending =
                request.Manager_Approval_Status__c === 'Pending';

            let managerStatusClass = 'status-badge';

            if (request.Manager_Approval_Status__c === 'Approved') {
                managerStatusClass = 'status-badge status-approved';
            } else if (
                request.Manager_Approval_Status__c === 'Rejected'
            ) {
                managerStatusClass = 'status-badge status-rejected';
            } else if (managerPending) {
                managerStatusClass = 'status-badge status-pending';
            }

            return {
                ...request,

                statusClass: this.getStatusClass(
                    request.Travel_Status__c
                ),

                managerStatusClass: managerStatusClass,

                canFinanceReview:
                    request.Finance_Review_Status__c === 'Pending Review',

                canReview: financeCleared && managerPending,

                financeCommentsDraft:
                    this.financeCommentsByRequest[request.Id] ??
                    request.Finance_Comments__c ??
                    ''
            };
        });
    }


    // ==========================================
    // DASHBOARD KPIs
    // ==========================================

    get totalRequests() {
        return this.travelRequests.length;
    }

    get pendingApprovals() {
        return this.travelRequests.filter(
            request =>
                request.Finance_Review_Status__c === 'Cleared' &&
                request.Manager_Approval_Status__c === 'Pending'
        ).length;
    }

    get approvedRequests() {
        return this.travelRequests.filter(
            request =>
                request.Manager_Approval_Status__c === 'Approved' ||
                request.Travel_Status__c === 'Approved'
        ).length;
    }

    get totalEstimatedSpend() {
        return this.travelRequests.reduce(
            (total, request) =>
                total +
                (Number(request.Estimated_Total__c) || 0),
            0
        );
    }

    get hasTravelRequests() {
        return this.travelRequests.length > 0;
    }

    get showEmptyMessage() {
        return (
            !this.isLoading &&
            !this.errorMessage &&
            this.travelRequests.length === 0
        );
    }


    // ==========================================
    // FINANCE REVIEW
    // ==========================================

    handleFinanceCommentsChange(event) {
        const requestId = event.target.dataset.id;

        this.financeCommentsByRequest = {
            ...this.financeCommentsByRequest,
            [requestId]: event.target.value
        };
    }

    handleFinanceClear(event) {
        this.processFinanceReview(
            event.currentTarget.dataset.id,
            'Cleared'
        );
    }

    handleFinanceNeedsChanges(event) {
        this.processFinanceReview(
            event.currentTarget.dataset.id,
            'Needs Changes'
        );
    }

    async processFinanceReview(requestId, reviewStatus) {
        if (!requestId || this.isProcessing) {
            return;
        }

        const comments =
            this.financeCommentsByRequest[requestId] || '';

        if (
            reviewStatus === 'Needs Changes' &&
            !comments.trim()
        ) {
            this.showToast(
                'Comments required',
                'Explain what needs to be changed before submitting.',
                'error'
            );
            return;
        }

        this.isProcessing = true;

        try {
            await submitFinanceReview({
                travelRequestId: requestId,
                reviewStatus: reviewStatus,
                financeComments: comments
            });

            this.showToast(
                'Finance review saved',
                reviewStatus === 'Cleared'
                    ? 'Request forwarded for manager approval.'
                    : 'Request marked as needing changes.',
                'success'
            );

            const updatedComments = {
                ...this.financeCommentsByRequest
            };

            delete updatedComments[requestId];
            this.financeCommentsByRequest = updatedComments;

            await refreshApex(this.wiredTravelRequestsResult);

        } catch (error) {
            console.error('Finance review error:', error);

            this.showToast(
                'Finance Review Failed',
                this.getErrorMessage(error),
                'error',
                'sticky'
            );
        } finally {
            this.isProcessing = false;
        }
    }


    // ==========================================
    // MANAGER APPROVAL
    // ==========================================

    handleApprove(event) {
        this.processDecision(
            event.currentTarget.dataset.id,
            'Approved'
        );
    }

    handleReject(event) {
        this.processDecision(
            event.currentTarget.dataset.id,
            'Rejected'
        );
    }

    async processDecision(requestId, newStatus) {
        if (
            !requestId ||
            this.isProcessing ||
            !['Approved', 'Rejected'].includes(newStatus)
        ) {
            return;
        }

        this.isProcessing = true;

        try {
            await updateTravelStatus({
                travelRequestId: requestId,
                newStatus: newStatus
            });

            this.showToast(
                'Decision saved',
                `Travel request ${newStatus.toLowerCase()} successfully.`,
                'success'
            );

            await refreshApex(this.wiredTravelRequestsResult);

        } catch (error) {
            console.error('Manager decision error:', error);

            this.showToast(
                'Unable to update request',
                this.getErrorMessage(error),
                'error',
                'sticky'
            );
        } finally {
            this.isProcessing = false;
        }
    }


    // ==========================================
    // TOAST NOTIFICATIONS
    // ==========================================

    showToast(title, message, variant, mode) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                ...(mode ? { mode } : {})
            })
        );
    }
}