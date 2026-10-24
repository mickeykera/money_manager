# LedgerLeaf Installation & Sideloading Guide

**Target Platform:** Apple iPhone (iOS 17.0+)  
**App Version:** 1.0.0 (MVP)  
**Host Requirement for Compilation:** macOS with Xcode 15+  

---

## 1. Prerequisites

Because Apple requires proprietary Darwin toolchains, code-signing certificates, and provisioning profiles to package and install native iOS applications, **final binary compilation and signing must occur on macOS with Xcode**. All Dart domain code, deterministic parsers, and Swift App Intents are fully prepared in this repository.

You will need:
1. An iPhone running **iOS 17.0 or newer**.
2. A Mac computer with **Xcode 15.0 or newer** installed.
3. An **Apple ID** (either a free personal developer account or a paid Apple Developer Program account).
4. A USB-C or Lightning cable to connect your iPhone to your Mac.

---

## 2. Step-by-Step Installation via Xcode (Recommended)

### Step 1: Clone the Repository on your Mac
```bash
git clone <repository_url> money_manager
cd money_manager
flutter pub get
```

### Step 2: Open the Xcode Workspace
Open the iOS workspace (NOT the `.xcodeproj` file):
```bash
open ios/Runner.xcworkspace
```

### Step 3: Configure Signing & Bundle ID
1. In the Xcode left navigator, select the root **Runner** project.
2. Under **Targets**, select **Runner**.
3. Select the **Signing & Capabilities** tab.
4. Check **Automatically manage signing**.
5. Under **Team**, select your personal Apple ID or Developer Team.
6. Under **Bundle Identifier**, replace `com.ledgerleaf` with a unique ID registered to your account (e.g., `com.yourname.ledgerleaf`).
7. Under **App Groups**, select or add your custom app group identifier matching your bundle ID (e.g., `group.com.yourname.ledgerleaf`).

### Step 4: Enable Developer Mode on your iPhone
Starting in iOS 16 and iOS 17, Apple requires Developer Mode to be enabled before sideloaded apps can launch:
1. On your iPhone, open **Settings**.
2. Navigate to **Privacy & Security** > scroll to the bottom > tap **Developer Mode**.
3. Toggle Developer Mode **ON**.
4. Restart your iPhone when prompted, then tap **Turn On** and enter your passcode.

### Step 5: Trust the Developer Certificate
1. Connect your iPhone to your Mac via cable.
2. In Xcode, select your physical iPhone in the device target selector (top toolbar).
3. Press the **Run** button (or `Cmd + R`).
4. Once installed, your iPhone may display an "Untrusted Developer" prompt:
   - Open iPhone **Settings** > **General** > **VPN & Device Management**.
   - Under **Developer App**, tap your Apple ID email.
   - Tap **Trust "[Your Apple ID]"** and confirm.
5. Tap the LedgerLeaf icon on your Home Screen to launch the app!

---

## 3. Alternative Sideloading (AltStore / Sideloadly)

If you compile an unsigned `.ipa` on macOS:
```bash
flutter build ipa --no-codesign
```
You can sideload the generated `.ipa` using:
- **AltStore / AltServer:** Keeps the app active over local Wi-Fi with automatic 7-day re-signing.
- **Sideloadly:** Sideloads directly from Windows or macOS via USB.
- **TrollStore:** If running on a compatible iOS version with CoreTrust vulnerability, allows permanent sideloading without 7-day revocation.

---

## 4. Configuring Apple Shortcuts Personal Automation

To enable automatic transaction capture:

1. Launch **LedgerLeaf** once and complete the initial onboarding.
2. Open Apple's native **Shortcuts** app on your iPhone.
3. Tap the **Automation** tab at the bottom, then tap **`+`** (in the top right corner).
4. Scroll down and choose **Message**.
5. Configure the Trigger:
   - **Sender:** Tap and choose your financial institutions (e.g. `CBE`, `Telebirr`, `127`, `BOA`, `Dashen`).
   - **Run:** Select **Run Immediately** (this allows the automation to execute headlessly).
   - **Notify When Run:** Toggle **OFF** (prevents spamming notification banners).
6. Tap **Next**.
7. In the search bar at the bottom, search for **LedgerLeaf**.
8. Select the action: **Log Transaction from SMS**.
9. Tap the **Message Text** parameter field, select **Shortcut Input**, and ensure **Message Content** is selected.
10. Tap **Done**.

Your automatic transaction capture is now live!

---

## 5. Code Signing Expiry & Limitations

> [!IMPORTANT]
> **Free Apple Developer Accounts:**
> Apps signed with a free personal Apple ID expire after **7 days**. When expired, the app will crash upon launch until re-signed via Xcode or AltStore.
> 
> **Paid Apple Developer Accounts ($99/year):**
> Apps signed with a paid Apple Developer account remain valid for **365 days** and support full App Group capabilities without restriction.

---

## 6. Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| "Untrusted Developer" error | iOS security prompt on sideloaded apps | Go to Settings > General > VPN & Device Management > Trust your Apple ID. |
| Automation prompts "Run" banner | "Run Immediately" was not toggled | Edit the automation in Shortcuts > ensure "Run Immediately" is checked. |
| Action "Log Transaction from SMS" missing in Shortcuts | App has not been launched once | Open LedgerLeaf at least once so iOS indexes its App Intents catalog. |
| Duplicate transactions recorded | Multiple automations matching same message | Ensure you have only one automation per sender shortcode. Deduplication engine will reject identical repeats. |
| OTP message not showing in transactions | Intended security behavior | LedgerLeaf explicitly drops all security OTP and 2FA verification passcodes. |
