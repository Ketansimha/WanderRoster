@IsTest
private class ExpenseReportTotalCalculatorTest {

    @IsTest
    static void testExpenseReportTotal() {

        Expense_Report__c report = new Expense_Report__c();
        insert report;

        Expense_Item__c item1 = new Expense_Item__c(
            Expense_Report__c = report.Id,
            Amount__c = 2600
        );
        insert item1;

        Test.startTest();

        Expense_Item__c item2 = new Expense_Item__c(
            Expense_Report__c = report.Id,
            Amount__c = 400
        );
        insert item2;

        Test.stopTest();

        Expense_Report__c updatedReport = [
            SELECT Total_Amount__c
            FROM Expense_Report__c
            WHERE Id = :report.Id
        ];

        System.assertEquals(
            Decimal.valueOf('3000'),
            updatedReport.Total_Amount__c,
            'Expense Report total should equal the sum of its Expense Items.'
        );
    }

    @IsTest
    static void testEmptyAndNullReportIds() {
        Test.startTest();
        ExpenseReportTotalCalculator.updateTotals(null);
        ExpenseReportTotalCalculator.updateTotals(new Set<Id>());
        Test.stopTest();
    }

    @IsTest
    static void testReportWithNoExpenseItems() {
        Expense_Report__c report = new Expense_Report__c();
        insert report;

        Test.startTest();
        ExpenseReportTotalCalculator.updateTotals(new Set<Id>{ report.Id });
        Test.stopTest();

        Expense_Report__c updatedReport = [
            SELECT Total_Amount__c
            FROM Expense_Report__c
            WHERE Id = :report.Id
        ];
        System.assertEquals(0, updatedReport.Total_Amount__c);
    }
}