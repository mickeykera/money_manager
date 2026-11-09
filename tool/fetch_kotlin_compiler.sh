#!/usr/bin/env bash
# Pre-seed the Kotlin compiler jar used by the Android Gradle build.
#
# Gradle normally downloads kotlin-compiler-embeddable from Maven Central. On
# hosted runners that request is occasionally redirected to
# https://github.com/JetBrains/kotlin/releases/download/v<version>/... which can
# answer HTTP 504 ("Gateway Time-out"), failing the release build.
#
# The GitHub REST API serves the identical jar reliably, so fetch it there and
# expose it through the local Maven repository. android/build.gradle.kts lists
# mavenLocal() first, so Gradle picks it up before touching the network.
#
# Usage: tool/fetch_kotlin_compiler.sh
# Requires: gh (authenticated via GH_TOKEN/GITHUB_TOKEN) and curl.

set -euo pipefail

version="$(sed -n 's/.*org\.jetbrains\.kotlin\.android.*version "\([0-9][0-9.]*\)".*/\1/p' android/settings.gradle.kts | head -n 1)"
if [ -z "$version" ]; then
  echo "Could not read the Kotlin version from android/settings.gradle.kts" >&2
  exit 1
fi

group_path="org/jetbrains/kotlin/kotlin-compiler-embeddable/$version"
dest="$HOME/.m2/repository/$group_path"
mkdir -p "$dest"

jar="$dest/kotlin-compiler-embeddable-$version.jar"
pom="$dest/kotlin-compiler-embeddable-$version.pom"

if [ ! -s "$jar" ]; then
  asset_id="$(gh api "repos/JetBrains/kotlin/releases/tags/v$version" \
    --jq ".assets[] | select(.name == \"kotlin-compiler-embeddable-$version.jar\") | .id")"
  if [ -z "$asset_id" ]; then
    echo "Kotlin release v$version does not contain the compiler jar" >&2
    exit 1
  fi

  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  gh api "repos/JetBrains/kotlin/releases/assets/$asset_id" \
    -H "Accept: application/octet-stream" >"$tmp"

  # Reject HTML error pages before publishing the artifact locally.
  if ! unzip -tq "$tmp" >/dev/null 2>&1; then
    echo "Downloaded Kotlin compiler is not a valid jar" >&2
    exit 1
  fi
  mv "$tmp" "$jar"
fi

if [ ! -s "$pom" ]; then
  for mirror in \
    "https://repo.maven.apache.org/maven2" \
    "https://repo1.maven.org/maven2" \
    "https://maven-central.storage-download.googleapis.com/maven2"; do
    if curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 \
      "$mirror/$group_path/kotlin-compiler-embeddable-$version.pom" -o "$pom" &&
      grep -q '<artifactId>kotlin-compiler-embeddable</artifactId>' "$pom"; then
      break
    fi
    rm -f "$pom"
  done
fi

if [ ! -s "$pom" ]; then
  echo "Could not download the Kotlin compiler POM" >&2
  exit 1
fi

echo "Kotlin compiler $version seeded at $jar"
