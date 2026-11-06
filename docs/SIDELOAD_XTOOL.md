# Sideloading LedgerLeaf from Linux with xtool

This is the recommended path if you do not have a Mac. GitHub Actions builds the
IPA; `xtool` signs it with your Apple ID and installs it over USB from Linux.

> [!IMPORTANT]
> **GitHub Actions cannot install to your iPhone.** A hosted runner has no USB
> connection to your device. Actions produces the `.ipa`; signing and installation
> happen locally with `xtool` (or Sideloadly/AltStore).

---

## 1. Why the previous sideload did not work

There were three separate problems:

1. **The App Intent code was never compiled.**  
   `ios/Runner/AppShortcuts.swift`, `IngestSmsIntent.swift`, and
   `NativeIngestionManager.swift` existed on disk but were not in the Runner
   target's `Sources` build phase. The IPA therefore had no
   `Log Transaction from SMS` action in Shortcuts and no native SMS queue writer.
   They are now part of the target, and the workflow fails if the App Intent is
   missing from the built binary.

2. **An unsigned IPA must be re-signed.**  
   `flutter build ios --no-codesign` produces an IPA that iOS refuses to install.
   Sideloadly/xtool/AltStore must re-sign every nested framework and the app.
   The new `ios-sideload.yml` workflow uploads that unsigned artifact explicitly
   for this purpose.

3. **Developer Mode and certificate trust are required.**  
   On iOS 16+, a development-signed app will not launch until Developer Mode is
   enabled and the Apple ID certificate is trusted. A free Apple ID signature
   also expires after 7 days.

Fix the build, then reinstall with xtool; do not reuse the old IPA.

---

## 2. Build the IPA on GitHub

The workflow is [`.github/workflows/ios-sideload.yml`](../.github/workflows/ios-sideload.yml).

It runs on every push to `main` touching Dart/iOS files, or manually:

```bash
gh workflow run ios-sideload.yml --ref main -f build_type=unsigned
```

It builds a **release** Flutter app (not a debug/Metro-dependent build), packages
`Payload/Runner.app`, and verifies that:

- `Runner.app/Runner` and `App.framework` are present;
- `flutter_assets` are present;
- `IngestSmsIntent` is compiled into the binary;
- the minimum iOS version is 16.0.

Download the artifact from the run page, or let the helper script do it:

```bash
./scripts/ios-sideload.sh --build
```

---

## 3. Install xtool on Fedora

`xtool` is an open-source Xcode replacement, not a GitHub product. It runs on
Linux and can sign and install an existing IPA without Xcode installed.

```bash
# USB transport and device utilities
sudo dnf install usbmuxd libimobiledevice-utils

# xtool AppImage
mkdir -p ~/.local/bin
curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" \
  -o ~/.local/bin/xtool
chmod +x ~/.local/bin/xtool
xtool --help
```

If FUSE is unavailable, extract the AppImage instead:

```bash
cd ~/.local/bin
./xtool-x86_64.AppImage --appimage-extract
ln -sf ~/.local/bin/squashfs-root/AppRun ~/.local/bin/xtool
```

You do **not** need the multi-gigabyte `Xcode.xip` just to sign and install an
existing IPA. `Xcode.xip` is only needed by `xtool setup` for building SwiftPM
projects from source.

---

## 4. Log in to Apple Developer Services

```bash
xtool auth login
```

Choose **Password** if you have a free Apple ID; choose **API Key** only if you
have a paid Apple Developer Program membership and an App Store Connect key.

Password mode uses private Apple APIs and a virtual-device token (Anisette data).
Your credentials are sent only to Apple, but consider using a secondary Apple ID.

The first login asks for your email, password, and the 2FA code.

Check the session:

```bash
xtool auth status
```

To log out or reset 2FA state:

```bash
xtool auth logout
xtool auth logout --reset-2fa
```

---

## 5. Install the IPA

Connect the iPhone with a USB cable, unlock it, and tap **Trust This Computer**.

```bash
xtool devices
# Example: Michael's iPhone [usb]: 00008110-...
```

Then install. `xtool install` re-signs the unsigned IPA as part of the install:

```bash
xtool install ledgerleaf-1.0.0-1-abcdef0-unsigned.ipa
```

Or use the helper script, which downloads the latest successful CI artifact and
installs it:

```bash
./scripts/ios-sideload.sh
```

Pick a specific device if several are connected:

```bash
xtool install --udid 00008110-... path/to/app.ipa
```

After installing:

1. **Settings → Privacy & Security → Developer Mode → ON**, reboot, and confirm.
2. **Settings → General → VPN & Device Management**, tap your Apple ID, and
   choose **Trust**.
3. Open LedgerLeaf once.
4. Open **Shortcuts → Automation → + → Message**, choose your bank senders,
   enable **Run Immediately**, then add the **Log Transaction from SMS** action
   with **Shortcut Input** as the message text.

The App Intent runs headlessly (`openAppWhenRun = false`), so the app does not
need to be open when the SMS arrives.

---

## 6. Free vs paid Apple ID

| | Free Apple ID | Paid Developer Program |
|---|---|---|
| Signing expiry | **7 days** | 1 year |
| App Groups | Not available | Available |
| Re-sign command | Re-run `xtool install` | Re-run after profile/cert changes |
| CI signed build | Not supported | Supported with the `signed` workflow mode |

LedgerLeaf's native queue has a Documents-directory fallback, so it still works
without an App Group. App Groups are only needed to share a container with a
separate extension target; this app's App Intent runs in the app's own process.

### App Group (paid accounts only)

If you have a paid account and want the shared container, set the
`IOS_APP_GROUP` repository secret (for example `group.com.yourname.ledgerleaf`)
and use the workflow's `signed` mode. Do **not** add an App Group entitlement to
a free-account build; signing will fail or the app will crash on launch.

---

## 7. Optional: signed IPA from GitHub Actions

The workflow can also build a CI-signed IPA with a paid developer certificate.
Add these repository secrets:

| Secret | Required | Value |
|---|---|---|
| `IOS_CERTIFICATE_BASE64` | yes | base64 of your exported `.p12` |
| `IOS_CERTIFICATE_PASSWORD` | yes | password for the `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | yes | base64 of the `.mobileprovision` |
| `IOS_TEAM_ID` | yes | 10-character Apple Team ID |
| `IOS_BUNDLE_ID` | no | custom bundle ID |
| `IOS_APP_GROUP` | no | custom App Group (paid only) |

Then:

```bash
gh workflow run ios-sideload.yml --ref main -f build_type=signed -f export_method=development
```

The device UDID must be registered in the provisioning profile. GitHub Actions
still cannot install the result; download it and use `xtool install` (it will
accept an already-signed IPA too) or Apple Configurator.

---

## 8. Troubleshooting a crash or blank screen

The app now renders a visible startup error instead of a white screen. If it
still fails before Flutter starts, collect a native crash log:

```bash
# Stream the device log while launching
idevicesyslog -u <UDID> | grep -i -E 'Runner|LedgerLeaf|crash|exception'

# Copy crash reports off the device
mkdir -p /tmp/crashes
idevicecrashreport -u <UDID> -k /tmp/crashes
ls /tmp/crashes | grep -i runner
```

On the phone, crash reports are also under **Settings → Privacy & Security →
Analytics & Improvements → Analytics Data** (look for `Runner-*.ips`).

Common causes:

| Symptom | Cause | Fix |
|---|---|---|
| "Unable to Install" | IPA is still unsigned | Re-sign with `xtool install`; do not drag the unsigned IPA into Finder |
| "Untrusted Developer" | Certificate not trusted | Settings → General → VPN & Device Management → Trust |
| App icon opens then closes immediately | Developer Mode off | Settings → Privacy & Security → Developer Mode → ON, reboot |
| App worked, now crashes after a week | Free certificate expired | Re-run `./scripts/ios-sideload.sh` |
| Shortcuts action missing | Old IPA without the native files | Build the new workflow artifact, reinstall, open the app once |
| "databaseFactory not initialized" | Plugin registration missing | Use the release build from this workflow, not a stale IPA |
| Automation runs but no transaction appears | App Group not shared / queue not drained | Open LedgerLeaf; check the in-app ingestion audit log |

For a truly clean reinstall:

```bash
xtool uninstall com.ledgerleaf.ledgerleaf
./scripts/ios-sideload.sh --build
```

---

## 9. References

- xtool: <https://github.com/xtool-org/xtool>
- xtool Linux installation: <https://xtool.sh/documentation/xtooldocs/installation-linux>
- Workflow: [`.github/workflows/ios-sideload.yml`](../.github/workflows/ios-sideload.yml)
- Apple App Intents: <https://developer.apple.com/documentation/appintents>
