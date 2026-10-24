public class ExpenseReportTotalCalculator {

    public static void updateTotals(Set<Id> reportIds) {
        if (reportIds == null || reportIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> totalsByReport = new Map<Id, Decimal>();

        for (AggregateResult result : [
            SELECT Expense_Report__c reportId, SUM(Amount__c) total
            FROM Expense_Item__c
            WHERE Expense_Report__c IN :reportIds
            GROUP BY Expense_Report__c
        ]) {
            totalsByReport.put(
                (Id) result.get('reportId'),
                (Decimal) result.get('total')
            );
        }

        List<Expense_Report__c> reportsToUpdate =
            new List<Expense_Report__c>();

        for (Id reportId : reportIds) {
            reportsToUpdate.add(new Expense_Report__c(
                Id = reportId,
                Total_Amount__c = totalsByReport.containsKey(reportId)
                    ? totalsByReport.get(reportId)
                    : 0
            ));
        }

        if (!reportsToUpdate.isEmpty()) {
            update reportsToUpdate;
        }
    }
}