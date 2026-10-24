@IsTest
private class WanderRosterDashboardControllerTest {

    @TestSetup
    static void setupTestData() {
        Travel_Request__c tr = new Travel_Request__c(
            Travel_Purpose__c = 'Client Meeting',
            Origin__c = 'Chennai',
            Destination__c = 'Bengaluru',
            Start_Date__c = Date.today().addDays(5),
            End_Date__c = Date.today().addDays(7),
            Travel_Cost__c = 1500,
            Hotel_Cost__c = 2500,
            Other_Estimated_Cost__c = 500,
            Travel_Status__c = 'Pending Approval',
            Finance_Review_Status__c = 'Pending Review',
            Manager_Approval_Status__c = 'Pending'
        );
        insert tr;

        Expense_Report__c report = new Expense_Report__c(
            Travel_Request__c = tr.Id,
            Expense_Status__c = 'Draft'
        );
        insert report;

        Expense_Item__c item = new Expense_Item__c(
            Expense_Report__c = report.Id,
            Amount__c = 1200,
            Expense_Category__c = 'Transport',
            Expense_Date__c = Date.today()
        );
        insert item;
    }

    @IsTest
    static void testGetters() {
        Test.startTest();
        List<Travel_Request__c> requests = WanderRosterDashboardController.getTravelRequests();
        List<Expense_Report__c> reports = WanderRosterDashboardController.getExpenseReports();
        List<Expense_Item__c> items = WanderRosterDashboardController.getExpenseItems();
        Test.stopTest();

        System.assertNotEquals(0, requests.size());
        System.assertNotEquals(0, reports.size());
        System.assertNotEquals(0, items.size());
    }

    @IsTest
    static void testCreateTravelRequestSuccess() {
        Test.startTest();
        Id reqId = WanderRosterDashboardController.createTravelRequest(
            'Mumbai',
            'Delhi',
            Date.today().addDays(10),
            Date.today().addDays(12),
            2000,
            3000,
            500
        );
        Test.stopTest();

        System.assertNotEquals(null, reqId);
        Travel_Request__c tr = [
            SELECT Origin__c, Destination__c, Travel_Status__c, Finance_Review_Status__c, Manager_Approval_Status__c
            FROM Travel_Request__c
            WHERE Id = :reqId
        ];
        System.assertEquals('Mumbai', tr.Origin__c);
        System.assertEquals('Pending Approval', tr.Travel_Status__c);
        System.assertEquals('Pending Review', tr.Finance_Review_Status__c);
        System.assertEquals('Pending', tr.Manager_Approval_Status__c);
    }

    @IsTest
    static void testCreateTravelRequestValidations() {
        try {
            WanderRosterDashboardController.createTravelRequest('', '', Date.today(), Date.today(), 10, 10, 10);
            System.assert(false, 'Should have thrown exception for blank route');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            WanderRosterDashboardController.createTravelRequest('A', 'B', Date.today().addDays(5), Date.today().addDays(2), 10, 10, 10);
            System.assert(false, 'Should have thrown exception for invalid dates');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            WanderRosterDashboardController.createTravelRequest('A', 'B', Date.today(), Date.today(), -1, 10, 10);
            System.assert(false, 'Should have thrown exception for negative costs');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            WanderRosterDashboardController.createTravelRequest('A', 'B', Date.today(), Date.today(), 0, 10, 10);
            System.assert(false, 'Should have thrown exception for zero travel cost');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void testFinanceReviewAndManagerDecision() {
        Travel_Request__c tr = [SELECT Id FROM Travel_Request__c LIMIT 1];

        Test.startTest();
        // Finance review needs changes
        WanderRosterDashboardController.submitFinanceReview(tr.Id, 'Needs Changes', 'Please attach itinerary');
        Travel_Request__c updatedTr = [SELECT Finance_Review_Status__c, Finance_Comments__c FROM Travel_Request__c WHERE Id = :tr.Id];
        System.assertEquals('Needs Changes', updatedTr.Finance_Review_Status__c);
        System.assertEquals('Please attach itinerary', updatedTr.Finance_Comments__c);

        // Attempt manager decision before cleared should fail
        try {
            WanderRosterDashboardController.updateTravelStatus(tr.Id, 'Approved');
            System.assert(false, 'Should have failed because not cleared by finance');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // Finance clears the request
        WanderRosterDashboardController.submitFinanceReview(tr.Id, 'Cleared', 'Approved by finance');
        updatedTr = [SELECT Finance_Review_Status__c, Manager_Approval_Status__c FROM Travel_Request__c WHERE Id = :tr.Id];
        System.assertEquals('Cleared', updatedTr.Finance_Review_Status__c);
        System.assertEquals('Pending', updatedTr.Manager_Approval_Status__c);

        // Manager approves
        WanderRosterDashboardController.updateTravelStatus(tr.Id, 'Approved');
        updatedTr = [SELECT Travel_Status__c, Manager_Approval_Status__c FROM Travel_Request__c WHERE Id = :tr.Id];
        System.assertEquals('Approved', updatedTr.Travel_Status__c);
        System.assertEquals('Approved', updatedTr.Manager_Approval_Status__c);

        Test.stopTest();
    }

    @IsTest
    static void testReviewExceptions() {
        try {
            WanderRosterDashboardController.submitFinanceReview(null, 'Cleared', '');
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            WanderRosterDashboardController.updateTravelStatus(null, 'Approved');
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}