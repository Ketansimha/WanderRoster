public class ExpenseReportQueueableAction {

    @InvocableMethod(
        label='Queue Expense Report Review'
        description='Queues submitted expense reports for review.'
    )
    public static void queueReview(List<Id> reportIds) {
        Set<Id> uniqueReportIds = new Set<Id>();

        for (Id reportId : reportIds) {
            if (reportId != null) {
                uniqueReportIds.add(reportId);
            }
        }

        if (!uniqueReportIds.isEmpty()) {
            System.enqueueJob(
                new ExpenseReportReviewQueueable(uniqueReportIds)
            );
        }
    }
}