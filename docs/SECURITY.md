# LedgerLeaf Security & Privacy Policy

**Project:** LedgerLeaf  
**Classification:** Financial Data & Personal Privacy Architecture  

---

## 1. Core Security Guarantees

1. **Zero Cloud Synchronization:** LedgerLeaf does not include an external backend, authentication server, or remote database. All financial records and settings are stored locally on the device in an encrypted iOS sandbox.
2. **Zero Third-Party Telemetry:** No analytics SDKs (e.g. Firebase, Mixpanel, Sentry, Facebook SDK) are included in the codebase.
3. **Zero Network Permissions Required:** LedgerLeaf operates 100% offline. It does not require or request internet communication permissions to parse or record transactions.
4. **No Sensitive Message Retention by Default:** 
   - Original SMS bodies are considered high-sensitivity data.
   - Users can toggle whether to store the original SMS text in `Settings > Privacy`.
   - If enabled, the text is kept strictly in local SQLite and never shared outside the app.
   - A retention setting allows automatic purging of original text after 30 days while retaining the structured transaction metadata.

---

## 2. Protection of Financial Credentials & OTPs

SMS messages from financial institutions frequently carry sensitive one-time passcodes (OTPs), verification PINs, and account balance notifications.

LedgerLeaf implements strict heuristic filters at the very entry of the parsing engine:
- If a message contains strings matching security patterns such as:
  - `OTP`
  - `verification code`
  - `secret code`
  - `do not share`
  - `password`
  - `ይህንን ሚስጥራዊ ቁጥር` (Amharic: "this secret number")
- The message is **immediately rejected and discarded**.
- It is never written to the transaction database or audit log.

---

## 3. iOS File Protection & Sandbox Security

1. **Data Protection Class:**
   - Database files in the App Group are secured using `NSFileProtectionCompleteUntilFirstUserAuthentication`.
   - This ensures that once the user unlocks their phone after boot, background App Intents can securely execute while the device is locked in a pocket or bag.
   - Files are encrypted at rest by the iOS hardware AES engine.
2. **App Group Isolation:**
   - The shared App Group container (`group.com.ledgerleaf.app`) is strictly limited to LedgerLeaf's main application and its companion App Intent.
   - No other third-party applications on the device can access the container.
3. **No Excessive Permissions:**
   - The app does not request access to contacts, microphone, camera, or location.

---

## 4. Data Portability & Destruction

1. **User Ownership:** Users can export their entire financial ledger to standard CSV or JSON format at any time.
2. **Secure Erase:** The Settings screen provides a **"Wipe All Data"** option that:
   - Drops and recreates the SQLite database.
   - Deletes all queued ingestion events and logs.
   - Resets all user preferences to default.
   - Overwrites and removes any temporary files.

---

## 5. Security Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Malicious SMS spoofing sender ID | Low | Parser extracts structured financial references; ambiguous or unrecognized transactions require manual review. |
| Inadvertent exposure of bank balance | Medium | Bank balances are parsed only for user reference and can be hidden via a "Privacy Mode" toggle in the UI. |
| Unauthorized physical access to unlocked device | Medium | App supports biometric lock (Face ID/Touch ID) before displaying ledger UI. |
| Accidental inclusion of OTP in transaction memo | High | OTP filter explicitly detects and drops authentication messages. |
