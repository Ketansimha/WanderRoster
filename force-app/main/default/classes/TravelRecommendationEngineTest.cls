@IsTest
private class TravelRecommendationEngineTest {

    @IsTest
    static void testRecommendationGeneration() {
        Travel_Request__c request = new Travel_Request__c(
            Travel_Purpose__c = 'Client Meeting',
            Origin__c = 'Chennai',
            Destination__c = 'Bengaluru',
            Travel_Cost__c = 1800,
            Hotel_Cost__c = 2000,
            Other_Estimated_Cost__c = 500,
            Start_Date__c = Date.today().addDays(7),
            End_Date__c = Date.today().addDays(9)
        );

        insert request;

        TravelRecommendationEngine.RequestInput input =
            new TravelRecommendationEngine.RequestInput();

        input.travelRequestId = request.Id;

        Test.startTest();

        List<TravelRecommendationEngine.RecommendationOutput> results =
            TravelRecommendationEngine.generateRecommendations(
                new List<TravelRecommendationEngine.RequestInput>{ input }
            );

        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].recommendation);
        System.assertNotEquals(null, results[0].explanation);
        System.assertEquals(0, results[0].riskScore);
        System.assertEquals('Compliant', results[0].policyStatus);
    }

    @IsTest
    static void testMissingIdAndNotFound() {
        TravelRecommendationEngine.RequestInput nullInput = null;
        TravelRecommendationEngine.RequestInput emptyInput = new TravelRecommendationEngine.RequestInput();
        TravelRecommendationEngine.RequestInput notFoundInput = new TravelRecommendationEngine.RequestInput();
        notFoundInput.travelRequestId = Travel_Request__c.sObjectType.getDescribe().getKeyPrefix() + '000000000001AAA';

        Test.startTest();
        List<TravelRecommendationEngine.RecommendationOutput> results =
            TravelRecommendationEngine.generateRecommendations(
                new List<TravelRecommendationEngine.RequestInput>{ nullInput, emptyInput, notFoundInput }
            );
        Test.stopTest();

        System.assertEquals(3, results.size());
        System.assertEquals(100, results[0].riskScore);
        System.assertEquals(100, results[1].riskScore);
        System.assertEquals(100, results[2].riskScore);
        System.assertEquals('Not Evaluated', results[0].policyStatus);
    }

    @IsTest
    static void testHighHotelCostAndMissingOrigin() {
        Travel_Request__c request = new Travel_Request__c(
            Travel_Purpose__c = 'Client Meeting',
            Destination__c = 'Bengaluru',
            Origin__c = '',
            Travel_Cost__c = 500,
            Hotel_Cost__c = 3000,
            Other_Estimated_Cost__c = 500,
            Start_Date__c = Date.today().addDays(7),
            End_Date__c = Date.today().addDays(9)
        );
        insert request;

        TravelRecommendationEngine.RequestInput input = new TravelRecommendationEngine.RequestInput();
        input.travelRequestId = request.Id;

        Test.startTest();
        List<TravelRecommendationEngine.RecommendationOutput> results =
            TravelRecommendationEngine.generateRecommendations(
                new List<TravelRecommendationEngine.RequestInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].riskScore >= 40, 'Risk score should reflect missing origin and high hotel cost');
        System.assertEquals('Review Required', results[0].policyStatus);
    }

    @IsTest
    static void testZeroCosts() {
        Travel_Request__c request = new Travel_Request__c(
            Travel_Purpose__c = 'Client Meeting',
            Origin__c = 'Chennai',
            Destination__c = 'Bengaluru',
            Travel_Cost__c = 0,
            Hotel_Cost__c = 0,
            Other_Estimated_Cost__c = 0,
            Start_Date__c = Date.today().addDays(7),
            End_Date__c = Date.today().addDays(9)
        );
        insert request;

        TravelRecommendationEngine.RequestInput input = new TravelRecommendationEngine.RequestInput();
        input.travelRequestId = request.Id;

        Test.startTest();
        List<TravelRecommendationEngine.RecommendationOutput> results =
            TravelRecommendationEngine.generateRecommendations(
                new List<TravelRecommendationEngine.RequestInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(0, results[0].riskScore);
        System.assertEquals('Compliant', results[0].policyStatus);
    }

    @IsTest
    static void testEstimatedCostAbove9000() {
        Travel_Request__c request = new Travel_Request__c(
            Travel_Purpose__c = 'Client Meeting',
            Origin__c = 'Chennai',
            Destination__c = 'Bengaluru',
            Travel_Cost__c = 6000,
            Hotel_Cost__c = 3000,
            Other_Estimated_Cost__c = 1000,
            Start_Date__c = Date.today().addDays(7),
            End_Date__c = Date.today().addDays(9)
        );
        insert request;

        TravelRecommendationEngine.RequestInput input = new TravelRecommendationEngine.RequestInput();
        input.travelRequestId = request.Id;

        Test.startTest();
        List<TravelRecommendationEngine.RecommendationOutput> results =
            TravelRecommendationEngine.generateRecommendations(
                new List<TravelRecommendationEngine.RequestInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].riskScore >= 20, 'Risk score should reflect cost above 9000');
        System.assert(results[0].explanation.contains('9000'), 'Explanation should mention 9000');
        System.assertEquals('Exception Required', results[0].policyStatus);
    }

    @IsTest
    static void testCategoryLimitPolicyStatus() {
        Travel_Request__c request = new Travel_Request__c(
            Travel_Purpose__c = 'Client Meeting',
            Origin__c = 'Chennai',
            Destination__c = 'Bengaluru',
            Travel_Cost__c = 1000,
            Hotel_Cost__c = 6000,
            Other_Estimated_Cost__c = 500,
            Start_Date__c = Date.today().addDays(7),
            End_Date__c = Date.today().addDays(8)
        );
        insert request;

        TravelRecommendationEngine.RequestInput input = new TravelRecommendationEngine.RequestInput();
        input.travelRequestId = request.Id;

        Test.startTest();
        List<TravelRecommendationEngine.RecommendationOutput> results =
            TravelRecommendationEngine.generateRecommendations(
                new List<TravelRecommendationEngine.RequestInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Exception Required', results[0].policyStatus);
    }
}