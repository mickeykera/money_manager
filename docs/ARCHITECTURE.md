# LedgerLeaf System Architecture

**Project:** LedgerLeaf — Privacy-First Automatic iOS Expense Tracker  
**Currency:** Ethiopian Birr (ETB)  
**Platform:** Flutter (iOS Primary Target, Linux Supported for Local Dev & Testing)  
**Storage:** Offline-First SQLite with Shared App Group Container & Ingestion Buffer  

---

## 1. Architectural Philosophy

LedgerLeaf is designed around five foundational tenets:

1. **Absolute Privacy by Design:** All transaction data, parsing rules, and original SMS messages remain exclusively on the user's physical device. No telemetry, no third-party analytics, no remote servers, no cloud sync in the MVP.
2. **Deterministic Financial Arithmetic:** Monetary calculations strictly avoid floating-point math. All amounts are modeled and computed in integer minor units (Santims for ETB: 1 ETB = 100 Santims).
3. **Decoupled Engine Layers:** The SMS parsing engine, transaction domain logic, persistence layer, and native iOS integration are completely decoupled from UI widgets. Each layer is independently unit-testable.
4. **Resilient Native Integration:** The native iOS App Intent communicates with the Flutter application via an App Group container using SQLite WAL mode and an append-only Ingestion Buffer queue to ensure zero data loss and concurrency safety.
5. **Auditable & Human-Controlled:** Ingestion confidence scoring ensures that ambiguous or malformed messages are placed in a Review Queue rather than silently corrupting account balances.

---

## 2. Layered Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                              │
│  - Dashboard Screen (Cashflow, Monthly Budgets, Spending Breakdown)     │
│  - Transactions Screen (Search, Multi-Filter, Detail, Edit, Review)    │
│  - Add/Edit Transaction Form (Precise Decimal Input, Validation)       │
│  - Budgets & Analytics Screen (Category Budgets, Trend Analysis)       │
│  - Automation Setup Wizard (Interactive Visual Shortcuts Guide)        │
│  - Settings & Data Portability Screen (Backup, Restore, CSV, Privacy)  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        DOMAIN / APPLICATION LAYER                      │
│  - Transaction Domain Engine (CRUD, Balance Calculations)              │
│  - Ingestion Orchestration Service (Deduplication, Routing, Auditing)  │
│  - Budget & Summary Calculator (Calendar boundaries, Minor Units)      │
│  - Category & Account Management                                       │
│  - Data Portability Engine (CSV Importer/Exporter, JSON Backup)        │
└──────────────────────┬────────────────────────────┬────────────────────┘
                       │                            │
                       ▼                            ▼
┌───────────────────────────────┐  ┌─────────────────────────────────────┐
│      PERSISTENCE LAYER        │  │       SMS PARSER ENGINE             │
│ - SQLite Database Repository  │  │ - Bank/Provider Parsers (CBE, BOA,  │
│   (WAL Mode, Migrations)      │  │   Telebirr, Dashen, Generic)        │
│ - Ingestion Buffer Queue      │  │ - Tokenizer & Regex Extractors      │
│ - App Group Path Resolver     │  │ - Confidence Scorer & OTP Filter    │
└──────────────┬────────────────┘  └─────────────────────────────────────┘
               │
               ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        NATIVE iOS LAYER (Swift)                        │
│ - IngestSmsIntent (AppIntent, `openAppWhenRun = false`)                │
│ - App Group Storage Directory Accessor                                 │
│ - Ingestion Event Log Buffer Writer                                    │
│ - Personal Automation Shortcuts Integration                            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Core Subsystems

### 3.1 Domain Model & Monetary Handling
- **Minor Units Representation:** All money amounts are stored as 64-bit integers (`int` in Dart, `INTEGER` in SQLite) representing Santims (1/100th of an ETB).
  - Example: `150.75 ETB` is represented internally as `15075`.
- **Transaction Types:**
  - `expense`: Decreases account balance, counts toward category budgets.
  - `income`: Increases account balance.
  - `transfer`: Moves funds between accounts. Linked transactions avoid double counting.
  - `refund`: Credits an account and offsets prior expense.
  - `reversal`: Voids a prior debit/credit.
- **Transaction Entity Attributes:**
  - `id`: UUID v4 string.
  - `amountSantims`: Integer.
  - `currency`: Default `"ETB"`.
  - `type`: Enum (`expense`, `income`, `transfer`, `refund`, `reversal`).
  - `merchant`: Cleaned merchant or counterparty name.
  - `timestamp`: UTC ISO-8601 millisecond timestamp.
  - `categoryId`: Foreign key to `categories`.
  - `accountId`: Foreign key to `accounts`.
  - `source`: Enum (`sms`, `manual`, `csv`).
  - `importStatus`: Enum (`posted`, `pendingReview`, `rejected`).
  - `sourceFingerprint`: SHA-256 hash of sender + timestamp + amount + reference.
  - `originalMessage`: Raw text (optional, governed by user privacy settings).
  - `reference`: Bank transaction reference ID (e.g. `FT24...`, `TRANS...`).
  - `linkedTransactionId`: Optional UUID for transfer or refund linking.
  - `notes`: User notes.

### 3.2 Local Persistence (SQLite)
- **Schema Management:** Automated versioned migrations (`v1`, `v2`, etc.).
- **Tables:**
  - `transactions`: Primary ledger.
  - `accounts`: Financial accounts (e.g., CBE Account, Telebirr Wallet, Cash).
  - `categories`: Category hierarchy, icons, and monthly budget limits.
  - `ingestion_logs`: Audit trail of all SMS ingestion attempts with results.
  - `settings`: Key-value configuration (privacy, retention, default account).
- **Concurrency & File Protection:**
  - SQLite Write-Ahead Logging (`PRAGMA journal_mode = WAL;`) enables non-blocking concurrent reads and writes between the native intent and Flutter.
  - `PRAGMA busy_timeout = 5000;` prevents `SQLITE_BUSY` crashes.
  - Storage is placed in the App Group container (`group.com.ledgerleaf.app`).

### 3.3 SMS Parsing Engine
- **Deterministic Pipeline:** The parser engine runs without any external AI/cloud dependencies using robust regular expressions and tokenizers.
- **Bank-Specific Modules:**
  1. `CbeParser`: Commercial Bank of Ethiopia debit/credit notifications.
  2. `TelebirrParser`: Telebirr P2P transfers, merchant payments, airtime, cash-in/out.
  3. `AbyssiniaParser`: Bank of Abyssinia transactional alerts.
  4. `DashenParser`: Dashen Bank / Amole alerts.
  5. `GenericBankParser`: Configurable heuristic fallback for standard bank alerts.
- **Security Guardrail:** All incoming messages are scanned for 2FA / OTP patterns. Messages containing OTP codes are immediately dropped to protect user credentials.

### 3.4 Ingestion Service & Deduplication Strategy
A simple hash of the message text is insufficient for deduplication because identical recurring payments or identical SMS templates may legitimately occur. The deduplication algorithm computes a Composite Transaction Key:
```
CompositeKey = Hash(sender + normalizedAmount + bankReferenceNumber + roundToMinute(timestamp))
```
If a message lacks a unique bank reference, a 10-minute sliding window check prevents duplicate insertion of duplicate SMS delivery retries while allowing legitimate distinct transactions.

---

## 4. Native iOS Integration Architecture

1. **Shortcuts Action:** LedgerLeaf provides `IngestSmsIntent` via Apple's `AppIntents` framework.
2. **Headless Execution:** `openAppWhenRun = false` allows iOS to run the intent in background when an SMS arrives.
3. **Dual Persistence Mechanism:**
   - **Direct SQLite:** The native intent connects to `ledgerleaf.db` in the App Group and inserts the transaction directly.
   - **Ingestion Event Queue:** If SQLite is locked or inaccessible, the intent writes the raw payload into an append-only JSON queue (`ingestion_queue.json`) in the App Group directory. When Flutter opens or resumes, it drains and processes any queued records.

---

## 5. UI Architecture & Reference Redesign (ui.jpg)

### 5.1 Visual Language & Aesthetic
- **Palette:**
  - Hero & Brand: Dark Forest Green (`#1B3B2B`, `#1A382A`)
  - Light Accents & Badges: Sage Green Pill (`#E8F3EC`), Sage Text (`#235839`)
  - Expenses & Warnings: Terracotta Clay (`#BA4A38`, `#FDECE9`)
  - Backgrounds & Cards: Warm Off-White (`#F8F7F2`), Pure Card White (`#FFFFFF`)
  - Borders & Dividers: Subtle Mineral Border (`#E8E6DE`)
  - Typography: Deep Charcoal (`#191A18`), Muted Secondary (`#75736B`)
- **Navigation Shell:** 5 dedicated destinations:
  1. **Home (`DashboardScreen`):** Dark forest green hero card (`ETB 12,780.50`, in/out flow), horizontally scrolling linked account cards, telecom summary card, and recent activity list with timestamp footnotes.
  2. **Transactions (`TransactionsScreen`):** Search bar, filter modal, quick filter chips (`All`, `Money in`, `Money out`), monthly summary card (`Money in`, `Money out`), and date-grouped headers (`TODAY · OCT 24`, `YESTERDAY · OCT 23`, `EARLIER THIS MONTH`).
  3. **Accounts (`AccountsScreen`):** Total across all accounts, expandable account cards featuring `[💬 SMS linked]` or `[✎ Manual]` badges, available balances, currency details, balance sources, and direct links to account transactions.
  4. **SMS Import (`SmsImportScreen`):** Privacy card ("Only what you choose to share"), Apple Shortcuts status card (`• Connected`), 4-step setup guide with "Open Shortcuts ↗" link, "Test with sample SMS" interactive simulator, and pending review queue.
  5. **Bundles (`BundlesScreen`):** Ethio telecom & Safaricom Ethiopia package tracking, remaining allowances, validity countdowns, and historical usage consumption logs.

---

## 6. Ethiopian Telecom & Mobile Money Architecture

### 6.1 Supported Financial & Telecom Providers
1. **Commercial Bank of Ethiopia (CBE):** Debit/credit notifications from sender `127` or `CBE`.
2. **Bank of Abyssinia (BOA):** P2P and merchant debit/credits.
3. **Dashen Bank / Amole:** Debit, credit, and P2P transfers.
4. **Telebirr:** Mobile money transfers, merchant checkout, cash-in/out, and airtime.
5. **Safaricom M-PESA:** Transfers, merchant till payments, airtime, and balance updates (`MpesaParser`).
6. **Ethio telecom (`EthioTelecomParser`):** 994/127 bundle purchases, `*804#` balance inquiries, and Amharic packages.
7. **Safaricom Ethiopia (`SafaricomTelecomParser`):** Bundle purchases, `*704#` balance inquiries, and All-in-One packages.

### 6.2 Telecom Data Model & Usage Calculation
- **`telecom_bundles` Table:** Tracks active packages (ID, provider, bundle name, category, original allowance, remaining allowance, unit, validity/expiry, purchase price).
- **`telecom_observations` Table:** Time-series records of remaining balance reports.
- **Consumption Engine:**
  - Usage between report $t_1$ and $t_2$ is calculated as $\Delta = \text{Remaining}(t_1) - \text{Remaining}(t_2)$ when $\text{Remaining}(t_2) < \text{Remaining}(t_1)$.
  - When $\text{Remaining}(t_2) > \text{Remaining}(t_1)$ (package renewed or bonus added), usage is recorded as `0.0` rather than negative consumption.
- **Anti-Double-Counting Guard:**
  - Bundle purchase messages with an explicit price (e.g. `ETB 300.00`) create both a financial expense transaction and a bundle record.
  - Bundle balance inquiries (e.g. `*804#`, `*704#`) update remaining allowances and observation history, but NEVER create a financial transaction.
