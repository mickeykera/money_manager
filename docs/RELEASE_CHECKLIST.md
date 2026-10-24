# LedgerLeaf Release & Quality Checklist

**Target Release:** 1.0.0+1 (Production MVP)  
**Date:** October 2026  

---

## 1. Codebase & Quality Gates

- [x] **Static Analysis:** `flutter analyze` completed with 0 errors, 0 warnings, 0 infos.
- [x] **Unit & Regression Tests:** 36 automated tests passing with 100% success rate:
  - Monetary minor-unit integer arithmetic (no floating-point rounding errors).
  - SQLite CRUD operations, balance calculations, transfers, refunds, reversals.
  - Ingestion deduplication (fingerprint, reference, 10-minute sliding window).
  - Deterministic SMS parsers: Commercial Bank of Ethiopia (CBE), Telebirr, Bank of Abyssinia, Dashen Bank, Generic.
  - OTP & Security passcodes immediate rejection filter.
  - Failed & declined transactions filter.
  - RFC-4180 CSV export and import round-trip preservation.
- [x] **Security & Privacy:**
  - Zero external analytics or telemetry SDKs.
  - Zero external cloud/server backend dependencies.
  - Zero network permissions requested.
  - Original SMS text retention toggleable and stored strictly in local SQLite.
  - File protection set to `NSFileProtectionCompleteUntilFirstUserAuthentication`.
- [x] **UI Polish & Themes:**
  - Material 3 theme matching visual direction (Sage Green `#3F6647`, Clay Terracotta `#B4533C`, Warm Neutrals).
  - Light mode, Dark mode, and System adaptive mode.
  - Privacy Mode toggle on Dashboard to mask sensitive balances in public.
  - Dynamic category budgets with progress bars and over-budget warnings.
  - Interactive Setup Simulator in Automation Setup screen with real synthetic fixtures.

---

## 2. iOS Native Layer & Sideloading Readiness

- [x] **App Intents Implementation:**
  - `IngestSmsIntent.swift` conforms to `AppIntent` protocol with `openAppWhenRun = false` (headless background execution).
  - `AppShortcuts.swift` conforms to `AppShortcutsProvider`.
  - Parameters: `@Parameter(title: "Message Text")` and `@Parameter(title: "Sender")`.
- [x] **App Group & Shared Storage:**
  - `Runner.entitlements` defines `group.com.ledgerleaf.app`.
  - `NativeIngestionManager.swift` manages atomic POSIX writing to `ingestion_events.json`.
  - `NativeBridge.dart` drains background events into local SQLite when app opens or resumes.
- [x] **URL Scheme:**
  - `ledgerleaf://` registered in `Info.plist`.
  - Display name set to `LedgerLeaf`.

---

## 3. Physical Device Verification Gates (macOS & iPhone)

- [ ] Compile release build on macOS using Xcode 15+:
  ```bash
  flutter build ipa --no-codesign
  ```
- [ ] Sign with personal/team developer provisioning profile.
- [ ] Deploy to physical iPhone with Developer Mode enabled.
- [ ] Complete 7-step Shortcuts Personal Automation setup in iOS Shortcuts app.
- [ ] Execute Live SMS Pocket Test (Screen locked, confirmation disabled).
- [ ] Confirm transaction is recorded on Dashboard without opening app.

---

## 4. Known Platform Constraints (Disclosed to User)

1. **Personal Automation creation is manual:** iOS does not allow any third-party app to programmatically create or enable Personal Automations.
2. **First unlock requirement:** Device must be unlocked at least once after reboot for iOS Data Protection to permit background file writing.
3. **Free developer account expiration:** Sideloaded apps using free Apple IDs must be re-signed every 7 days.
