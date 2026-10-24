# LedgerLeaf Implementation Plan

**Project:** LedgerLeaf — Privacy-First Automatic iOS Expense Tracker  
**Target Delivery:** High-quality, sideloadable iOS app with complete offline expense tracking.

---

## Stage Breakdown & Milestones

| Stage | Milestone | Primary Deliverables | Verification Gate |
|---|---|---|---|
| **Stage 0** | Feasibility Verification | `docs/IOS_AUTOMATION_FEASIBILITY.md` | Verification of iOS 17+ background App Intent & Personal Automation rules |
| **Stage 1** | Architecture & Project Setup | `docs/ARCHITECTURE.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/SECURITY.md`, Flutter setup | Clean project setup, `flutter test` & `flutter analyze` pass |
| **Stage 2** | Expense Tracker UI | Onboarding, Dashboard, Transactions, Add/Edit Form, Budgets, Setup Wizard, Settings | Working UI connected to state & local data |
| **Stage 3** | Database & Domain Logic | SQLite repository, models, minor units arithmetic, transfers, refunds, deduplication | 100% unit test coverage of financial calculations & database operations |
| **Stage 4** | SMS Parser Engine | Deterministic parser for CBE, Telebirr, Abyssinia, Dashen, Generic; synthetic fixtures | Comprehensive positive, negative, and malformed SMS test suite |
| **Stage 5** | Native iOS Shortcuts Integration | Swift App Intent, App Group configuration, Ingestion buffer, Shortcuts guide | Valid Swift source code, App Intent structure, background safety |
| **Stage 6** | Automatic Ingestion Pipeline | Ingestion orchestration, auto-categorization, review queue, audit log | End-to-end ingestion pipeline tests, idempotent retry tests |
| **Stage 7** | Privacy, Security & Data Portability | Local backup/restore, CSV export/import, zero network calls, security audit | Security validation, privacy settings verification |
| **Stage 8** | Automated Tests & Verification Plan | `docs/REAL_DEVICE_TEST_PLAN.md`, full test suite execution | All tests passing, analyze clean |
| **Stage 9** | Sideloading & Delivery Guide | `docs/INSTALLATION.md`, `docs/RELEASE_CHECKLIST.md`, Xcode config | Complete build & signing guides for sideloading |
| **Stage 10**| Final Audit & Handoff | Final audit, dead code removal, clean diff, handoff report | Complete production-ready codebase |

---

## Technical Specifications

### Tech Stack
- **Framework:** Flutter 3.47+ / Dart 3.13+
- **Native Platform:** Swift (iOS 17+ target, compatible with iOS 16 fallback)
- **Local Database:** `sqflite` (with `sqflite_common_ffi` for Linux/desktop unit tests)
- **State Management:** Reactive ChangeNotifier / ValueNotifier / Repository pattern
- **Typography & Design:** Material 3 with customized Warm Neutral, Sage Green (`#4A6B53`), Clay (`#A05A42`), Charcoal surfaces.

### Verification Principles
- Execute stages sequentially.
- Verify each gate before committing.
- Commit git history at the completion of each stage with descriptive messages.
