trigger ExpenseItemTotalTrigger on Expense_Item__c (
    after insert,
    after update,
    after delete,
    after undelete
) {
    Set<Id> reportIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Expense_Item__c item : Trigger.new) {
            if (item.Expense_Report__c != null) {
                reportIds.add(item.Expense_Report__c);
            }
        }
    }

    if (Trigger.isUpdate || Trigger.isDelete) {
        for (Expense_Item__c item : Trigger.old) {
            if (item.Expense_Report__c != null) {
                reportIds.add(item.Expense_Report__c);
            }
        }
    }

    ExpenseReportTotalCalculator.updateTotals(reportIds);
}