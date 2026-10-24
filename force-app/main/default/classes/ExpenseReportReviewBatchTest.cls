@IsTest
private class ExpenseReportReviewBatchTest {

    @IsTest
    static void testMultipleReports() {

        List<Expense_Report__c> reports =
            new List<Expense_Report__c>{
                new Expense_Report__c(
                    Expense_Status__c = 'Submitted'
                ),
                new Expense_Report__c(
                    Expense_Status__c = 'Submitted'
                ),
                new Expense_Report__c(
                    Expense_Status__c = 'Submitted'
                ),
                new Expense_Report__c(
                    Expense_Status__c = 'Draft'
                )
            };

        insert reports;

        Test.startTest();
        Database.executeBatch(
            new ExpenseReportReviewBatch(), 200
        );
        Test.stopTest();

        List<Expense_Report__c> results = [
            SELECT Id, Expense_Status__c
            FROM Expense_Report__c
            WHERE Id IN :reports
        ];

        System.assertEquals(
            4, results.size(),
            'Four expense reports should exist'
        );

        Map<Id, Expense_Report__c> resultsById =
            new Map<Id, Expense_Report__c>(results);

      System.debug(
    'Actual Draft report status: ' +
    resultsById.get(reports[3].Id).Expense_Status__c
);

        System.assertEquals(
            'Under Review',
            resultsById.get(reports[0].Id).Expense_Status__c
        );

        System.assertEquals(
            'Under Review',
            resultsById.get(reports[1].Id).Expense_Status__c
        );

        System.assertEquals(
            'Under Review',
            resultsById.get(reports[2].Id).Expense_Status__c
        );

        System.assertEquals(
            'Draft',
            resultsById.get(reports[3].Id).Expense_Status__c,
            'Draft reports should remain unchanged'
        );
    }

    @IsTest
    static void testScheduler() {
        Expense_Report__c report = new Expense_Report__c(
            Expense_Status__c = 'Submitted'
        );
        insert report;

        Test.startTest();
        new ExpenseReportReviewScheduler().execute(null);
        Test.stopTest();

        List<Expense_Report__c> results = [
            SELECT Id, Expense_Status__c
            FROM Expense_Report__c
            WHERE Id = :report.Id
        ];
        System.assertEquals('Under Review', results[0].Expense_Status__c);
    }

    @IsTest
    static void testSchedulerJob() {
        Test.startTest();
        String cronExpr = '0 0 0 15 3 ? 2042';
        String jobId = System.schedule('TestExpenseReportReviewSchedulerJob', cronExpr, new ExpenseReportReviewScheduler());
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }
}