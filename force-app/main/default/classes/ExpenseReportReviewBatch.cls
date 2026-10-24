public class ExpenseReportReviewBatch
    implements Database.Batchable<SObject> {

    public Database.QueryLocator start(
        Database.BatchableContext context
    ) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Expense_Report__c
            WHERE Expense_Status__c = 'Submitted'
        ]);
    }

    public void execute(
        Database.BatchableContext context,
        List<SObject> scope
    ) {
        String targetStatus = 'Under Review';
        for (Schema.PicklistEntry ple : Expense_Report__c.Expense_Status__c.getDescribe().getPicklistValues()) {
            if (ple.isActive() && ple.getValue() == 'Pending Approval') {
                targetStatus = 'Pending Approval';
                break;
            }
        }

        List<Expense_Report__c> reports =
            new List<Expense_Report__c>();

        for (SObject record : scope) {
            reports.add(
                new Expense_Report__c(
                    Id = record.Id,
                    Expense_Status__c = targetStatus
                )
            );
        }

        if (!reports.isEmpty()) {
            update reports;
        }
    }

    public void finish(Database.BatchableContext context) {
    }
}