@IsTest
private class ExpensePolicyCheckerTest {

    @IsTest
    static void testMissingPolicy() {
        System.assertEquals(
            false,
            ExpensePolicyChecker.exceedsLimit(
                'NoSuchCategory', 500
            ),
            'Missing policy should not flag an expense.'
        );
    }

    @IsTest
    static void testNullAmount() {
        System.assertEquals(
            false,
            ExpensePolicyChecker.exceedsLimit(
                'Transport', null
            ),
            'Null amount should not exceed a policy limit.'
        );
    }

    @IsTest
    static void testBelowLimit() {
        System.assertEquals(
            false,
            ExpensePolicyChecker.exceedsLimit(
                'Transport', 1500
            ),
            'Amount below the limit should pass.'
        );
    }

    @IsTest
    static void testAtLimit() {
        System.assertEquals(
            false,
            ExpensePolicyChecker.exceedsLimit(
                'Transport', 2000
            ),
            'Amount equal to the limit should pass.'
        );
    }

    @IsTest
    static void testAboveLimit() {
        System.assertEquals(
            true,
            ExpensePolicyChecker.exceedsLimit(
                'Transport', 2500
            ),
            'Amount above the limit should be flagged.'
        );
    }

    @IsTest
    static void testInactivePolicy() {
        System.assertEquals(
            false,
            ExpensePolicyChecker.exceedsLimit(
                'InactiveTest', 2500
            ),
            'An inactive policy should not be applied.'
        );
    }

    @IsTest
    static void testGetPolicyExplanation() {
        String res1 = ExpensePolicyChecker.getPolicyExplanation('', 100);
        System.assert(res1.contains('Requires review'));

        String res2 = ExpensePolicyChecker.getPolicyExplanation('NoSuchCategory', 100);
        System.assert(res2.contains('no active policy limit'));

        String res3 = ExpensePolicyChecker.getPolicyExplanation('Transport', 1500);
        System.assert(res3.contains('Within policy'));

        String res4 = ExpensePolicyChecker.getPolicyExplanation('Transport', 2500);
        System.assert(res4.contains('Policy violation'));
    }

    @IsTest
    static void testEvaluateReport() {
        Expense_Report__c report = new Expense_Report__c(
            Expense_Status__c = 'Draft'
        );
        insert report;

        // Empty items evaluation
        ExpensePolicyChecker.EvaluationResult resEmpty =
            ExpensePolicyChecker.evaluateReport(report.Id);
        System.assert(
            resEmpty.policyStatus == 'Requires Review' ||
            resEmpty.policyStatus == 'Review Required',
            'Policy status should be Requires Review or Review Required.'
        );

        // Add valid items
        Expense_Item__c item1 = new Expense_Item__c(
            Expense_Report__c = report.Id,
            Expense_Category__c = 'Hotel',
            Amount__c = 4000,
            Expense_Date__c = Date.today()
        );
        insert item1;

        ExpensePolicyChecker.EvaluationResult resValid =
            ExpensePolicyChecker.evaluateReport(report.Id);
        System.assert(
            resValid.policyStatus == 'Within Policy' ||
            resValid.policyStatus == 'Compliant',
            'Policy status should be Within Policy or Compliant.'
        );

        // Add violation item
        Expense_Item__c item2 = new Expense_Item__c(
            Expense_Report__c = report.Id,
            Expense_Category__c = 'Hotel',
            Amount__c = 9000,
            Expense_Date__c = Date.today()
        );
        insert item2;

        ExpensePolicyChecker.EvaluationResult resViolation =
            ExpensePolicyChecker.evaluateReport(report.Id);
        System.assert(
            resViolation.policyStatus == 'Policy Violation' ||
            resViolation.policyStatus == 'Exception Required',
            'Policy status should be Policy Violation or Exception Required.'
        );

        // Exceptions
        try {
            ExpensePolicyChecker.evaluateReport(null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}