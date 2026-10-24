@IsTest
private class ExpenseReportReviewQueueableTest {

    @IsTest
    static void testSubmittedReportMovesToPendingApproval() {
        Expense_Report__c report = new Expense_Report__c(
            Expense_Status__c = 'Submitted'
        );
        insert report;

        Test.startTest();
        System.enqueueJob(
            new ExpenseReportReviewQueueable(
                new Set<Id>{ report.Id }
            )
        );
        Test.stopTest();

        Expense_Report__c result = [
            SELECT Expense_Status__c
            FROM Expense_Report__c
            WHERE Id = :report.Id
        ];

        System.assertEquals(
            'Under Review',
            result.Expense_Status__c,
            'Submitted report should move to Under Review.'
        );
    }

    @IsTest
    static void testQueueableAction() {
        Expense_Report__c report = new Expense_Report__c(
            Expense_Status__c = 'Submitted'
        );
        insert report;

        Test.startTest();
        ExpenseReportQueueableAction.queueReview(new List<Id>{ report.Id, null });
        Test.stopTest();

        Expense_Report__c result = [
            SELECT Expense_Status__c
            FROM Expense_Report__c
            WHERE Id = :report.Id
        ];

        System.assertEquals(
            'Under Review',
            result.Expense_Status__c,
            'Queueable action should update status to Under Review.'
        );
    }
}