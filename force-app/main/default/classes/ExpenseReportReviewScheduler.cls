public class ExpenseReportReviewScheduler implements Schedulable {

    public void execute(SchedulableContext context) {
        Database.executeBatch(
            new ExpenseReportReviewBatch(),
            200
        );
    }
}