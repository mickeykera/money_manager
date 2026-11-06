# LedgerLeaf

A privacy-first, offline expense tracker for Ethiopian bank and mobile-money SMS
messages. The Flutter UI runs entirely on-device; there is no backend, telemetry,
or network permission.

## Android APK

The Android APK is built by GitHub Actions (`.github/workflows/android-apk.yml`).
You can download the latest `ledgerleaf-android-apk-*` artifact from the
Actions tab, or use the helper script:

```bash
# Download the latest APK
./scripts/android-apk.sh

# Download and install it over USB with adb
./scripts/android-apk.sh --install
```

The APK is signed with the debug key unless `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`
repository secrets are configured. Either way it can be sideloaded after
allowing "Install unknown apps" on the phone.

## iOS builds & sideloading

The iOS IPA is built by GitHub Actions (`.github/workflows/ios-sideload.yml`).
You do not need a Mac to install it:

```bash
# Build, download, sign with your Apple ID, and install over USB from Linux
./scripts/ios-sideload.sh --build
```

The workflow produces an unsigned release IPA; `xtool` re-signs it during
installation. See [`docs/SIDELOAD_XTOOL.md`](docs/SIDELOAD_XTOOL.md) for the
one-time xtool setup, Developer Mode, certificate trust, and troubleshooting.
The older [`docs/IOS_IPA_BUILD.md`](docs/IOS_IPA_BUILD.md) covers the CI modes
and optional paid-account signing.

Free Apple ID signatures expire after 7 days. Re-run the script to re-sign.
App Groups require a paid Apple Developer account and are optional; SMS
automation works without them.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d linux      # desktop development target
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and
[`docs/REAL_DEVICE_TEST_PLAN.md`](docs/REAL_DEVICE_TEST_PLAN.md) for the design
and device test matrix.
