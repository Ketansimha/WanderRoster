public with sharing class TravelRecommendationEngine {

    public class RequestInput {
        @InvocableVariable(
            required=true
            label='Travel Request ID'
        )
        public Id travelRequestId;
    }

    public class RecommendationOutput {
        @InvocableVariable(label='AI Recommendation')
        public String recommendation;

        @InvocableVariable(label='AI Explanation')
        public String explanation;

        @InvocableVariable(label='AI Risk Score')
        public Integer riskScore;

        @InvocableVariable(label='Policy Status')
        public String policyStatus;
    }

    @InvocableMethod(
        label='Generate Travel Recommendation'
        description='Analyzes a travel request and suggests cost-saving actions.'
    )
    public static List<RecommendationOutput> generateRecommendations(
        List<RequestInput> requests
    ) {
        List<RecommendationOutput> results =
            new List<RecommendationOutput>();

        Set<Id> requestIds = new Set<Id>();

        for (RequestInput input : requests) {
            if (input != null && input.travelRequestId != null) {
                requestIds.add(input.travelRequestId);
            }
        }

        Map<Id, Travel_Request__c> travelRequests =
            new Map<Id, Travel_Request__c>([
                SELECT Id, Origin__c, Destination__c,
                       Travel_Cost__c, Hotel_Cost__c,
                       Other_Estimated_Cost__c,
                       Estimated_Total__c,
                       Start_Date__c, End_Date__c
                FROM Travel_Request__c
                WHERE Id IN :requestIds
            ]);

        Map<String, Decimal> policyLimits = new Map<String, Decimal>();
        for (Expense_Policy__mdt policy : [
            SELECT Expense_Category__c, Maximum_Amount__c
            FROM Expense_Policy__mdt
            WHERE Active__c = true
        ]) {
            if (!String.isBlank(policy.Expense_Category__c) && policy.Maximum_Amount__c != null) {
                policyLimits.put(
                    policy.Expense_Category__c.trim().toLowerCase(),
                    policy.Maximum_Amount__c
                );
            }
        }

        Decimal hotelLimit = policyLimits.containsKey('hotel') ? policyLimits.get('hotel') : 5000;
        Decimal transportLimit = policyLimits.containsKey('transport') ? policyLimits.get('transport') : 2000;
        Decimal miscLimit = policyLimits.containsKey('miscellaneous') ? policyLimits.get('miscellaneous') : 1000;

        for (RequestInput input : requests) {
            RecommendationOutput output =
                new RecommendationOutput();

            output.riskScore = 0;

            Travel_Request__c travelRequest =
                input == null
                ? null
                : travelRequests.get(input.travelRequestId);

            if (travelRequest == null) {
                output.recommendation =
                    'Travel request not found.';
                output.explanation =
                    'Check the Travel Request ID and try again.';
                output.riskScore = 100;
                output.policyStatus = 'Not Evaluated';
                results.add(output);
                continue;
            }

            Decimal travelCost =
                travelRequest.Travel_Cost__c == null
                ? 0 : travelRequest.Travel_Cost__c;

            Decimal hotelCost =
                travelRequest.Hotel_Cost__c == null
                ? 0 : travelRequest.Hotel_Cost__c;

            Decimal otherCost =
                travelRequest.Other_Estimated_Cost__c == null
                ? 0 : travelRequest.Other_Estimated_Cost__c;

            Decimal totalCost = travelCost + hotelCost + otherCost;

            List<String> suggestions = new List<String>();
            List<String> reasons = new List<String>();

            if (String.isBlank(travelRequest.Origin__c) ||
                String.isBlank(travelRequest.Destination__c)) {
                suggestions.add(
                    'Complete the origin and destination details.'
                );
                reasons.add(
                    'Route details are missing, so travel options cannot be compared.'
                );
                output.riskScore += 20;
            }

            if (hotelCost > 0 && totalCost > 0 &&
                hotelCost / totalCost >= 0.5) {
                suggestions.add(
                    'Compare hotel prices and nearby accommodation.'
                );
                reasons.add(
                    'Hotel cost is at least 50% of the estimated total.'
                );
                output.riskScore += 20;
            }

            if (totalCost > 9000) {
                suggestions.add(
                    'Compare available transport options before booking.'
                );
                reasons.add(
                    'Estimated total exceeds 9000. Transport prices have not been compared by this engine.'
                );
                output.riskScore += 20;
            }

            if (travelRequest.Start_Date__c != null &&
                travelRequest.End_Date__c != null &&
                travelRequest.End_Date__c < travelRequest.Start_Date__c) {
                suggestions.add(
                    'Correct the travel dates before approval.'
                );
                reasons.add(
                    'The end date is earlier than the start date.'
                );
                output.riskScore += 50;
            }

            if (suggestions.isEmpty()) {
                suggestions.add(
                    'Review the itinerary and compare current prices before booking.'
                );
                reasons.add(
                    'No specific cost concern was detected by the basic rules.'
                );
            }

            if (output.riskScore > 100) {
                output.riskScore = 100;
            }

            output.recommendation = String.join(suggestions, ' ');
            output.explanation =
                'Estimated total: ' + String.valueOf(totalCost) +
                '. Analysis: ' + String.join(reasons, ' ');

            Integer durationDays = 1;
            if (travelRequest.Start_Date__c != null &&
                travelRequest.End_Date__c != null &&
                travelRequest.End_Date__c >= travelRequest.Start_Date__c) {
                Integer diff = travelRequest.Start_Date__c.daysBetween(travelRequest.End_Date__c);
                if (diff > 0) {
                    durationDays = diff;
                }
            }

            Decimal hotelPerNight = hotelCost / durationDays;
            Decimal travelPerDay = travelCost / durationDays;

            Boolean isOverLimit = (totalCost > 9000) ||
                                  (hotelPerNight > hotelLimit) ||
                                  (travelPerDay > transportLimit) ||
                                  (otherCost > miscLimit);

            Boolean hasDateError = (travelRequest.Start_Date__c != null &&
                                    travelRequest.End_Date__c != null &&
                                    travelRequest.End_Date__c < travelRequest.Start_Date__c);

            Boolean hasRouteError = (String.isBlank(travelRequest.Origin__c) ||
                                     String.isBlank(travelRequest.Destination__c));

            if (isOverLimit) {
                output.policyStatus = 'Exception Required';
            } else if (hasDateError || hasRouteError) {
                output.policyStatus = 'Review Required';
            } else {
                output.policyStatus = 'Compliant';
            }

            results.add(output);
        }

        return results;
    }
}