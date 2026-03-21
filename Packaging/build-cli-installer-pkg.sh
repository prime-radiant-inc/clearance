#!/bin/zsh

set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "usage: $0 <cli-binary-path> <output-pkg-path> <version> [installer-sign-identity]" >&2
  exit 1
fi

CLI_BINARY_PATH="$1"
OUTPUT_PKG_PATH="$2"
PKG_VERSION="$3"
INSTALLER_SIGN_IDENTITY="${4:-}"

WORK_DIR="$(mktemp -d "${TMPDIR%/}/clearance-cli-pkg.XXXXXX")"
PAYLOAD_ROOT="$WORK_DIR/payload"
INSTALL_PATH="$PAYLOAD_ROOT/usr/local/bin"
IDENTIFIER="com.primeradiant.ClearanceCLIInstaller"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$INSTALL_PATH"
install -m 755 "$CLI_BINARY_PATH" "$INSTALL_PATH/clearance"
mkdir -p "$(dirname "$OUTPUT_PKG_PATH")"
rm -f "$OUTPUT_PKG_PATH"

PKGBUILD_ARGS=(
  --root "$PAYLOAD_ROOT"
  --identifier "$IDENTIFIER"
  --version "$PKG_VERSION"
  --install-location "/"
)

if [[ -n "$INSTALLER_SIGN_IDENTITY" ]]; then
  PKGBUILD_ARGS+=(--sign "$INSTALLER_SIGN_IDENTITY")
fi

pkgbuild "${PKGBUILD_ARGS[@]}" "$OUTPUT_PKG_PATH"
