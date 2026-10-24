@IsTest
private class TravelExpenseReportSyncTest {

    @IsTest
    static void testCreateReportIfMissing() {
        // Create an approved travel request with required Travel_Purpose__c
        Travel_Request__c req = new Travel_Request__c(
            Travel_Purpose__c = 'Client Meeting',
            Origin__c = 'Chennai',
            Destination__c = 'Bengaluru',
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(3),
            Travel_Cost__c = 3000,
            Hotel_Cost__c = 4000,
            Other_Estimated_Cost__c = 1000,
            Travel_Status__c = 'Draft'
        );
        insert req;

        // Verify trigger on update to Approved
        Test.startTest();
        req.Travel_Status__c = 'Approved';
        update req;
        Test.stopTest();

        List<Expense_Report__c> reports = [
            SELECT Id, Travel_Request__c, Expense_Status__c
            FROM Expense_Report__c
            WHERE Travel_Request__c = :req.Id
        ];
        System.assertNotEquals(0, reports.size(), 'Expense report should be created automatically.');
        System.assertEquals('Draft', reports[0].Expense_Status__c);

        // Test invocable method directly with existing report
        TravelExpenseReportSync.Request syncReq = new TravelExpenseReportSync.Request();
        syncReq.travelRequestId = req.Id;

        List<TravelExpenseReportSync.Result> results =
            TravelExpenseReportSync.createReportIfMissing(
                new List<TravelExpenseReportSync.Request>{ syncReq }
            );

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].created);
        System.assertEquals(reports[0].Id, results[0].expenseReportId);

        // Test empty/null requests
        System.assertEquals(0, TravelExpenseReportSync.createReportIfMissing(null).size());
        System.assertEquals(0, TravelExpenseReportSync.createReportIfMissing(new List<TravelExpenseReportSync.Request>()).size());
    }
}