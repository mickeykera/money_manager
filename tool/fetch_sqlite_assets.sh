#!/usr/bin/env bash
# Pre-populate the download cache used by package:sqlite3's build hook.
#
# The hook normally downloads prebuilt SQLite binaries from
# https://github.com/simolus3/sqlite3.dart/releases/download/<tag>/<file>.
# GitHub's release download endpoint intermittently answers with HTTP 504 on
# hosted runners, which makes `flutter test` and `flutter build` fail with a
# hash mismatch ("Hash of downloaded file ... is <html>, expected ...").
#
# The GitHub REST API serves the same bytes reliably, so fetch them through the
# API and place them where the hook expects to find them. The hook still checks
# the SHA-256 of every cached file before reusing it, so this never bypasses the
# package's integrity checks.
#
# Usage: tool/fetch_sqlite_assets.sh
# Requires: gh (authenticated via GH_TOKEN/GITHUB_TOKEN) and flutter pub get.

set -euo pipefail

repo="simolus3/sqlite3.dart"
cache="${PUB_CACHE:-$HOME/.pub-cache}"

version="$(awk '/^  sqlite3:/{flag=1;next} flag && /^    version:/{gsub(/"/,"",$2); print $2; exit}' pubspec.lock)"
if [ -z "$version" ]; then
  echo "Could not determine the sqlite3 package version from pubspec.lock" >&2
  exit 1
fi

hashes_file="$cache/hosted/pub.dev/sqlite3-$version/lib/src/hook/asset_hashes.dart"
if [ ! -f "$hashes_file" ]; then
  echo "Missing $hashes_file; run 'flutter pub get' first" >&2
  exit 1
fi

tag="$(sed -n "s/^const String? releaseTag = '\(.*\)';/\1/p" "$hashes_file")"
if [ -z "$tag" ]; then
  echo "Could not read the release tag from $hashes_file" >&2
  exit 1
fi

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# The hash table also lists the multiple-ciphers and SQLCipher builds; this app
# only uses the upstream SQLite binaries.
sed -n "s/^  '\(libsqlite3\.[^']*\)': '\([0-9a-f]\{64\}\)',/\1 \2/p" "$hashes_file" |
while read -r name expected; do
  asset_id="$(gh api "repos/$repo/releases/tags/$tag" --jq ".assets[] | select(.name == \"$name\") | .id")"
  if [ -z "$asset_id" ]; then
    echo "Release $tag does not contain $name" >&2
    exit 1
  fi

  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  gh api "repos/$repo/releases/assets/$asset_id" \
    -H "Accept: application/octet-stream" >"$tmp"

  actual="$(hash_file "$tmp")"
  if [ "$actual" != "$expected" ]; then
    echo "Hash mismatch for $name: got $actual, expected $expected" >&2
    exit 1
  fi

  dir=".dart_tool/hooks_runner/shared/sqlite3/build/download-${actual:0:8}"
  mkdir -p "$dir"
  case "$name" in
  *.dylib) out="$dir/libsqlite3.dylib" ;;
  *.dll) out="$dir/sqlite3.dll" ;;
  *) out="$dir/libsqlite3.so" ;;
  esac
  mv "$tmp" "$out"
  echo "Cached $name -> $out"
done
