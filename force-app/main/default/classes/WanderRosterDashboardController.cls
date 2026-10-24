public with sharing class WanderRosterDashboardController {

    // 1. Get Travel Requests
    @AuraEnabled(cacheable=true)
    public static List<Travel_Request__c> getTravelRequests() {
        return [
            SELECT Id, Name, Origin__c, Destination__c,
                   Start_Date__c, End_Date__c,
                   Travel_Cost__c, Hotel_Cost__c,
                   Other_Estimated_Cost__c, Estimated_Total__c,
                   Travel_Status__c, Policy_Status__c,
                   Manager_Approval_Status__c,
                   Finance_Review_Status__c, Finance_Comments__c,
                   AI_Risk_Score__c, AI_Recommendation__c,
                   AI_Explanation__c
            FROM Travel_Request__c
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }


    // 2. Get Expense Reports
    @AuraEnabled(cacheable=true)
    public static List<Expense_Report__c> getExpenseReports() {
        return [
            SELECT Id, Name, Employee__c, Total_Amount__c,
                   Expense_Status__c, Policy_Status__c,
                   AI_Risk_Score__c, AI_Explanation__c,
                   Submission_Date__c, Manager_Comments__c,
                   Travel_Request__c
            FROM Expense_Report__c
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }


    // 3. Get Expense Items
    @AuraEnabled(cacheable=true)
    public static List<Expense_Item__c> getExpenseItems() {
        return [
            SELECT Id, Name, Amount__c, Expense_Category__c,
                   Expense_Date__c, Expense_Report__c,
                   Policy_Violation__c, Possible_Duplicate__c,
                   Receipt_Status__c, Verification_Status__c,
                   Receipt_Deadline__c, Receipt_Number__c,
                   Receipt_Submission_Time__c, Vendor_Name__c,
                   Description__c, AI_Explanation__c
            FROM Expense_Item__c
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }


    // 4. Employee submits a travel request
    @AuraEnabled
    public static Id createTravelRequest(
        String origin,
        String destination,
        Date startDate,
        Date endDate,
        Decimal travelCost,
        Decimal hotelCost,
        Decimal otherEstimatedCost
    ) {
        if (String.isBlank(origin) || String.isBlank(destination)) {
            throw new AuraHandledException(
                'Please enter both origin and destination.'
            );
        }

        if (startDate == null || endDate == null ||
            startDate > endDate) {
            throw new AuraHandledException(
                'Please enter valid travel dates.'
            );
        }

        if (travelCost == null || hotelCost == null ||
            otherEstimatedCost == null ||
            travelCost <= 0 || hotelCost < 0 ||
            otherEstimatedCost < 0 ||
            (travelCost + hotelCost + otherEstimatedCost) <= 0) {
            throw new AuraHandledException(
                'Estimated Travel Cost must be greater than zero. Amount cannot be 0 or negative.'
            );
        }

        if (!Schema.sObjectType.Travel_Request__c.isCreateable()) {
            throw new AuraHandledException(
                'You do not have permission to create travel requests.'
            );
        }

        Travel_Request__c request = new Travel_Request__c(
            Origin__c = origin.trim(),
            Destination__c = destination.trim(),
            Travel_Purpose__c = 'Client Meeting',
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Travel_Cost__c = travelCost,
            Hotel_Cost__c = hotelCost,
            Other_Estimated_Cost__c = otherEstimatedCost,

            // Travel Status is a separate picklist.
            Travel_Status__c = 'Pending Approval',

            // Finance review status.
            Finance_Review_Status__c = 'Pending Review',

            // Valid Manager Approval picklist value.
            Manager_Approval_Status__c = 'Pending'
        );

        insert request;
        return request.Id;
    }


    // 5. Finance reviews the request
    @AuraEnabled
    public static void submitFinanceReview(
        Id travelRequestId,
        String reviewStatus,
        String financeComments
    ) {
        if (travelRequestId == null) {
            throw new AuraHandledException(
                'Travel request ID is required.'
            );
        }

        if (reviewStatus != 'Cleared' &&
            reviewStatus != 'Needs Changes') {
            throw new AuraHandledException(
                'Finance must select Cleared or Needs Changes.'
            );
        }

        List<Travel_Request__c> requests = [
            SELECT Id, Travel_Status__c,
                   Finance_Review_Status__c,
                   Manager_Approval_Status__c
            FROM Travel_Request__c
            WHERE Id = :travelRequestId
            LIMIT 1
            FOR UPDATE
        ];

        if (requests.isEmpty()) {
            throw new AuraHandledException(
                'Travel request was not found.'
            );
        }

        Travel_Request__c request = requests[0];

        if (request.Manager_Approval_Status__c == 'Approved' ||
            request.Manager_Approval_Status__c == 'Rejected') {
            throw new AuraHandledException(
                'A request with a manager decision cannot be reviewed again.'
            );
        }

        request.Finance_Review_Status__c = reviewStatus;
        request.Finance_Comments__c = financeComments;

        if (reviewStatus == 'Cleared') {
            request.Travel_Status__c = 'Pending Approval';

            // Reset to the valid pending manager status.
            request.Manager_Approval_Status__c = 'Pending';
        }

        update request;
    }


    // 6. Manager decision: only after Finance clears the request
    @AuraEnabled
    public static void updateTravelStatus(
        Id travelRequestId,
        String newStatus
    ) {
        if (travelRequestId == null) {
            throw new AuraHandledException(
                'Travel request ID is required.'
            );
        }

        if (newStatus != 'Approved' && newStatus != 'Rejected') {
            throw new AuraHandledException(
                'Only Approved or Rejected status is allowed.'
            );
        }

        List<Travel_Request__c> requests = [
            SELECT Id, Travel_Status__c,
                   Finance_Review_Status__c,
                   Manager_Approval_Status__c
            FROM Travel_Request__c
            WHERE Id = :travelRequestId
            LIMIT 1
            FOR UPDATE
        ];

        if (requests.isEmpty()) {
            throw new AuraHandledException(
                'Travel request was not found.'
            );
        }

        Travel_Request__c request = requests[0];

        if (request.Finance_Review_Status__c != 'Cleared') {
            throw new AuraHandledException(
                'Finance must clear this request before manager approval.'
            );
        }

        if (request.Manager_Approval_Status__c != 'Pending') {
            throw new AuraHandledException(
                'This request has already received a manager decision.'
            );
        }

        request.Travel_Status__c = newStatus;
        request.Manager_Approval_Status__c = newStatus;

        update request;
    }
}