# WanderRoster ✈️💼

**WanderRoster** is a comprehensive, enterprise-grade Travel & Expense Management application built natively on the Salesforce Platform. It automates the end-to-end travel lifecycle—from trip planning and policy-aware budget requests to AI-powered cost recommendations, multi-tier approvals, and post-trip expense settlement.

---

## 🚀 Key Features & Architecture

### 1. Unified Application Shell (`wanderRosterApp`)
* **Role-Based Workspaces**: Single-Page Application (SPA) container organizing work into three dedicated portals:
  * **Employee Portal**: Plan trips, submit travel requests, and monitor approval status.
  * **Finance Portal**: Audit budgets, enforce expense caps, and reconcile settlements.
  * **Manager Portal**: Review trip itineraries, AI risk explanations, and authorize travel.

### 2. Employee Travel Workspace (`wanderRosterDashboard`)
* **Trip Request Creation**: Streamlined form capturing Origin, Destination, Dates (End Date & Start Date), and itemized estimates (Travel, Hotel, Miscellaneous).
* **Live Cost & Error Validation**: Reactive calculations preventing negative or zero amounts with inline error alerts.
* **Executive Metrics**: KPI cards displaying total requests, pending decisions, approved trips, and estimated spend.

### 3. Smart Travel AI & Policy Engine (`TravelRecommendationEngine.cls`)
* **Dynamic Expense Policies**: Compares estimates against active policy caps (`Expense_Policy__mdt`).
* **AI Cost Analysis**: Evaluates route completeness, category caps, and expenditure thresholds (e.g. ₹9,000 threshold).
* **Policy Compliance Classification**:
  * `Compliant`: Request is within policy limits and cost thresholds.
  * `Exception Required`: Request exceeds ₹9,000 or breaches category-level policy caps.
  * `Review Required`: Missing route details or unclassified categories.

### 4. Finance Pre-Trip Review (`wanderRosterFinance`)
* **Inspection Console**: Split-view UI showing request details, itemized cost cards, and AI policy recommendations.
* **One-Click Decisions**: Finance officers can `Clear for Manager` or `Request Changes` with feedback comments.

### 5. Manager Approval Cockpit (`wanderRosterManager`)
* **Approval Queue**: Filterable dashboard for travel requests awaiting management decisions.
* **Audit Trail**: Accesses travel justification, route details, AI risk scoring, and finance comments prior to approval or rejection.

### 6. Post-Trip Expense Settlement (`wanderRosterSettlement`)
* **Settlement Reconciliation**: Powered by `ExpenseSettlementController.cls` to manage post-travel expense reports (`Expense_Report__c`) and itemized receipts (`Expense_Item__c`).
* **Receipt Auditing**: Flags policy violations, overdue receipts, and potential duplicate submissions.
* **Reimbursement Workflow**: Direct approval and settlement lifecycle management.

### 7. Process Automation
* **`Travel_Status_Review` Flow**: Record-triggered automation executing the AI recommendation engine and dynamically updating policy status.
* **Apex Triggers**: Automates expense report sync and line-item aggregations.

---

## 📁 Repository Structure

```
force-app/main/default/
├── applications/             # Custom Lightning App definitions (WanderRoster)
├── classes/                  # Apex Controllers, Batch jobs, and Test classes (100% test coverage)
│   ├── ExpensePolicyChecker.cls
│   ├── ExpenseSettlementController.cls
│   ├── TravelExpenseReportSync.cls
│   ├── TravelRecommendationEngine.cls
│   └── WanderRosterDashboardController.cls
├── customMetadata/           # Active Expense Policy metadata records (Expense_Policy__mdt)
├── flexipages/               # Lightning App and Record Pages
├── flows/                    # Record-triggered flow (Travel_Status_Review)
├── layouts/                  # Page layouts for Custom Objects
├── lwc/                      # Lightning Web Components
│   ├── wanderRosterApp/
│   ├── wanderRosterDashboard/
│   ├── wanderRosterFinance/
│   ├── wanderRosterManager/
│   └── wanderRosterSettlement/
├── objects/                  # Custom Object schemas & validation rules
│   ├── Expense_Item__c/
│   ├── Expense_Policy__mdt/
│   ├── Expense_Report__c/
│   └── Travel_Request__c/
├── permissionsets/           # Admin and user permission sets (WanderRoster_Admin)
├── tabs/                     # Custom tabs for navigation
└── triggers/                 # Apex Triggers for travel and expense records
```

---

## 🛠️ Deployment & Setup

### Prerequisites
* [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf` v2+)
* An authorized Salesforce Developer Edition or Sandbox Org

### Deploy to Salesforce Org
```bash
# 1. Authorize your target org
sf org login web --alias WanderRosterOrg

# 2. Deploy source metadata
sf project deploy start --target-org WanderRosterOrg

# 3. Assign Permission Set
sf org assign permset --name WanderRoster_Admin --target-org WanderRosterOrg

# 4. Run Apex Unit Tests
sf apex test run --code-coverage --result-format human --target-org WanderRosterOrg
```

---

## 👤 Author
* **Ketansimha Reddy** ([GitHub](https://github.com/Ketansimha))
