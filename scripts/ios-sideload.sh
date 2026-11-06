#!/usr/bin/env bash
#
# Download the latest unsigned LedgerLeaf IPA from GitHub Actions and install it
# on a connected iPhone using xtool. Works from Linux (no Windows required).
#
# Prerequisites:
#   gh       https://cli.github.com/
#   xtool    https://github.com/xtool-org/xtool
#   usbmuxd  (Fedora: sudo dnf install usbmuxd libimobiledevice-utils)
#
# Usage:
#   ./scripts/ios-sideload.sh                  # latest successful build
#   ./scripts/ios-sideload.sh --build          # trigger a new build, wait, install
#   ./scripts/ios-sideload.sh --ipa app.ipa    # install an IPA you already have
#   ./scripts/ios-sideload.sh --download-only  # just download the artifact
#
set -euo pipefail

WORKFLOW_FILE="ios-sideload.yml"
ARTIFACT_PATTERN="ledgerleaf-ios-unsigned-*"
REF="main"
REPO="${GITHUB_REPOSITORY:-}"
IPA=""
RUN_ID=""
UDID=""
DO_BUILD=0
DO_INSTALL=1
KEEP=0

usage() {
  cat <<'EOF'
Download the latest unsigned LedgerLeaf IPA from GitHub Actions and install it
on a connected iPhone using xtool. Works from Linux (no Windows required).

Prerequisites:
  gh       https://cli.github.com/
  xtool    https://github.com/xtool-org/xtool
  usbmuxd  (Fedora: sudo dnf install usbmuxd libimobiledevice-utils)

Usage:
  ./scripts/ios-sideload.sh                  # latest successful build
  ./scripts/ios-sideload.sh --build          # trigger a new build, wait, install
  ./scripts/ios-sideload.sh --ipa app.ipa    # install an IPA you already have
  ./scripts/ios-sideload.sh --download-only  # just download the artifact

Options:
  --build              Trigger the workflow, wait for it, then install.
  --run-id ID          Use a specific GitHub Actions run.
  --ipa PATH           Install a local IPA (skips the download).
  --download-only      Download but do not install.
  --udid UDID          Target a specific connected iPhone.
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
    --ipa)
      [[ $# -ge 2 ]] || die "--ipa needs a path"
      IPA="$2"
      shift 2
      ;;
    --build)
      DO_BUILD=1
      shift
      ;;
    --run-id)
      [[ $# -ge 2 ]] || die "--run-id needs an id"
      RUN_ID="$2"
      shift 2
      ;;
    --udid)
      [[ $# -ge 2 ]] || die "--udid needs a device UDID"
      UDID="$2"
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
    --download-only)
      DO_INSTALL=0
      shift
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

if [[ -z "$IPA" ]]; then
  TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ledgerleaf-ipa.XXXXXX")

  if [[ $KEEP -eq 1 ]]; then
    trap 'echo "Kept download directory: $TMP_DIR"' EXIT
  else
    trap 'rm -rf "$TMP_DIR"' EXIT
  fi

  if [[ $DO_BUILD -eq 1 ]]; then
    echo "Triggering $WORKFLOW_FILE on $REPO ($REF)..."
    gh workflow run "$WORKFLOW_FILE" --repo "$REPO" --ref "$REF" -f build_type=unsigned

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

  echo "Downloading the unsigned IPA artifact..."
  gh run download "$RUN_ID" --repo "$REPO" \
    --pattern "$ARTIFACT_PATTERN" --dir "$TMP_DIR"

  IPA=$(find "$TMP_DIR" -type f -name '*.ipa' | head -n 1)
  [[ -n "$IPA" ]] || die "the artifact did not contain an .ipa file"
  echo "IPA: $IPA"
else
  [[ -f "$IPA" ]] || die "IPA not found: $IPA"
fi

if [[ $DO_INSTALL -eq 0 ]]; then
  echo "Downloaded: $IPA"
  exit 0
fi

command -v xtool >/dev/null 2>&1 || die \
  "xtool is not installed. See docs/SIDELOAD_XTOOL.md, or install the AppImage from https://github.com/xtool-org/xtool/releases/latest"

if ! xtool auth status 2>/dev/null | grep -q "Logged in"; then
  echo
  echo "xtool is not logged in to Apple Developer Services yet."
  echo "Run this once (a free Apple ID works; 2FA is required):"
  echo
  echo "    xtool auth login"
  echo
  echo "Then re-run this script. See docs/SIDELOAD_XTOOL.md for details."
  exit 1
fi

if ! xtool devices --no-wait 2>/dev/null | grep -q ':'; then
  echo "No iPhone detected. Connect it with a USB cable, unlock it, and trust this computer."
  echo "Then check that usbmuxd is running:"
  echo "    sudo systemctl status usbmuxd"
  exit 1
fi

echo
echo "Installing $IPA"
if [[ -n "$UDID" ]]; then
  xtool install --udid "$UDID" "$IPA"
else
  xtool install "$IPA"
fi

echo
echo "Installed. If this is the first launch:"
echo "  1. Settings > Privacy & Security > Developer Mode -> ON, then reboot and confirm."
echo "  2. Settings > General > VPN & Device Management -> trust your Apple ID."
echo "  3. Open LedgerLeaf once, then add the Shortcuts Message automation."
echo
echo "Free Apple ID signatures expire after 7 days; re-run this script to re-sign."
