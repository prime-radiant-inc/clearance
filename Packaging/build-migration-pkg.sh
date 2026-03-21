#!/bin/zsh

set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "usage: $0 <app-path> <output-pkg-path> <version> [installer-sign-identity]" >&2
  exit 1
fi

APP_PATH="$1"
OUTPUT_PKG_PATH="$2"
PKG_VERSION="$3"
INSTALLER_SIGN_IDENTITY="${4:-}"
IDENTIFIER="com.primeradiant.ClearanceMigrationInstaller"
COMPONENT_IDENTIFIER="com.primeradiant.ClearanceMigrationComponent"
WORK_DIR="$(mktemp -d "${TMPDIR%/}/clearance-migration-pkg.XXXXXX")"
ROOT_PATH="$WORK_DIR/root"
COMPONENT_PLIST_PATH="$WORK_DIR/component.plist"
COMPONENT_PACKAGE_PATH="$WORK_DIR/ClearanceMigrationComponent.pkg"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$(dirname "$OUTPUT_PKG_PATH")"
rm -f "$OUTPUT_PKG_PATH"

mkdir -p "$ROOT_PATH/Applications"
ditto "$APP_PATH" "$ROOT_PATH/Applications/$(basename "$APP_PATH")"

pkgbuild --analyze --root "$ROOT_PATH" "$COMPONENT_PLIST_PATH" >/dev/null
/usr/libexec/PlistBuddy -c "Set :0:BundleHasStrictIdentifier false" "$COMPONENT_PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$COMPONENT_PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :0:BundleIsVersionChecked false" "$COMPONENT_PLIST_PATH"

pkgbuild \
  --root "$ROOT_PATH" \
  --component-plist "$COMPONENT_PLIST_PATH" \
  --identifier "$COMPONENT_IDENTIFIER" \
  --version "$PKG_VERSION" \
  "$COMPONENT_PACKAGE_PATH" >/dev/null

PRODUCTBUILD_ARGS=(
  --package "$COMPONENT_PACKAGE_PATH"
  --identifier "$IDENTIFIER"
  --version "$PKG_VERSION"
)

if [[ -n "$INSTALLER_SIGN_IDENTITY" ]]; then
  PRODUCTBUILD_ARGS+=(--sign "$INSTALLER_SIGN_IDENTITY")
fi

productbuild "${PRODUCTBUILD_ARGS[@]}" "$OUTPUT_PKG_PATH"
