@IsTest
private class ExpenseSettlementControllerTest {

    @IsTest
    static void testFullSettlementLifecycle() {
        // 1. Create Travel Request
        Travel_Request__c tr = new Travel_Request__c(
            Travel_Purpose__c = 'Client Meeting',
            Origin__c = 'Chennai',
            Destination__c = 'Bengaluru',
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(3),
            Travel_Cost__c = 3000,
            Hotel_Cost__c = 4000,
            Other_Estimated_Cost__c = 1000,
            Travel_Status__c = 'Approved',
            Manager_Approval_Status__c = 'Approved',
            Finance_Review_Status__c = 'Cleared'
        );
        insert tr;

        // 2. Create linked Expense Report
        Expense_Report__c report = new Expense_Report__c(
            Travel_Request__c = tr.Id,
            Expense_Status__c = 'Draft'
        );
        insert report;

        // 3. Create linked Expense Item (within limit: Hotel cap is 5000)
        Expense_Item__c item = new Expense_Item__c(
            Expense_Report__c = report.Id,
            Expense_Category__c = 'Hotel',
            Amount__c = 4000,
            Expense_Date__c = Date.today(),
            Vendor_Name__c = 'Grand Hotel'
        );
        insert item;

        Test.startTest();

        // 4. Test getDashboard
        ExpenseSettlementController.DashboardData dash =
            ExpenseSettlementController.getDashboard();
        System.assertNotEquals(null, dash);

        // 5. Test getExpenseItems
        List<Expense_Item__c> items =
            ExpenseSettlementController.getExpenseItems(report.Id);
        System.assertEquals(1, items.size());

        // 6. Test submitExpenses
        ExpenseSettlementController.submitExpenses(report.Id);

        Expense_Report__c submittedReport = [
            SELECT Id, Expense_Status__c
            FROM Expense_Report__c
            WHERE Id = :report.Id
        ];
        System.assert(
            submittedReport.Expense_Status__c == 'Pending Approval' ||
            submittedReport.Expense_Status__c == 'Under Review' ||
            submittedReport.Expense_Status__c == 'Submitted',
            'Report should be in pending review status.'
        );

        // 7. Test financeDecision - Approve
        ExpenseSettlementController.financeDecision(
            report.Id,
            'Approve',
            'Looks good to settle',
            submittedReport.Expense_Status__c == 'Approved' ? null : null
        );

        Expense_Report__c approvedReport = [
            SELECT Id, Expense_Status__c
            FROM Expense_Report__c
            WHERE Id = :report.Id
        ];
        System.assertEquals('Approved', approvedReport.Expense_Status__c);

        // 8. Test markSettled
        ExpenseSettlementController.markSettled(report.Id);

        Expense_Report__c settledReport = [
            SELECT Id, Expense_Status__c
            FROM Expense_Report__c
            WHERE Id = :report.Id
        ];
        System.assert(
            settledReport.Expense_Status__c == 'Paid' ||
            settledReport.Expense_Status__c == 'Reimbursed',
            'Report should be marked paid or reimbursed.'
        );

        Test.stopTest();
    }

    @IsTest
    static void testRejectionFlow() {
        Travel_Request__c tr = new Travel_Request__c(
            Travel_Purpose__c = 'Client Meeting',
            Origin__c = 'Chennai',
            Destination__c = 'Bengaluru',
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(3),
            Travel_Cost__c = 3000,
            Hotel_Cost__c = 4000,
            Other_Estimated_Cost__c = 1000,
            Travel_Status__c = 'Approved',
            Manager_Approval_Status__c = 'Approved'
        );
        insert tr;

        Expense_Report__c report = new Expense_Report__c(
            Travel_Request__c = tr.Id,
            Expense_Status__c = 'Draft'
        );
        insert report;

        Expense_Item__c item = new Expense_Item__c(
            Expense_Report__c = report.Id,
            Expense_Category__c = 'Meals',
            Amount__c = 800,
            Expense_Date__c = Date.today()
        );
        insert item;

        ExpenseSettlementController.submitExpenses(report.Id);

        Test.startTest();
        ExpenseSettlementController.financeDecision(
            report.Id,
            'Reject',
            'Missing valid bill copy',
            null
        );
        Test.stopTest();

        Expense_Report__c rejectedReport = [
            SELECT Id, Expense_Status__c
            FROM Expense_Report__c
            WHERE Id = :report.Id
        ];
        System.assertEquals('Rejected', rejectedReport.Expense_Status__c);
    }

    @IsTest
    static void testExceptions() {
        try {
            ExpenseSettlementController.getExpenseItems(null);
            System.assert(false, 'Should throw exception for null report ID');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            ExpenseSettlementController.submitExpenses(null);
            System.assert(false, 'Should throw exception for null report ID');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            ExpenseSettlementController.financeDecision(null, 'Approve', '', null);
            System.assert(false, 'Should throw exception for null report ID');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            ExpenseSettlementController.markSettled(null);
            System.assert(false, 'Should throw exception for null report ID');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}