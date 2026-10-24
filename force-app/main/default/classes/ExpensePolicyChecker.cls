public with sharing class ExpensePolicyChecker {

    public class EvaluationResult {
        @AuraEnabled public String policyStatus { get; set; }
        @AuraEnabled public Decimal riskScore { get; set; }
        @AuraEnabled public String explanation { get; set; }
        @AuraEnabled public Integer itemsChecked { get; set; }
        @AuraEnabled public Integer violations { get; set; }
    }

    private static Set<String> getPolicyStatusValues() {
        Set<String> values = new Set<String>();
        for (Schema.PicklistEntry ple : Expense_Report__c.Policy_Status__c.getDescribe().getPicklistValues()) {
            if (ple.isActive()) {
                values.add(ple.getValue());
            }
        }
        return values;
    }

    public static String getCompliantPolicyStatus() {
        Set<String> values = getPolicyStatusValues();
        if (values.contains('Within Policy')) {
            return 'Within Policy';
        }
        return 'Compliant';
    }

    public static String getViolationPolicyStatus() {
        Set<String> values = getPolicyStatusValues();
        if (values.contains('Policy Violation')) {
            return 'Policy Violation';
        }
        return 'Exception Required';
    }

    public static String getReviewRequiredPolicyStatus() {
        Set<String> values = getPolicyStatusValues();
        if (values.contains('Requires Review')) {
            return 'Requires Review';
        }
        return 'Review Required';
    }

    private static Map<String, Decimal> getActivePolicyLimits() {
        Map<String, Decimal> limits = new Map<String, Decimal>();

        for (Expense_Policy__mdt policy : [
            SELECT Expense_Category__c, Maximum_Amount__c
            FROM Expense_Policy__mdt
            WHERE Active__c = true
        ]) {
            if (!String.isBlank(policy.Expense_Category__c)
                && policy.Maximum_Amount__c != null) {
                limits.put(
                    policy.Expense_Category__c.trim().toLowerCase(),
                    policy.Maximum_Amount__c
                );
            }
        }

        return limits;
    }

    public static Boolean exceedsLimit(
        String category,
        Decimal amount
    ) {
        if (String.isBlank(category) || amount == null) {
            return false;
        }

        Map<String, Decimal> limits = getActivePolicyLimits();
        String key = category.trim().toLowerCase();

        return limits.containsKey(key)
            && amount > limits.get(key);
    }

    @AuraEnabled
    public static String getPolicyExplanation(
        String category,
        Decimal amount
    ) {
        if (String.isBlank(category) || amount == null) {
            return 'Requires review: category or amount is missing.';
        }

        Map<String, Decimal> limits = getActivePolicyLimits();
        String key = category.trim().toLowerCase();

        if (!limits.containsKey(key)) {
            return 'Requires review: no active policy limit was found for '
                + category + '.';
        }

        Decimal limitAmount = limits.get(key);

        if (amount > limitAmount) {
            return 'Policy violation: ' + category
                + ' expense exceeds the limit of ₹'
                + String.valueOf(limitAmount) + '.';
        }

        return 'Within policy: ' + category
            + ' expense is within the limit of ₹'
            + String.valueOf(limitAmount) + '.';
    }

    @AuraEnabled
    public static EvaluationResult evaluateReport(Id reportId) {
        if (reportId == null) {
            throw new AuraHandledException(
                'Expense report ID is required.'
            );
        }

        List<Expense_Report__c> reports = [
            SELECT Id, Policy_Status__c,
                   AI_Risk_Score__c, AI_Explanation__c
            FROM Expense_Report__c
            WHERE Id = :reportId
            LIMIT 1
            FOR UPDATE
        ];

        if (reports.isEmpty()) {
            throw new AuraHandledException(
                'Expense report was not found.'
            );
        }

        List<Expense_Item__c> items = [
            SELECT Id, Expense_Category__c, Amount__c,
                   Policy_Violation__c
            FROM Expense_Item__c
            WHERE Expense_Report__c = :reportId
        ];

        Map<String, Decimal> limits = getActivePolicyLimits();

        EvaluationResult result = new EvaluationResult();
        result.itemsChecked = items.size();
        result.violations = 0;

        Boolean missingPolicy = false;
        Decimal totalRisk = 0;
        List<String> findings = new List<String>();

        for (Expense_Item__c item : items) {
            Boolean violation = false;
            String category = item.Expense_Category__c;

            if (String.isBlank(category) || item.Amount__c == null) {
                missingPolicy = true;
                totalRisk += 20;
                findings.add(
                    'An expense item has a missing category or amount.'
                );
            } else {
                String key = category.trim().toLowerCase();

                if (!limits.containsKey(key)) {
                    missingPolicy = true;
                    totalRisk += 20;
                    findings.add(
                        category + ': no active policy or limit configured.'
                    );
                } else {
                    Decimal limitAmount = limits.get(key);

                    violation = item.Amount__c > limitAmount;

                    if (violation) {
                        result.violations++;
                        totalRisk += 40;
                        findings.add(
                            category + ': amount ₹'
                            + String.valueOf(item.Amount__c)
                            + ' exceeds limit ₹'
                            + String.valueOf(limitAmount) + '.'
                        );
                    }
                }
            }

            item.Policy_Violation__c = violation;
        }

        if (!items.isEmpty()) {
            update items;
        }

        if (items.isEmpty()) {
            result.policyStatus = getReviewRequiredPolicyStatus();
            result.riskScore = 50;
            result.explanation =
                'No expense items were found. Add expense items before evaluation.';
        } else {
            result.riskScore = Math.min(100, totalRisk);

            if (result.violations > 0) {
                result.policyStatus = getViolationPolicyStatus();
            } else if (missingPolicy) {
                result.policyStatus = getReviewRequiredPolicyStatus();
            } else {
                result.policyStatus = getCompliantPolicyStatus();
            }

            result.explanation = findings.isEmpty()
                ? 'All ' + items.size()
                    + ' expense items are within their configured policy limits.'
                : String.join(findings, ' ');
        }

        Expense_Report__c report = reports[0];
        report.Policy_Status__c = result.policyStatus;
        report.AI_Risk_Score__c = result.riskScore;
        report.AI_Explanation__c = result.explanation;
        update report;

        return result;
    }
}