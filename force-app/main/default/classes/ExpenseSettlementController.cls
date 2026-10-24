public with sharing class ExpenseSettlementController {

    public class DashboardData {
        @AuraEnabled public Integer totalReports { get; set; }
        @AuraEnabled public Integer pendingReports { get; set; }
        @AuraEnabled public Integer approvedReports { get; set; }
        @AuraEnabled public Decimal totalExpenses { get; set; }
        @AuraEnabled public List<Expense_Report__c> reports { get; set; }
        @AuraEnabled public List<Travel_Request__c> approvedTravelRequests { get; set; }
    }

    // 1. Load dashboard metrics, approved trips, and expense reports
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboard() {
        DashboardData data = new DashboardData();

        data.totalReports = [
            SELECT COUNT()
            FROM Expense_Report__c
        ];

        data.pendingReports = [
            SELECT COUNT()
            FROM Expense_Report__c
            WHERE Expense_Status__c IN ('Submitted', 'Pending Approval', 'Under Review')
        ];

        data.approvedReports = [
            SELECT COUNT()
            FROM Expense_Report__c
            WHERE Expense_Status__c = 'Approved'
        ];

        AggregateResult result = [
            SELECT SUM(Total_Amount__c) total
            FROM Expense_Report__c
        ];

        data.totalExpenses = (Decimal) result.get('total');
        if (data.totalExpenses == null) {
            data.totalExpenses = 0;
        }

        data.approvedTravelRequests = [
            SELECT Id, Name,
                   Origin__c, Destination__c,
                   Start_Date__c, End_Date__c,
                   Travel_Cost__c, Hotel_Cost__c,
                   Other_Estimated_Cost__c, Estimated_Total__c,
                   Travel_Status__c, Manager_Approval_Status__c,
                   Finance_Review_Status__c, Finance_Comments__c,
                   Policy_Status__c, AI_Risk_Score__c,
                   AI_Recommendation__c, AI_Explanation__c
            FROM Travel_Request__c
            WHERE Manager_Approval_Status__c = 'Approved'
              AND Travel_Status__c = 'Approved'
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];

        data.reports = [
            SELECT Id, Name,
                   Submission_Date__c, Total_Amount__c,
                   Expense_Status__c, Policy_Status__c,
                   AI_Risk_Score__c, AI_Explanation__c,
                   Manager_Comments__c,
                   Employee__c, Employee__r.Name,
                   Travel_Request__c, Travel_Request__r.Name,
                   Travel_Request__r.Manager_Approval_Status__c,
                   Travel_Request__r.Travel_Status__c,
                   Travel_Request__r.Origin__c,
                   Travel_Request__r.Destination__c,
                   Travel_Request__r.Travel_Cost__c,
                   Travel_Request__r.Hotel_Cost__c,
                   Travel_Request__r.Other_Estimated_Cost__c,
                   Travel_Request__r.Estimated_Total__c,
                   Travel_Request__r.Start_Date__c,
                   Travel_Request__r.End_Date__c
            FROM Expense_Report__c
            ORDER BY LastModifiedDate DESC
            LIMIT 100
        ];

        return data;
    }

    // 2. Retrieve expense items for a report
    @AuraEnabled(cacheable=true)
    public static List<Expense_Item__c> getExpenseItems(Id reportId) {
        if (reportId == null) {
            throw new AuraHandledException(
                'Select an expense report first.'
            );
        }

        return [
            SELECT Id, Name, Expense_Report__c,
                   Expense_Date__c, Expense_Category__c,
                   Amount__c, Vendor_Name__c, Description__c,
                   Receipt_Number__c, Receipt_Submission_Time__c,
                   Receipt_Deadline__c, Receipt_Status__c,
                   Verification_Status__c, AI_Explanation__c,
                   Possible_Duplicate__c, Policy_Violation__c
            FROM Expense_Item__c
            WHERE Expense_Report__c = :reportId
            ORDER BY Expense_Date__c DESC
        ];
    }

    // 3. Submit a draft report for Finance review
    @AuraEnabled
    public static void submitExpenses(Id reportId) {
        if (reportId == null) {
            throw new AuraHandledException(
                'Select an expense report first.'
            );
        }

        Expense_Report__c report = [
            SELECT Id, Expense_Status__c, Total_Amount__c,
                   Travel_Request__c,
                   Travel_Request__r.Travel_Status__c,
                   Travel_Request__r.Manager_Approval_Status__c
            FROM Expense_Report__c
            WHERE Id = :reportId
            LIMIT 1
            FOR UPDATE
        ];

        Boolean managerApproved =
            report.Travel_Request__c != null &&
            report.Travel_Request__r.Travel_Status__c == 'Approved' &&
            report.Travel_Request__r.Manager_Approval_Status__c == 'Approved';

        if (report.Expense_Status__c != 'Draft' || !managerApproved) {
            throw new AuraHandledException(
                'Only a Draft report linked to a manager-approved trip can be submitted.'
            );
        }

        Integer itemCount = [
            SELECT COUNT()
            FROM Expense_Item__c
            WHERE Expense_Report__c = :reportId
        ];

        if (itemCount == 0) {
            throw new AuraHandledException(
                'Submission blocked. Add genuine expense items first.'
            );
        }

        if (report.Total_Amount__c == null ||
            report.Total_Amount__c <= 0) {
            throw new AuraHandledException(
                'Submission blocked. The report total must be greater than zero.'
            );
        }

        ExpensePolicyChecker.EvaluationResult evaluation =
            ExpensePolicyChecker.evaluateReport(reportId);

        Boolean isWithinPolicy = evaluation != null &&
            (evaluation.policyStatus == 'Within Policy' || evaluation.policyStatus == 'Compliant');

        if (!isWithinPolicy) {
            throw new AuraHandledException(
                'Submission blocked. Resolve policy issues before submitting.'
            );
        }

        report.Expense_Status__c = getPendingExpenseStatus();
        update report;
    }

    // 4. Finance approves or rejects a submitted report
    @AuraEnabled
    public static void financeDecision(
        Id reportId,
        String decision,
        String comments,
        Decimal approvedAmount
    ) {
        if (reportId == null) {
            throw new AuraHandledException(
                'Select an expense report first.'
            );
        }

        if (decision != 'Approve' && decision != 'Reject') {
            throw new AuraHandledException(
                'Decision must be Approve or Reject.'
            );
        }

        Expense_Report__c report = [
            SELECT Id, Expense_Status__c, Policy_Status__c,
                   Total_Amount__c, Manager_Comments__c,
                   Travel_Request__c,
                   Travel_Request__r.Travel_Status__c,
                   Travel_Request__r.Manager_Approval_Status__c
            FROM Expense_Report__c
            WHERE Id = :reportId
            LIMIT 1
            FOR UPDATE
        ];

        if (report.Expense_Status__c != 'Submitted' &&
            report.Expense_Status__c != 'Pending Approval' &&
            report.Expense_Status__c != 'Under Review') {
            throw new AuraHandledException(
                'Finance can review only submitted or pending-approval reports.'
            );
        }

        if (report.Travel_Request__c == null ||
            report.Travel_Request__r.Travel_Status__c != 'Approved' ||
            report.Travel_Request__r.Manager_Approval_Status__c != 'Approved') {
            throw new AuraHandledException(
                'The linked trip must be manager-approved before Finance review.'
            );
        }

        if (decision == 'Approve') {
            Integer itemCount = [
                SELECT COUNT()
                FROM Expense_Item__c
                WHERE Expense_Report__c = :reportId
            ];

            if (itemCount == 0) {
                throw new AuraHandledException(
                    'Approval blocked. This report has no expense items.'
                );
            }

            if (report.Total_Amount__c == null ||
                report.Total_Amount__c <= 0) {
                throw new AuraHandledException(
                    'Approval blocked. The report total must be greater than zero.'
                );
            }

            ExpensePolicyChecker.EvaluationResult evaluation =
                ExpensePolicyChecker.evaluateReport(reportId);

            Boolean isWithinPolicy = evaluation != null &&
                (evaluation.policyStatus == 'Within Policy' || evaluation.policyStatus == 'Compliant');

            if (!isWithinPolicy) {
                throw new AuraHandledException(
                    'Approval blocked. Resolve all policy issues first.'
                );
            }

            if (approvedAmount != null &&
                approvedAmount != report.Total_Amount__c) {
                throw new AuraHandledException(
                    'Partial approval needs a dedicated approved-amount field.'
                );
            }

            report.Expense_Status__c = 'Approved';
        } else {
            report.Expense_Status__c = 'Rejected';
        }

        report.Manager_Comments__c = comments;
        update report;
    }

    // 5. Mark a report Paid after reimbursement has actually occurred
    @AuraEnabled
    public static void markSettled(Id reportId) {
        if (reportId == null) {
            throw new AuraHandledException(
                'Select an expense report first.'
            );
        }

        Expense_Report__c report = [
            SELECT Id, Expense_Status__c, Total_Amount__c,
                   Travel_Request__c,
                   Travel_Request__r.Travel_Status__c,
                   Travel_Request__r.Manager_Approval_Status__c
            FROM Expense_Report__c
            WHERE Id = :reportId
            LIMIT 1
            FOR UPDATE
        ];

        if (report.Expense_Status__c != 'Approved') {
            throw new AuraHandledException(
                'Only Finance-approved reports can be marked as paid.'
            );
        }

        if (report.Travel_Request__c == null ||
            report.Travel_Request__r.Travel_Status__c != 'Approved' ||
            report.Travel_Request__r.Manager_Approval_Status__c != 'Approved') {
            throw new AuraHandledException(
                'The linked trip must remain manager-approved.'
            );
        }

        Integer itemCount = [
            SELECT COUNT()
            FROM Expense_Item__c
            WHERE Expense_Report__c = :reportId
        ];

        if (itemCount == 0) {
            throw new AuraHandledException(
                'Payment blocked. Add genuine expense items before settlement.'
            );
        }

        if (report.Total_Amount__c == null ||
            report.Total_Amount__c <= 0) {
            throw new AuraHandledException(
                'Payment blocked. The report total must be greater than zero.'
            );
        }

        ExpensePolicyChecker.EvaluationResult evaluation =
            ExpensePolicyChecker.evaluateReport(reportId);

        Boolean isWithinPolicy = evaluation != null &&
            (evaluation.policyStatus == 'Within Policy' || evaluation.policyStatus == 'Compliant');

        if (!isWithinPolicy) {
            throw new AuraHandledException(
                'Payment blocked. Resolve policy issues before settlement.'
            );
        }

        // Salesforce status update only; this does not transfer money.
        report.Expense_Status__c = getSettledExpenseStatus();
        update report;
    }

    private static String getPendingExpenseStatus() {
        Set<String> values = getExpenseStatusValues();
        if (values.contains('Pending Approval')) {
            return 'Pending Approval';
        }
        return 'Under Review';
    }

    private static String getSettledExpenseStatus() {
        Set<String> values = getExpenseStatusValues();
        if (values.contains('Paid')) {
            return 'Paid';
        }
        return 'Reimbursed';
    }

    private static Set<String> getExpenseStatusValues() {
        Set<String> values = new Set<String>();
        for (Schema.PicklistEntry ple : Expense_Report__c.Expense_Status__c.getDescribe().getPicklistValues()) {
            if (ple.isActive()) {
                values.add(ple.getValue());
            }
        }
        return values;
    }
}