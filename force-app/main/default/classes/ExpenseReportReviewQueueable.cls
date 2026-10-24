public class ExpenseReportReviewQueueable
    implements Queueable {

    private List<Id> reportIds;

    public ExpenseReportReviewQueueable(List<Id> reportIds) {
        this.reportIds = reportIds;
    }

    public ExpenseReportReviewQueueable(Set<Id> reportIds) {
        this.reportIds = reportIds == null ? new List<Id>() : new List<Id>(reportIds);
    }

    public void execute(QueueableContext context) {
        if (reportIds == null || reportIds.isEmpty()) {
            return;
        }

        List<Expense_Report__c> reports = [
            SELECT Id, Expense_Status__c
            FROM Expense_Report__c
            WHERE Id IN :reportIds
        ];

        String targetStatus = 'Under Review';
        for (Schema.PicklistEntry ple : Expense_Report__c.Expense_Status__c.getDescribe().getPicklistValues()) {
            if (ple.isActive() && ple.getValue() == 'Pending Approval') {
                targetStatus = 'Pending Approval';
                break;
            }
        }

        for (Expense_Report__c report : reports) {
            if (report.Expense_Status__c == 'Submitted') {
                report.Expense_Status__c = targetStatus;
            }
        }

        update reports;
    }
}