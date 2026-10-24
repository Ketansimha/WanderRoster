public with sharing class TravelExpenseReportSync {

    public class Request {
        @InvocableVariable(required=true)
        public Id travelRequestId;
    }

    public class Result {
        @InvocableVariable
        public Id expenseReportId;

        @InvocableVariable
        public Boolean created;
    }

    @InvocableMethod(
        label='Create Expense Report If Missing'
        description='Creates a draft expense report after travel approval.'
    )
    public static List<Result> createReportIfMissing(
        List<Request> requests
    ) {
        List<Result> results = new List<Result>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        // Collect valid travel request IDs.
        Set<Id> travelIds = new Set<Id>();

        for (Request request : requests) {
            if (request != null &&
                request.travelRequestId != null) {
                travelIds.add(request.travelRequestId);
            }
        }

        // Keep the result list aligned with the input list.
        for (Integer i = 0; i < requests.size(); i++) {
            Result result = new Result();
            result.created = false;
            results.add(result);
        }

        if (travelIds.isEmpty()) {
            return results;
        }

        // Retrieve travel requests.
        Map<Id, Travel_Request__c> travels =
            new Map<Id, Travel_Request__c>([
                SELECT Id, Employee__c, Travel_Status__c
                FROM Travel_Request__c
                WHERE Id IN :travelIds
            ]);

        // Find existing reports without changing their status.
        Map<Id, Expense_Report__c> existingByTravel =
            new Map<Id, Expense_Report__c>();

        for (Expense_Report__c report : [
            SELECT Id, Travel_Request__c
            FROM Expense_Report__c
            WHERE Travel_Request__c IN :travelIds
        ]) {
            existingByTravel.put(
                report.Travel_Request__c,
                report
            );
        }

        List<Expense_Report__c> reportsToInsert =
            new List<Expense_Report__c>();

        Map<Integer, Id> resultIndexToTravelId =
            new Map<Integer, Id>();

        for (Integer i = 0; i < requests.size(); i++) {
            Request request = requests[i];

            if (request == null ||
                request.travelRequestId == null) {
                continue;
            }

            Id travelId = request.travelRequestId;
            Travel_Request__c travel = travels.get(travelId);

            // Only process approved travel requests.
            if (travel == null ||
                travel.Travel_Status__c != 'Approved') {
                continue;
            }

            // Reuse the existing report without changing its status.
            if (existingByTravel.containsKey(travelId)) {
                results[i].expenseReportId =
                    existingByTravel.get(travelId).Id;
                continue;
            }

            // Create a draft report; finance approval happens later.
            Expense_Report__c report = new Expense_Report__c(
                Travel_Request__c = travelId,
                Employee__c = travel.Employee__c,
                Expense_Status__c = 'Draft'
            );
            if (Expense_Report__c.sObjectType.getDescribe().fields.getMap().containsKey('Travel_Manager_Approved__c')) {
                report.put('Travel_Manager_Approved__c', true);
            }

            reportsToInsert.add(report);
            resultIndexToTravelId.put(i, travelId);

            // Prevent duplicate reports for repeated IDs in this batch.
            existingByTravel.put(travelId, report);
        }

        if (!reportsToInsert.isEmpty()) {
            insert reportsToInsert;

            for (Integer i = 0; i < reportsToInsert.size(); i++) {
                Expense_Report__c insertedReport =
                    reportsToInsert[i];

                for (Integer resultIndex :
                     resultIndexToTravelId.keySet()) {

                    if (resultIndexToTravelId.get(resultIndex) ==
                        insertedReport.Travel_Request__c) {

                        results[resultIndex].expenseReportId =
                            insertedReport.Id;

                        results[resultIndex].created = true;
                    }
                }
            }
        }

        return results;
    }
}