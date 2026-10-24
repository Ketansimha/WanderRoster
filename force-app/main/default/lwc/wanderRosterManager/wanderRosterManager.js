import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getTravelRequests
    from '@salesforce/apex/WanderRosterDashboardController.getTravelRequests';

import updateTravelStatus
    from '@salesforce/apex/WanderRosterDashboardController.updateTravelStatus';

export default class WanderRosterManager extends LightningElement {
    requests = [];
    isLoading = false;
    isProcessing = false;
    errorMessage = '';
    searchTerm = '';
    statusFilter = 'All';

    filterOptions = [
        { label: 'All Requests', value: 'All' },
        { label: 'Pending Manager Approval', value: 'Pending' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Finance Needs Changes', value: 'Needs Changes' }
    ];

    connectedCallback() {
        this.loadRequests();
    }

    normalizeStatus(value, fallback = '') {
        return String(value ?? fallback).trim();
    }

    getField(record, names, fallback = '') {
        for (const name of names) {
            const value = record?.[name];

            if (value !== undefined && value !== null && value !== '') {
                return value;
            }
        }

        return fallback;
    }

    loadRequests() {
        if (this.isLoading) {
            return Promise.resolve();
        }

        this.isLoading = true;
        this.errorMessage = '';

        return getTravelRequests()
            .then((data) => {
                this.requests = (data || []).map((record) => {
                    const financeStatus = this.normalizeStatus(
                        this.getField(
                            record,
                            ['Finance_Review_Status__c'],
                            'Pending Review'
                        )
                    );

                    const managerStatus = this.normalizeStatus(
                        this.getField(
                            record,
                            ['Manager_Approval_Status__c'],
                            'Pending'
                        )
                    );

                    const travelStatus = this.normalizeStatus(
                        this.getField(
                            record,
                            ['Travel_Status__c'],
                            'Pending Approval'
                        )
                    );

                    const financeKey = financeStatus.toLowerCase();
                    const managerKey = managerStatus.toLowerCase();
                    const travelKey = travelStatus.toLowerCase();

                    const canDecide =
                        financeKey === 'cleared' &&
                        managerKey === 'pending' &&
                        travelKey === 'pending approval';

                    const cost = Number(
                        this.getField(
                            record,
                            [
                                'Estimated_Total__c',
                                'Estimated_Cost__c',
                                'Travel_Cost__c'
                            ],
                            0
                        )
                    ) || 0;

                    const employeeValue = this.getField(
                        record,
                        [
                            'Employee_Name__c',
                            'Employee__c',
                            'Employee_Name',
                            'OwnerName'
                        ],
                        'Employee'
                    );

                    const employee =
                        typeof employeeValue === 'object'
                            ? employeeValue?.Name || 'Employee'
                            : String(employeeValue);

                    return {
                        id: record.Id,
                        name: this.getField(
                            record,
                            ['Name'],
                            'Travel Request'
                        ),
                        employee,
                        destination: this.getField(
                            record,
                            ['Destination__c'],
                            'Not specified'
                        ),
                        cost,
                        costLabel: new Intl.NumberFormat('en-IN', {
                            style: 'currency',
                            currency: 'INR',
                            maximumFractionDigits: 0
                        }).format(cost),
                        financeStatus,
                        managerStatus,
                        travelStatus,
                        canDecide,
                        actionLabel: this.getActionLabel(
                            financeStatus,
                            managerStatus,
                            travelStatus
                        ),
                        financeClass: this.getStatusClass(financeStatus),
                        managerClass: this.getStatusClass(managerStatus)
                    };
                });
            })
            .catch((error) => {
                this.errorMessage = this.getErrorMessage(error);

                this.showToast(
                    'Unable to load requests',
                    this.errorMessage,
                    'error'
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    getActionLabel(financeStatus, managerStatus, travelStatus) {
        const finance = financeStatus.toLowerCase();
        const manager = managerStatus.toLowerCase();
        const travel = travelStatus.toLowerCase();

        if (manager === 'approved' || travel === 'approved') {
            return 'Approved';
        }

        if (manager === 'rejected' || travel === 'rejected') {
            return 'Rejected';
        }

        if (finance === 'needs changes') {
            return 'Needs Finance Changes';
        }

        if (finance !== 'cleared') {
            return 'Awaiting Finance';
        }

        if (manager !== 'pending') {
            return `Manager: ${managerStatus}`;
        }

        if (travel !== 'pending approval') {
            return `Travel: ${travelStatus}`;
        }

        return 'Awaiting Decision';
    }

    getStatusClass(status) {
        const value = status.toLowerCase();

        if (
            value === 'cleared' ||
            value === 'approved'
        ) {
            return 'status-pill status-success';
        }

        if (
            value === 'rejected' ||
            value === 'needs changes'
        ) {
            return 'status-pill status-danger';
        }

        return 'status-pill status-pending';
    }

    get pendingCount() {
        return this.requests.filter(
            (item) => item.canDecide
        ).length;
    }

    get approvedCount() {
        return this.requests.filter(
            (item) =>
                item.managerStatus.toLowerCase() === 'approved'
        ).length;
    }

    get rejectedCount() {
        return this.requests.filter(
            (item) =>
                item.managerStatus.toLowerCase() === 'rejected'
        ).length;
    }

    get visibleRequests() {
        const term = this.searchTerm.trim().toLowerCase();

        return this.requests.filter((item) => {
            const matchesSearch =
                !term ||
                String(item.name).toLowerCase().includes(term) ||
                String(item.employee).toLowerCase().includes(term) ||
                String(item.destination).toLowerCase().includes(term);

            let matchesFilter = true;

            if (this.statusFilter === 'Pending') {
                matchesFilter = item.canDecide;
            } else if (this.statusFilter === 'Needs Changes') {
                matchesFilter =
                    item.financeStatus.toLowerCase() === 'needs changes';
            } else if (this.statusFilter === 'Approved') {
                matchesFilter =
                    item.managerStatus.toLowerCase() === 'approved';
            } else if (this.statusFilter === 'Rejected') {
                matchesFilter =
                    item.managerStatus.toLowerCase() === 'rejected';
            }

            return matchesSearch && matchesFilter;
        });
    }

    get hasRequests() {
        return this.visibleRequests.length > 0;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
    }

    handleFilterChange(event) {
        this.statusFilter = event.detail.value;
    }

    handleRefresh() {
        return this.loadRequests();
    }

    handleApprove(event) {
        this.saveDecision(
            event.currentTarget.dataset.id,
            'Approved'
        );
    }

    handleReject(event) {
        this.saveDecision(
            event.currentTarget.dataset.id,
            'Rejected'
        );
    }

    saveDecision(recordId, newStatus) {
        if (this.isProcessing || !recordId) {
            return;
        }

        const request = this.requests.find(
            (item) => item.id === recordId
        );

        if (!request || !request.canDecide) {
            this.showToast(
                'Cannot update request',
                'Only finance-cleared requests awaiting manager approval can be decided.',
                'warning'
            );
            return;
        }

        this.isProcessing = true;
        this.errorMessage = '';

        updateTravelStatus({
            travelRequestId: recordId,
            newStatus: newStatus
        })
            .then(() => {
                this.showToast(
                    'Decision saved',
                    `Travel request ${newStatus.toLowerCase()} successfully.`,
                    'success'
                );

                // Reload the latest Salesforce records.
                return this.loadRequests();
            })
            .catch((error) => {
                this.showToast(
                    'Decision failed',
                    this.getErrorMessage(error),
                    'error'
                );
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }

    getErrorMessage(error) {
        return (
            error?.body?.message ||
            error?.message ||
            'An unexpected error occurred.'
        );
    }

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