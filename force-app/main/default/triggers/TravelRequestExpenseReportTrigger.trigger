trigger TravelRequestExpenseReportTrigger on Travel_Request__c (
    after insert,
    after update
) {
    List<TravelExpenseReportSync.Request> requests =
        new List<TravelExpenseReportSync.Request>();

    for (Travel_Request__c travel : Trigger.new) {
        Boolean isApproved =
            travel.Travel_Status__c == 'Approved';

        if (Trigger.isUpdate) {
            Travel_Request__c oldTravel =
                Trigger.oldMap.get(travel.Id);

            isApproved = isApproved &&
                oldTravel.Travel_Status__c != 'Approved';
        }

        if (isApproved) {
            TravelExpenseReportSync.Request request =
                new TravelExpenseReportSync.Request();

            request.travelRequestId = travel.Id;
            requests.add(request);
        }
    }

    if (!requests.isEmpty()) {
        TravelExpenseReportSync.createReportIfMissing(requests);
    }
}