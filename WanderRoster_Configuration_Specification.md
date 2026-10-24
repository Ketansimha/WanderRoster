# WanderRoster — Declarative Configuration Specification
## Page Layouts, Validation Rules, Custom Metadata Types & Record Types

**Target Audience:** Cognizant Technical Evaluation Panel & Project Presentation Team  
**Focus Area:** Salesforce Declarative Configuration & Data Integrity  
**Application:** WanderRoster (Corporate Travel & Expense Management System)  
**Salesforce Org:** Developer Edition (`ketan93983@mindful-hawk-qrzmyl.com` | Org ID: `00Dhg000006QzVpEAK`)  

---

## Document Scope & Purpose
This document focuses exclusively on the four foundational declarative pillars of the **WanderRoster** application:
1. **Page Layouts** — User Interface field organization, sections, field behaviors, and related lists.
2. **Validation Rules** — Database-level guardrails, formulas, logic functions, and error handling.
3. **Custom Metadata Types** — Application metadata architecture, policy decoupling, and dynamic rules.
4. **Record Types** — Business process segmentation, picklist filtering, and layout assignments.

Every section includes **technical definitions**, **WanderRoster implementations**, **Cognizant interview answers**, **comprehensive test cases**, and a **slide-by-slide PPT blueprint**.

---

# SECTION 1: Page Layouts

## 1.1 Technical Definition & Architecture
A **Page Layout** in Salesforce is a declarative mechanism that customizes the visual design and organization of detail and edit pages for Salesforce objects. 

### Core Capabilities:
* **Field Organization:** Arrange fields into customized 1-column or 2-column sections with collapsible headers.
* **Field Property Governance:** Mark fields as **Read-Only** or **Required** at the layout level.
* **Related Lists:** Determine which child object records are visible on the parent page (e.g., child Expense Reports on a Travel Request) and select specific columns to display.
* **Standard & Custom Buttons:** Control access to actions like *Edit*, *Delete*, *Clone*, and custom quick actions.
* **Assignment Mechanism:** Assigned to users based on their **Profile** and **Record Type**.

> **Cognizant Interview Note:** Field requiredness on a Page Layout is enforced **only in the browser UI**. It does *not* prevent null values inserted via Apex, Data Loader, or REST/SOAP APIs. True database requiredness must be enforced at the Custom Field definition level or via a Validation Rule.

---

## 1.2 Page Layout vs. Lightning Record Page (FlexiPage)

Cognizant panels frequently evaluate candidates on the distinction between Page Layouts and Lightning Record Pages:

| Architectural Attribute | Classic Page Layout | Lightning Record Page (FlexiPage) |
| :--- | :--- | :--- |
| **Scope of Control** | Governs the content *inside* the Record Detail component. | Governs the *entire screen canvas* (headers, tabs, sidebars, sub-tabs). |
| **Component Support** | Only standard Salesforce fields, sections, and related lists. | Can host custom **Lightning Web Components (LWCs)**, Flows, and Dashboards. |
| **Visibility Logic** | Static per profile; cannot conditionally hide a field based on data. | Supports **Component & Field Visibility Filters** (Dynamic Forms) to show/hide items conditionally. |
| **Assignment Levels** | Profile + Record Type. | 3 Hierarchy Levels: Org Default, App Default, or App + Record Type + Profile. |
| **WanderRoster Implementation** | `Travel_Request__c-Travel Request Layout`<br>`Expense_Item__c-Expense Item Layout`<br>`Expense_Report__c-Expense Report Layout` | `WanderRoster_Application` (FlexiPage)<br>`WanderRoster_Dashboard` (FlexiPage) |

---

## 1.3 Page Layouts Actually Used in WanderRoster

WanderRoster utilizes four primary page layouts configured in the project:

### 1. `Travel Request Layout` (Object: `Travel_Request__c`)
* **Metadata File:** `force-app/main/default/layouts/Travel_Request__c-Travel Request Layout.layout-meta.xml`
* **Sections & Structure:**
  * **Section 1: `Travel Details` (2 Columns, Left-to-Right):**
    * *Left Column:* `Name` (Auto-number `TR-{0000}`, Read-only), `Travel_Purpose__c` (Picklist), `Origin__c` (Text), `Start_Date__c` (Date), `Expenses_Ready_for_Approval__c` (Checkbox), `Manager_Approval_Status__c` (Picklist).
    * *Right Column:* `Employee__c` (Lookup User), `Business_Objective__c` (Text), `Destination__c` (Text), `End_Date__c` (Date).
  * **Section 2: `Estimated Costs` (2 Columns, Left-to-Right):**
    * *Left Column:* `Travel_Cost__c` (Currency), `Other_Estimated_Cost__c` (Currency).
    * *Right Column:* `Hotel_Cost__c` (Currency), `Estimated_Total__c` (Formula Currency, Read-only).
  * **Section 3: `Approval & AI Review` (2 Columns, Left-to-Right):**
    * *Left Column:* `Travel_Status__c` (Picklist), `AI_Risk_Score__c` (Number), `AI_Explanation__c` (Long Text).
    * *Right Column:* `Policy_Status__c` (Picklist), `AI_Recommendation__c` (Long Text).
  * **Section 4: `System Information`:** `CreatedById`, `LastModifiedById`, `OwnerId`.
  * **Related Lists:**
    * `Expense_Report__c.Travel_Request__c` — Displays all post-trip claims linked to this requisition.
    * `RelatedProcessHistoryList` — Full approval audit trail (Step Name, Date, Actor, Comments, Decision).

### 2. `Expense Item Layout` (Object: `Expense_Item__c`)
* **Metadata File:** `force-app/main/default/layouts/Expense_Item__c-Expense Item Layout.layout-meta.xml`
* **Sections & Structure:**
  * **Section 1: `Expense Details` (2 Columns):**
    * *Left Column:* `Name` (Read-only), `Expense_Date__c` (Date), `Amount__c` (**Required**), `Description__c` (Long Text).
    * *Right Column:* `Expense_Report__c` (**Required Master-Detail**), `Expense_Category__c` (Picklist), `Vendor_Name__c` (Text).
  * **Section 2: `Receipt Tracking` (2 Columns):**
    * *Left Column:* `Receipt_Number__c` (Text), `Receipt_Submission_Time__c` (DateTime).
    * *Right Column:* `Receipt_Status__c` (Picklist), `Receipt_Deadline__c` (DateTime).
  * **Section 3: `AI Verification` (2 Columns):**
    * *Left Column:* `Verification_Status__c` (Picklist), `Possible_Duplicate__c` (Checkbox).
    * *Right Column:* `AI_Explanation__c` (Long Text), `Policy_Violation__c` (Checkbox).

### 3. `Expense Report Layout` (Object: `Expense_Report__c`)
* Organizes high-level summary claims with trigger-aggregated `Total_Amount__c`, status badges, manager comments, and child expense items.

### 4. `Approval Page Layout: Travel Request Manager Approval`
* Dedicated approval layout displayed to managers during the formal approval stage (`04ahg000000ZFYr`), highlighting budget breakdowns and AI risk ratings before approval decisions are submitted.

---

# SECTION 2: Record Types

## 2.1 Technical Definition & Capabilities
A **Record Type** in Salesforce allows administrators to offer different business processes, picklist values, and page layouts to different users based on the operational context of a record.

### Key Capabilities of Record Types:
1. **Page Layout Assignment:** Assign different layouts to different user profiles for the same object.
2. **Picklist Value Filtering:** Display a subset of picklist values without deleting or creating duplicate fields.
3. **Business Process Association:** Enforce custom stages for Lead Processes, Sales (Opportunity) Processes, Support (Case) Processes, and Solution Processes.

---

## 2.2 Record Types in WanderRoster

### Current Implementation (Master Record Type)
* **Architecture:** Operates on the default **Master Record Type**.
* **Design Rationale:** WanderRoster uses a **Single-Page Lightning Web Component Architecture** (`wanderRosterDashboard`, `wanderRosterFinance`, `wanderRosterManager`). User role transitions (Employee vs. Finance Officer vs. Approving Manager) occur dynamically via permission sets (`WanderRoster_Admin`) and client-side reactive components. This avoids forcing users through standard Salesforce record type selection prompts during fast requisition logging.

### Enterprise Expansion Model (For Cognizant Panel Presentation)
To demonstrate enterprise scalability, WanderRoster incorporates a dual-record-type model:

```
                       TRAVEL REQUEST OBJECT
                                │
        ┌───────────────────────┴───────────────────────┐
        ▼                                               ▼
[ Domestic Travel Record Type ]        [ International Travel Record Type ]
• Fixed Base Currency: INR (₹)          • Multi-Currency / Forex Conversion
• Page Layout: Domestic Layout          • Page Layout: International Layout
• Picklist: Cab, Metro, Train, Air      • Picklist: International Air, Overseas Hotel
• Per-Diem: Standard Domestic Limits    • Extra Fields: Passport Number, Visa Status
```

1. **`Domestic_Travel` Record Type:**
   * **Assigned Layout:** Standard `Travel Request Layout`.
   * **Filtered Picklists:** `Expense_Category__c` limited to local transport, domestic hotels, and domestic meals.
   * **Field Behavior:** Passport and visa fields hidden.
2. **`International_Travel` Record Type:**
   * **Assigned Layout:** `International Travel Request Layout`.
   * **Filtered Picklists:** Includes foreign exchange fees, visa charges, international flights.
   * **Field Behavior:** Mandatory `Passport_Number__c`, `Visa_Status__c`, and `Forex_Rate__c`.

---

# SECTION 3: Validation Rules

## 3.1 Technical Definition & Execution Lifecycle
A **Validation Rule** contains a formula or expression that evaluates record data before saving.
* **Returns `TRUE`:** Condition is violated $\rightarrow$ Save is blocked, transaction rolls back, and error message is displayed.
* **Returns `FALSE`:** Data is valid $\rightarrow$ Record proceeds to the next stage of execution.

```
       [ User Clicks Save / DML Fired ]
                      │
                      ▼
       [ 1. System Validation Rules ] (Field formats, required fields)
                      │
                      ▼
       [ 2. Before Triggers Execute ]
                      │
                      ▼
       [ 3. Custom Validation Rules ] ◄── Evaluates formulas
         ├── Formula = TRUE  ──► HALT & ROLLBACK (Display Error)
         └── Formula = FALSE ──► Proceed to After Triggers & Commit
```

---

## 3.2 Key Formula Functions Explained

### 1. `ISBLANK()` vs. `ISNULL()`
* **`ISBLANK(expression)`**: Returns `TRUE` if the expression is empty or null. Works across **all data types** (Text, Number, Date, Currency, Phone).
* **`ISNULL(expression)`**: Legacy function that only worked on numbers/dates. Failed on text fields because empty text fields in Salesforce are stored as `""` (empty string), not `null`. Salesforce officially recommends `ISBLANK()`.
* **Picklist Consideration:** Picklist fields cannot be checked directly. They must be wrapped with `TEXT()`:
  ```salesforce
  ISBLANK(TEXT(Travel_Purpose__c))
  ```

### 2. `AND()` vs. `OR()`
* **`AND(cond1, cond2, ...)`**: Returns `TRUE` **only if ALL conditions are `TRUE`**. Used when multiple conditions must occur together to trigger an error.
* **`OR(cond1, cond2, ...)`**: Returns `TRUE` **if AT LEAST ONE condition is `TRUE`**. Used when violating any single rule should trigger an error.

### 3. Can a Validation Rule Replace Apex Validation?
**No.** Validation rules are ideal for declarative single-object checks, but Apex validation is mandatory when:
1. **Cross-Object Aggregate Queries:** Checking if adding a ₹2,000 expense causes an employee's total department spend to exceed ₹500,000 requires SOQL aggregation (`SUM()`).
2. **Concurrency Locking:** WanderRoster requires `SELECT ... FOR UPDATE` in Apex to prevent two approvers from approving the same record simultaneously.
3. **External API Calls:** Validating an international flight PNR or tax invoice against a government portal requires Apex HTTP callouts.

### 4. What Happens When Two Validation Rules Fail at Once?
* Salesforce evaluates **all active validation rules** and presents **ALL failing error messages simultaneously**.
* Top-of-page errors appear stacked in the top notification banner.
* Field-level errors highlight each respective field in red with its specific message beneath the field.

---

## 3.3 Active Validation Rules in WanderRoster

### Rule 1: `End_Date_After_Start_Date` (Date Integrity)
* **Object:** `Travel_Request__c` | **Active:** `true`
* **Error Location:** Top of Page (or Field: `End_Date__c`)
* **Error Message:** *"Travel end date cannot be earlier than the start date."*
* **Formula:**
  ```salesforce
  AND(
      NOT(ISBLANK(Start_Date__c)),
      NOT(ISBLANK(End_Date__c)),
      End_Date__c < Start_Date__c
  )
  ```
* **Logic Breakdown:**
  1. `NOT(ISBLANK(Start_Date__c))`: Ensures start date is populated.
  2. `NOT(ISBLANK(End_Date__c))`: Ensures end date is populated.
  3. `End_Date__c < Start_Date__c`: Evaluates whether the trip return date precedes the departure date.

#### Test Cases for Rule 1:
| Test ID | Scenario | Start Date | End Date | Expected Result | Pass/Fail Criteria |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-VR1-01** | Positive Valid Range | `2026-11-01` | `2026-11-05` | Save Succeeded | Record committed to database. |
| **TC-VR1-02** | Boundary Same-Day Trip | `2026-11-01` | `2026-11-01` | Save Succeeded | End Date is equal to Start Date (not `<`). |
| **TC-VR1-03** | Negative Inverted Dates | `2026-11-10` | `2026-11-05` | Save Blocked | Error message displayed on top banner. |
| **TC-VR1-04** | Boundary Null Dates | `null` | `2026-11-05` | Save Allowed by VR | Rule returns FALSE; caught by required field. |

---

### Rule 2: `Travel_Purpose_And_Destination_Required` (Commercial Context)
* **Object:** `Travel_Request__c` | **Active:** `true`
* **Error Location:** Top of Page
* **Error Message:** *"Enter both a travel purpose and a destination before saving the request."*
* **Formula:**
  ```salesforce
  OR(
      ISBLANK(TEXT(Travel_Purpose__c)),
      ISBLANK(Destination__c)
  )
  ```
* **Logic Breakdown:**
  1. `ISBLANK(TEXT(Travel_Purpose__c))`: Converts picklist to string; returns `TRUE` if `--None--`.
  2. `ISBLANK(Destination__c)`: Returns `TRUE` if destination text is empty.
  3. `OR(...)`: If *either* field is omitted, save is rejected.

#### Test Cases for Rule 2:
| Test ID | Scenario | Purpose | Destination | Expected Result | Pass/Fail Criteria |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-VR2-01** | Positive Complete Info | `Client Meeting` | `Mumbai` | Save Succeeded | Record committed cleanly. |
| **TC-VR2-02** | Negative Blank Destination | `Training` | `""` (Empty) | Save Blocked | Error message displayed. |
| **TC-VR2-03** | Negative Blank Purpose | `--None--` | `Bengaluru` | Save Blocked | Error message displayed. |
| **TC-VR2-04** | Negative Both Blank | `--None--` | `""` (Empty) | Save Blocked | Error message displayed. |

---

### Rule 3: `Estimated_Costs_Non_Negative` & `Expense_amount_cannot_be_negative`
* **`Estimated_Costs_Non_Negative`** on `Travel_Request__c`:
  ```salesforce
  OR(
      Travel_Cost__c < 0,
      Hotel_Cost__c < 0,
      Other_Estimated_Cost__c < 0
  )
  ```
* **`Expense_amount_cannot_be_negative`** on `Expense_Item__c`:
  ```salesforce
  Amount__c < 0
  ```
* **Business Rationale:** Prevents negative financial inputs that distort corporate budget rollups or trigger fraudulent credit claims.

---

## 3.4 Handling Rejected Expenses Without a Reason

### The Compliance Problem
When a manager or finance officer rejects an expense claim, corporate policy mandates that **the reviewer must provide explanatory feedback** (e.g., *"Missing tax invoice"* or *"Exceeds per-diem cap"*). An approver cannot reject a claim without explanation.

### Dual-Layer Enforcement Architecture:
```
                              APPROVER CLICKS REJECT
                                        │
                                        ▼
             ┌─────────────────────────────────────────────────────┐
             │ Layer 1: Apex Controller Exception Check            │
             │ In WanderRosterDashboardController.cls:             │
             │ If (status == 'Rejected' && isBlank(comments))      │
             │     throw new AuraHandledException(...)             │
             └──────────────────────────┬──────────────────────────┘
                                        │
                                        ▼
             ┌─────────────────────────────────────────────────────┐
             │ Layer 2: Declarative Validation Rule (Database Lock)│
             │ On Expense_Report__c:                               │
             │ Formula:                                            │
             │ AND(                                                │
             │     ISPICKVAL(Expense_Status__c, "Rejected"),       │
             │     ISBLANK(Manager_Comments__c)                    │
             │ )                                                   │
             └─────────────────────────────────────────────────────┘
```

#### Declarative Rule Specification:
* **Object:** `Expense_Report__c`
* **Rule Name:** `Rejection_Reason_Mandatory_On_Report`
* **Formula:**
  ```salesforce
  AND(
      ISPICKVAL(Expense_Status__c, "Rejected"),
      ISBLANK(Manager_Comments__c)
  )
  ```
* **Error Message:** *"Please provide a rejection reason in Manager Comments before rejecting this expense report."*
* **Error Display Field:** `Manager_Comments__c`

#### Live Demonstration Workflow:
1. Approver opens pending report `ER-0014` (Amount: ₹18,500).
2. Approver sets status to **"Rejected"** but leaves `Manager_Comments__c` blank.
3. Approver clicks **Save**.
4. **Result:** Save is blocked. The `Manager_Comments__c` field border turns red and displays the error message.
5. Approver inputs: *"Hotel cost of ₹7,000 exceeds ₹5,000 policy cap without pre-approval."*
6. Approver clicks **Save** $\rightarrow$ Save succeeds, and notification is sent to the claimant.

---

# SECTION 4: Custom Metadata Types

## 4.1 Technical Definition & Architecture
A **Custom Metadata Type (CMDT)** is a Salesforce architectural structure whose records are treated as **metadata** rather than data.

### Architectural Advantages:
* **Application Lifecycle Management (ALM):** Records can be deployed directly from Sandbox to Production using Salesforce CLI (`sf project deploy`) or Git pipelines without Data Loader.
* **Cached in Application RAM:** CMDT records are cached globally in memory. Accessing them via static methods (`Expense_Policy__mdt.getAll()`) incurs **zero SOQL query limits**.
* **Declarative Administration:** Business rules can be updated in **Setup $\rightarrow$ Custom Metadata Types** without editing code or running unit tests.

---

## 4.2 Custom Metadata vs. Hardcoding Limits

| Evaluation Criterion | Hardcoded in Apex Code | Custom Metadata (`Expense_Policy__mdt`) |
| :--- | :--- | :--- |
| **Updating a Cap** | Developer writes code, creates test methods, runs test classes, and deploys changeset. | Finance Admin updates the record in **Setup** in under 60 seconds. |
| **Auditability** | Changes tracked in Git version control only. | Changes tracked in Salesforce **Setup Audit Trail** with user timestamps. |
| **Deployment Risk** | Can fail production deployments if unrelated unit tests fail. | Metadata deployment with zero Apex compilation risks. |
| **Reusability** | Buried inside specific Apex classes. | Accessible across Formulas, Validation Rules, Flows, and Apex. |

---

## 4.3 WanderRoster Implementation: `Expense_Policy__mdt`

### Schema Definition:
* **Developer Name:** `Expense_Policy__mdt`
* **Master Label:** `Expense Policy`
* **Custom Fields:**
  * `Expense_Category__c` — Picklist (`Hotel`, `Meals`, `Transport`, `Miscellaneous`)
  * `Maximum_Amount__c` — Currency (18, 2)
  * `Active__c` — Checkbox (Default: `true`)

### Live Production Configuration in Org:
| Developer Name | Master Label | Expense Category | Maximum Amount | Active |
| :--- | :--- | :--- | :--- | :--- |
| **`Hotel_Policy`** | Hotel Policy | `Hotel` | **₹5,000.00** | `true` |
| **`Meals_Policy`** | Meals Policy | `Meals` | **₹1,500.00** | `true` |
| **`Transport_Policy`** | Transport Policy | `Transport` | **₹2,000.00** | `true` |
| **`Miscellaneous_Policy`**| Miscellaneous Policy | `Miscellaneous` | **₹1,000.00** | `true` |

### Programmatic Integration in Apex (`ExpensePolicyChecker.cls`):
```apex
public class ExpensePolicyChecker {

    // Evaluates whether an expense item exceeds its metadata policy cap
    public static Boolean exceedsLimit(String category, Decimal amount) {
        if (String.isBlank(category) || amount == null) {
            return false;
        }

        List<Expense_Policy__mdt> policies = [
            SELECT Maximum_Amount__c
            FROM Expense_Policy__mdt
            WHERE Expense_Category__c = :category
            AND Active__c = true
            LIMIT 1
        ];

        if (policies.isEmpty() || policies[0].Maximum_Amount__c == null) {
            return false;
        }

        return amount > policies[0].Maximum_Amount__c;
    }
}
```

---

# SECTION 5: Slide-by-Slide PPT Blueprint (10 Slides)

Use the following slide blueprint directly to assemble your PowerPoint presentation:

```
========================================================================================
SLIDE 1: TITLE SLIDE
========================================================================================
Title: Salesforce Configuration Architecture
Subtitle: Page Layouts, Validation Rules, Custom Metadata Types & Record Types
Presenter: Member 2 — Salesforce Configuration Specialist
Project: WanderRoster (Corporate Travel & Expense Management)

Speaker Script:
"Good morning, panel. I am Member 2, representing the WanderRoster project. Today, I will present the four declarative pillars of our application: Page Layouts, Record Types, Validation Rules, and Custom Metadata Types. I will show how we structured our user interfaces, prevented bad data at inception, and decoupled policy rules from programmatic code."

========================================================================================
SLIDE 2: PAGE LAYOUTS VS LIGHTNING RECORD PAGES
========================================================================================
Title: UI Architecture: Page Layouts vs Lightning Record Pages
Comparison:
• Page Layout: Governs fields inside record details, layout requiredness, and related lists.
• Lightning Record Page (FlexiPage): Full canvas hosting custom LWCs and dynamic widgets.
• WanderRoster Use: Page Layouts organize fields; FlexiPages host our single-page workspace.

Speaker Script:
"In Salesforce Lightning, Page Layouts and Lightning Record Pages work together. While our Lightning FlexiPages host our unified workspace and LWC dashboards, our Page Layouts govern the underlying fields—grouping data into logical sections, establishing read-only summary calculations, and defining child related lists."

========================================================================================
SLIDE 3: WANDERROSTER PAGE LAYOUT ARCHITECTURE
========================================================================================
Title: Field Ergonomics: Travel Request & Expense Layouts
Key Sections:
• Travel Request Layout:
  1. Travel Details: Origin, destination, dates, employee identity, commercial purpose.
  2. Estimated Costs: Transport, lodging, and auto-computed formula Estimated Total.
  3. Approval & AI Review: Travel status badges, AI risk score, and prescriptive guidance.
• Expense Item Layout: Enforces requiredness on Amount and parent Expense Report lookup.

Speaker Script:
"Here is our field layout architecture. Notice how fields are grouped into three distinct sections: Travel Details, Estimated Costs, and Approval/AI Review. A user entering trip details sees only what is relevant, while summary calculations like Estimated Total are kept strictly read-only."

========================================================================================
SLIDE 4: RECORD TYPES STRATEGY
========================================================================================
Title: Record Types: Master Architecture & Enterprise Expansion
Key Points:
• Current Production State: Unified Master Record Type with dynamic LWC role switching.
• Enterprise Expansion Model:
  - Domestic Travel: Standard INR currency, domestic transport picklists, local per-diems.
  - International Travel: Forex multi-currency, mandatory Passport/Visa fields, international caps.

Speaker Script:
"Currently, WanderRoster uses a master record type because our dynamic LWC workspace switches views based on user permissions. However, for enterprise scale, we designed a Domestic vs International Record Type model to dynamically filter picklists and require passport fields only for overseas travel."

========================================================================================
SLIDE 5: VALIDATION RULES: DATABASE-LEVEL GUARDRAILS
========================================================================================
Title: Validation Rules: Stopping Bad Data at Inception
Key Points:
• Executes before Apex triggers in the standard Salesforce Order of Execution.
• Formula evaluates to TRUE -> Halts transaction, rolls back database, displays error banner.
• Formula Functions: ISBLANK() (universal data type support), AND() / OR() logic nesting.

Speaker Script:
"Validation rules are our first line of defense. By stopping bad data before Apex triggers fire, we conserve governor limits and prevent data corruption. Unlike ISNULL, we use ISBLANK because it functions reliably across all field types, including empty text strings."

========================================================================================
SLIDE 6: ACTIVE VALIDATION RULES & TEST CASES
========================================================================================
Title: Active Validation Rules: Formulas & Verification
Key Rules:
• Rule 1: End_Date_After_Start_Date
  AND(NOT(ISBLANK(Start_Date__c)), NOT(ISBLANK(End_Date__c)), End_Date__c < Start_Date__c)
  -> Prevents negative trip durations; verified across positive, boundary, and negative tests.
• Rule 2: Travel_Purpose_And_Destination_Required
  OR(ISBLANK(TEXT(Travel_Purpose__c)), ISBLANK(Destination__c))
  -> Guarantees no incomplete travel requisition can be saved.

Speaker Script:
"Here are two active validation rules from our org. Rule 1 ensures that trip end dates cannot precede start dates, avoiding negative durations and division-by-zero errors in daily per-diem calculations. Rule 2 ensures that both destination and commercial purpose are provided before saving."

========================================================================================
SLIDE 7: REJECTION WITHOUT REASON HANDLING
========================================================================================
Title: Governance: Mandatory Rejection Comments
Key Points:
• Compliance Requirement: No reviewer can reject a claim without explanatory feedback.
• Declarative Rule on Expense_Report__c:
  AND(ISPICKVAL(Expense_Status__c, "Rejected"), ISBLANK(Manager_Comments__c))
• Dual Protection: Client-side LWC validation + Server-side Apex exception + Declarative DB rule.

Speaker Script:
"One of our practical tasks was demonstrating how rejected expenses without a reason are handled. We implemented a dual-layer lock: declaratively, a validation rule checks if status is 'Rejected' while comments are blank, blocking the save. Programmatically, our Apex controller throws an exception if rejection feedback is missing."

========================================================================================
SLIDE 8: CUSTOM METADATA TYPES: DECOUPLING POLICY
========================================================================================
Title: Custom Metadata: The Antidote to Hardcoding
Comparison:
• Hardcoded Apex: Requires developer edits, test class runs, and full release deployments.
• Custom Metadata: Stored as metadata, cached in RAM, zero governor impact, admin editable.
• Live Org Implementation: Expense_Policy__mdt stores category spending caps.

Speaker Script:
"Why use Custom Metadata instead of hardcoding an IF statement? If corporate meal allowances increase from ₹1,500 to ₹1,800, hardcoding requires developer tickets, code changes, and test deployments. With Custom Metadata, a business administrator changes the limit in Setup in 30 seconds."

========================================================================================
SLIDE 9: EXPENSE_POLICY__MDT IN ACTION
========================================================================================
Title: Dynamic Policy Engine: Schema & Live Configuration
Key Data:
• Configured Records: Hotel (₹5,000), Transport (₹2,000), Meals (₹1,500), Misc (₹1,000).
• Apex Integration: ExpensePolicyChecker queries Expense_Policy__mdt dynamically.
• Automated Auditing: Flags Policy_Violation__c and calculates policy delta automatically.

Speaker Script:
"This slide shows our live Expense_Policy__mdt records. In Apex, our ExpensePolicyChecker queries this metadata. If an expense line exceeds its category cap, the system automatically flags Policy_Violation__c as true and notes the excess amount for audit review."

========================================================================================
SLIDE 10: COGNIZANT RAPID-FIRE SUMMARY & Q&A
========================================================================================
Title: Summary & Key Takeaways
Key Answers:
• ISBLANK vs ISNULL: ISBLANK supports text; ISNULL does not.
• Multiple Rules Failing: Salesforce displays all failing error messages simultaneously.
• Validation vs Apex: Apex is mandatory for cross-object rollups and SELECT FOR UPDATE locking.
• Testing Approach: Positive, negative, boundary UI tests + Apex DmlException assertions.

Speaker Script:
"In summary: Page Layouts structure user input, Validation Rules ensure data integrity, Record Types provide enterprise scalability, and Custom Metadata decouples business policy from code. Thank you, and I look forward to your questions."
========================================================================================
```

---

## Technical File Locations
* **Word Document (`.docx`):** [`D:\Salesforce\Use Case 3\WanderRoster_Configuration_Specification.docx`](file:///D:/Salesforce/Use%20Case%203/WanderRoster_Configuration_Specification.docx)
* **Markdown Document (`.md`):** [`D:\Salesforce\Use Case 3\WanderRoster_Configuration_Specification.md`](file:///D:/Salesforce/Use%20Case%203/WanderRoster_Configuration_Specification.md)
* **Artifact Directory Path:** [`C:\Users\ketan\.gemini\antigravity\brain\55fa75b5-3885-4226-8f44-7a5304fa47bf\WanderRoster_Configuration_Specification.docx`](file:///C:/Users/ketan/.gemini/antigravity/brain/55fa75b5-3885-4226-8f44-7a5304fa47bf/WanderRoster_Configuration_Specification.docx)
