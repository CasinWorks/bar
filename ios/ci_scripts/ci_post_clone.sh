#!/bin/sh

# Xcode Cloud post-clone hook. Runs from ios/ci_scripts before Xcode resolves
# package dependencies.
#
# Generated.xcconfig, Pods/ and Flutter/ephemeral/Packages are gitignored, so a
# fresh clone has none of them. They must be produced here or the build fails
# resolving FlutterGeneratedPluginSwiftPackage.

set -e

# Keep in sync with .metadata / the Flutter version used locally.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.1}"
FLUTTER_DIR="$HOME/flutter"

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$REPO_ROOT"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "==> Installing Flutter $FLUTTER_VERSION"
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version

# The Xcode project links FlutterGeneratedPluginSwiftPackage, so the tool must
# use Swift Package Manager rather than routing plugins through CocoaPods.
flutter config --enable-swift-package-manager >/dev/null 2>&1 || true

flutter precache --ios

echo "==> Resolving Dart dependencies"
flutter pub get

if ! command -v pod >/dev/null 2>&1; then
  echo "==> Installing CocoaPods"
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
fi

echo "==> Generating iOS build configuration"
flutter build ios --config-only --release --no-codesign

echo "==> Post-clone complete"
