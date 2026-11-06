#!/usr/bin/env bash
#
# Download the latest LedgerLeaf Android APK from GitHub Actions and optionally
# install it on a connected phone with adb.
#
# Prerequisites:
#   gh        https://cli.github.com/
#   adb       Android platform-tools (Fedora: sudo dnf install android-tools)
#
# Usage:
#   ./scripts/android-apk.sh                  # download the latest APK
#   ./scripts/android-apk.sh --install        # download and adb install
#   ./scripts/android-apk.sh --build          # trigger a build, wait, install
#   ./scripts/android-apk.sh --apk app.apk    # install an APK you already have
#
set -euo pipefail

WORKFLOW_FILE="android-apk.yml"
ARTIFACT_PATTERN="ledgerleaf-android-apk-*"
REF="main"
REPO="${GITHUB_REPOSITORY:-}"
APK=""
RUN_ID=""
SERIAL=""
DO_BUILD=0
DO_INSTALL=0
KEEP=0

usage() {
  cat <<'EOF'
Download the latest LedgerLeaf Android APK from GitHub Actions and optionally
install it on a connected phone with adb.

Prerequisites:
  gh        https://cli.github.com/
  adb       Android platform-tools (Fedora: sudo dnf install android-tools)

Usage:
  ./scripts/android-apk.sh                  # latest successful build
  ./scripts/android-apk.sh --install        # download and install
  ./scripts/android-apk.sh --build          # trigger a new build, wait, install
  ./scripts/android-apk.sh --apk app.apk    # install an APK you already have

Options:
  --build              Trigger the workflow, wait for it, then install.
  --run-id ID          Use a specific GitHub Actions run.
  --apk PATH           Install a local APK (skips the download).
  --install            Install after downloading (default: download only).
  --serial SERIAL      Target a specific adb device.
  --repo OWNER/NAME    Override the GitHub repository.
  --ref BRANCH         Branch for --build (default: main).
  --keep               Keep the temporary download directory.
  -h, --help           Show this help.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk)
      [[ $# -ge 2 ]] || die "--apk needs a path"
      APK="$2"
      shift 2
      ;;
    --build)
      DO_BUILD=1
      DO_INSTALL=1
      shift
      ;;
    --install)
      DO_INSTALL=1
      shift
      ;;
    --run-id)
      [[ $# -ge 2 ]] || die "--run-id needs an id"
      RUN_ID="$2"
      shift 2
      ;;
    --serial)
      [[ $# -ge 2 ]] || die "--serial needs a device serial"
      SERIAL="$2"
      shift 2
      ;;
    --repo)
      [[ $# -ge 2 ]] || die "--repo needs owner/name"
      REPO="$2"
      shift 2
      ;;
    --ref)
      [[ $# -ge 2 ]] || die "--ref needs a branch"
      REF="$2"
      shift 2
      ;;
    --keep)
      KEEP=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1 (try --help)"
      ;;
  esac
done

command -v gh >/dev/null 2>&1 || die "gh is not installed. Install it from https://cli.github.com/"

if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner) ||
    die "could not detect the GitHub repo; pass --repo owner/name"
fi

if [[ -z "$APK" ]]; then
  TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ledgerleaf-apk.XXXXXX")

  if [[ $KEEP -eq 1 ]]; then
    trap 'echo "Kept download directory: $TMP_DIR"' EXIT
  else
    trap 'rm -rf "$TMP_DIR"' EXIT
  fi

  if [[ $DO_BUILD -eq 1 ]]; then
    echo "Triggering $WORKFLOW_FILE on $REPO ($REF)..."
    gh workflow run "$WORKFLOW_FILE" --repo "$REPO" --ref "$REF"

    # The new run can take a few seconds to appear in the API.
    for _ in $(seq 1 20); do
      RUN_ID=$(gh run list --repo "$REPO" --workflow "$WORKFLOW_FILE" \
        --branch "$REF" --event workflow_dispatch --limit 1 \
        --json databaseId -q '.[0].databaseId // empty' 2>/dev/null || true)
      [[ -n "$RUN_ID" ]] && break
      sleep 2
    done
    [[ -n "$RUN_ID" ]] || die "the workflow run did not appear; check the Actions tab"

    echo "Watching run $RUN_ID..."
    gh run watch "$RUN_ID" --repo "$REPO" --exit-status
  elif [[ -z "$RUN_ID" ]]; then
    RUN_ID=$(gh run list --repo "$REPO" --workflow "$WORKFLOW_FILE" \
      --status success --limit 1 --json databaseId -q '.[0].databaseId // empty')
    [[ -n "$RUN_ID" ]] || die "no successful $WORKFLOW_FILE run found; re-run with --build"
    echo "Using latest successful run: $RUN_ID"
  fi

  echo "Downloading the APK artifact..."
  gh run download "$RUN_ID" --repo "$REPO" \
    --pattern "$ARTIFACT_PATTERN" --dir "$TMP_DIR"

  APK=$(find "$TMP_DIR" -type f -name '*.apk' | head -n 1)
  [[ -n "$APK" ]] || die "the artifact did not contain an .apk file"
else
  [[ -f "$APK" ]] || die "APK not found: $APK"
fi

echo "APK: $APK"

if [[ $DO_INSTALL -eq 0 ]]; then
  exit 0
fi

command -v adb >/dev/null 2>&1 || die \
  "adb is not installed. Fedora: sudo dnf install android-tools"

ADB=(adb)
[[ -n "$SERIAL" ]] && ADB+=(-s "$SERIAL")

if ! "${ADB[@]}" get-state 2>/dev/null | grep -q 'device'; then
  echo "No Android phone detected. Connect it with a USB cable, unlock it, and"
  echo "accept the 'Allow USB debugging' prompt on the phone."
  echo "Check with: adb devices"
  exit 1
fi

echo
echo "Installing $(basename "$APK")"
"${ADB[@]}" install -r "$APK"

echo
echo "Installed. Open LedgerLeaf from the app drawer."
echo "If the installer is blocked, enable 'Install unknown apps' for your"
echo "file manager or browser in the phone settings first."
