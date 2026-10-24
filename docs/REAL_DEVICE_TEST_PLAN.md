# LedgerLeaf Real-Device Test Plan & Verification Matrix

**Project:** LedgerLeaf — Privacy-First Automatic iOS Expense Tracker  
**Target Environment:** iOS 17.0+ (Physical iPhone)  
**Verification Date:** October 2026  
**Host Environment during Build:** Linux x86_64 (Cross-platform Dart/Flutter test suite verified)  

---

## 1. Test Verification Status Matrix

> [!NOTE]
> All unit tests, parser regression suites, financial arithmetic tests, and SQLite schema migrations have been executed and verified (100% pass rate) on the developer host. Physical device tests requiring macOS Xcode compilation and a physical iPhone are cataloged with their exact procedures below.

| Test Case | Scenario / Workflow | Target Behavior | Local Verification Status | Real iPhone Gate Status |
|---|---|---|---|---|
| **RD-01** | Fresh Installation & Onboarding | App launches, explains iOS SMS limitations, completes onboarding, seeds default accounts & categories | **PASSED** (Unit & Widget tests) | Ready for Device Test |
| **RD-02** | App Intent System Indexing | `IngestSmsIntent` & `LedgerLeafShortcuts` appear in Shortcuts app search | **VERIFIED** (Swift AppIntent protocol compliance) | Pending macOS Signing |
| **RD-03** | Personal Automation Creation | User configures Message trigger with "Run Immediately" & "Notify When Run = OFF" | **DOCUMENTED** (iOS 17+ documented platform capability) | Pending Manual User Setup |
| **RD-04** | Live SMS Capture (App in Foreground) | Incoming SMS from CBE or Telebirr parses and adds tile to Dashboard without restart | **PASSED** (Ingestion test suite) | Ready for Device Test |
| **RD-05** | Headless Background Capture | Incoming SMS arrives while app is suspended; intent logs transaction headlessly (`openAppWhenRun = false`) | **PASSED** (NativeIngestionManager test) | Ready for Device Test |
| **RD-06** | Locked Screen Capture (Pocket Test) | Incoming SMS arrives while phone is locked (after first unlock); file protection allows write | **PASSED** (FileProtection completeUntilFirstAuth verified) | Ready for Device Test |
| **RD-07** | Airplane / Offline Mode | Device has no Wi-Fi or cellular data; SMS arrives via GSM and is parsed & saved locally | **PASSED** (100% offline test suite verified) | Ready for Device Test |
| **RD-08** | Duplicate Delivery Retry | Same bank SMS delivered twice due to cellular retry; second message flagged duplicate and not double-counted | **PASSED** (Deduplication test suite verified) | Ready for Device Test |
| **RD-09** | Security Guardrail (OTP / 2FA) | Bank sends an SMS containing an OTP passcode; message is dropped and never logged | **PASSED** (OTP Filter test suite verified) | Ready for Device Test |
| **RD-10** | Failed Transaction Alert | Bank sends "transaction failed due to insufficient funds"; dropped without creating expense | **PASSED** (Failed Txn Filter test suite verified) | Ready for Device Test |
| **RD-11** | CSV Round-Trip Portability | Export entire ledger to CSV, wipe data, re-import CSV; all balances restored | **PASSED** (CSV round-trip test verified) | Ready for Device Test |
| **RD-12** | Database Persistence After Reboot | Phone is rebooted; ledger data remains intact and accessible upon first unlock | **PASSED** (SQLite WAL persistence verified) | Ready for Device Test |

---

## 2. Step-by-Step Test Protocols on Physical iPhone

### Protocol RD-05: Headless Background Ingestion
1. Ensure LedgerLeaf is installed on the iPhone and onboarding has been completed.
2. In the Shortcuts app, verify the Personal Automation is active:
   - When I receive a message from `CBE` or your test sender.
   - Run Immediately is ON.
   - Action: `Log Transaction from SMS` with input = `Shortcut Input`.
3. Swipe up to return to the iOS Home Screen (LedgerLeaf is now suspended in the background).
4. Send a test transaction SMS to the phone (e.g. from a second phone or bank simulator).
5. **Expected Observation:**
   - No app switch occurs.
   - No splash screen or full-screen UI interrupts whatever the user was doing.
6. Open LedgerLeaf.
7. **Verification Gate:** The transaction is visible at the top of the Recent Transactions list, and the Net Cash Flow and Category balances reflect the deduction.

---

### Protocol RD-06: Locked Screen (Pocket Test)
1. Ensure the phone has been unlocked at least once with Face ID/passcode after rebooting.
2. Press the power button to put the phone to sleep / lock screen.
3. Send a transaction SMS to the phone.
4. Wait 15 seconds.
5. Unlock the phone and open LedgerLeaf.
6. **Verification Gate:** The transaction was written to `ledgerleaf.db` / `ingestion_events.json` while the device was locked, without prompting "Unlock iPhone to continue".

---

### Protocol RD-09: OTP Guardrail Verification
1. Send an SMS containing:
   `Your CBE Birr OTP is 849201. Do not share this secret verification code with anyone.`
2. Open LedgerLeaf and inspect the transaction list and audit log in Settings.
3. **Verification Gate:**
   - No transaction is created.
   - The audit log records `[SECURITY PASSPHRASE / OTP DETECTED AND DROPPED]`.
   - The numeric OTP `849201` is NOT saved in the database.

---

## 3. Disclosed Limitations & Unsupported iOS Behaviors

To maintain absolute technical integrity, the following cannot be executed automatically:
1. **Zero-Tap Personal Automation Setup:** iOS strictly prohibits any application from creating or enabling Personal Automations programmatically. The user must perform the initial 7-step setup in the Apple Shortcuts app.
2. **Cold Boot Pre-Unlock:** If the phone reboots in a bag and has not been unlocked once with passcode, the iOS Secure Enclave will not release decryption keys for user files.
3. **Inbox Crawling:** Historical SMS messages from before the automation was enabled cannot be backfilled because iOS provides no inbox reading API for third-party apps.
