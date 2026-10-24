import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getTravelRequests
    from '@salesforce/apex/WanderRosterDashboardController.getTravelRequests';

import submitFinanceReview
    from '@salesforce/apex/WanderRosterDashboardController.submitFinanceReview';

export default class WanderRosterFinance extends LightningElement {
    requests = [];
    errorMessage = '';
    isLoading = true;
    isSaving = false;
    wiredRequestsResult;

    // Load travel requests from Salesforce
    @wire(getTravelRequests)
    wiredRequests(result) {
        this.wiredRequestsResult = result;

        const { data, error } = result;

        if (data) {
            this.errorMessage = '';

            this.requests = data.map(record => {
                const financeStatus =
                    record.Finance_Review_Status__c || '';

                const managerStatus =
                    record.Manager_Approval_Status__c || '';

                return {
                    ...record,

                    canReview:
                        financeStatus === 'Pending Review' &&
                        managerStatus === 'Pending',

                    draftComments:
                        record.Finance_Comments__c || '',

                    formattedTravelCost: this.formatCurrency(
                        record.Travel_Cost__c
                    ),

                    formattedHotelCost: this.formatCurrency(
                        record.Hotel_Cost__c
                    ),

                    formattedOtherCost: this.formatCurrency(
                        record.Other_Estimated_Cost__c
                    ),

                    formattedEstimatedTotal: this.formatCurrency(
                        record.Estimated_Total__c
                    ),

                    financeStatusClass:
                        this.getStatusClass(financeStatus),

                    financeStatusLabel:
                        financeStatus || 'Not submitted',

                    policyStatusLabel:
                        record.Policy_Status__c || 'Not evaluated',

                    aiRecommendation:
                        record.AI_Recommendation__c ||
                        'No recommendation available.',

                    aiExplanation:
                        record.AI_Explanation__c ||
                        'No AI explanation available.'
                };
            });
        } else if (error) {
            this.requests = [];
            this.errorMessage = this.getErrorMessage(error);
        }

        this.isLoading = false;
    }

    // Format values as Indian rupees
    formatCurrency(value) {
        return (Number(value) || 0).toLocaleString('en-IN', {
            style: 'currency',
            currency: 'INR',
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    // CSS classes for finance status badges
    getStatusClass(status) {
        switch (status) {
            case 'Cleared':
                return 'status-pill status-cleared';

            case 'Needs Changes':
                return 'status-pill status-changes';

            case 'Pending Review':
                return 'status-pill status-pending';

            default:
                return 'status-pill';
        }
    }

    // Summary: all retrieved requests
    get totalRequests() {
        return this.requests.length;
    }

    // Requests awaiting finance review
    get pendingRequests() {
        return this.requests.filter(
            item =>
                item.Finance_Review_Status__c === 'Pending Review' &&
                item.Manager_Approval_Status__c === 'Pending'
        ).length;
    }

    // Requests cleared by finance
    get clearedRequests() {
        return this.requests.filter(
            item => item.Finance_Review_Status__c === 'Cleared'
        ).length;
    }

    // Combined estimated costs
    get totalBudget() {
        const total = this.requests.reduce(
            (sum, item) =>
                sum + (Number(item.Estimated_Total__c) || 0),
            0
        );

        return total.toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    // Template helpers
    get hasRequests() {
        return this.requests.length > 0;
    }

    get showRequestList() {
        return (
            !this.isLoading &&
            !this.errorMessage &&
            this.requests.length > 0
        );
    }

    get showEmpty() {
        return (
            !this.isLoading &&
            !this.errorMessage &&
            this.requests.length === 0
        );
    }

    // Update draft comments without saving immediately
    handleCommentsChange(event) {
        const requestId = event.target.dataset.id;
        const comments = event.target.value;

        this.requests = this.requests.map(item =>
            item.Id === requestId
                ? { ...item, draftComments: comments }
                : item
        );
    }

    // Save a finance review decision and verify the refreshed value
    async handleReview(event) {
        if (this.isSaving) {
            return;
        }

        const requestId = event.currentTarget.dataset.id;
        const reviewStatus = event.currentTarget.dataset.status;

        if (!requestId) {
            this.showToast(
                'Missing request ID',
                'Refresh the page and select the request again.',
                'error'
            );
            return;
        }

        if (!['Cleared', 'Needs Changes'].includes(reviewStatus)) {
            this.showToast(
                'Invalid decision',
                'Choose Clear for Manager or Request Changes.',
                'error'
            );
            return;
        }

        const request = this.requests.find(
            item => item.Id === requestId
        );

        if (!request) {
            this.showToast(
                'Request not found',
                'Refresh the page and try again.',
                'error'
            );
            return;
        }

        if (!request.canReview) {
            this.showToast(
                'Review unavailable',
                'This request is not awaiting finance review. Refresh and check its status.',
                'warning'
            );
            return;
        }

        const comments = (request.draftComments || '').trim();

        if (reviewStatus === 'Needs Changes' && !comments) {
            this.showToast(
                'Comments required',
                'Explain what the employee needs to change.',
                'error'
            );
            return;
        }

        this.isSaving = true;

        try {
            await submitFinanceReview({
                travelRequestId: requestId,
                reviewStatus: reviewStatus,
                financeComments: comments
            });

            this.requests = this.requests.map(item => {
                if (item.Id === requestId) {
                    return {
                        ...item,
                        Finance_Review_Status__c: reviewStatus,
                        Finance_Comments__c: comments,
                        draftComments: comments,
                        canReview: false,
                        financeStatusLabel: reviewStatus,
                        financeStatusClass: this.getStatusClass(reviewStatus)
                    };
                }
                return item;
            });

            this.showToast(
                'Finance review saved',
                `${request.Name}: ${reviewStatus}`,
                'success'
            );

            await refreshApex(this.wiredRequestsResult);
        } catch (error) {
            this.showToast(
                'Finance review failed',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isSaving = false;
        }
    }

    // Refresh data from Salesforce
    async handleRefresh() {
        if (this.isLoading || !this.wiredRequestsResult) {
            return;
        }

        this.isLoading = true;

        try {
            await refreshApex(this.wiredRequestsResult);
        } catch (error) {
            this.errorMessage = this.getErrorMessage(error);

            this.showToast(
                'Refresh failed',
                this.errorMessage,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    // Convert Salesforce errors into readable messages
    getErrorMessage(error) {
        if (Array.isArray(error?.body)) {
            return error.body
                .map(item => item.message)
                .filter(Boolean)
                .join(', ');
        }

        return (
            error?.body?.message ||
            error?.message ||
            'An unexpected error occurred.'
        );
    }

    // Display toast notifications
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