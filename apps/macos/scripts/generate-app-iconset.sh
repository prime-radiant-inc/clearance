#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  apps/macos/scripts/generate-app-iconset.sh [source-svg] [appiconset-dir]

Examples:
  apps/macos/scripts/generate-app-iconset.sh
  apps/macos/scripts/generate-app-iconset.sh /Users/jesse/Downloads/clearance-icon_5.svg
  apps/macos/scripts/generate-app-iconset.sh ./icon.svg ./apps/macos/Clearance/Resources/Assets.xcassets/AppIcon.appiconset
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 2 ]]; then
  usage
  exit 1
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "error: rsvg-convert is required. Install with: brew install librsvg" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_root="$(cd "$script_dir/.." && pwd)"
workspace_root="$(cd "$script_dir/../../.." && pwd)"
default_source_svg="$workspace_root/packages/assets/branding/clearance-app-icon.svg"

source_svg="${1:-$default_source_svg}"
if [[ ! -f "$source_svg" ]]; then
  echo "error: source SVG not found: $source_svg" >&2
  echo "hint: provide a source path or add the default at: $default_source_svg" >&2
  exit 1
fi

icon_dir="${2:-$app_root/Clearance/Resources/Assets.xcassets/AppIcon.appiconset}"

mkdir -p "$icon_dir"

render_icon() {
  local size="$1"
  local name="$2"
  rsvg-convert -w "$size" -h "$size" "$source_svg" -o "$icon_dir/$name"
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
render_icon 1024 icon_512x512@2x.png

cat > "$icon_dir/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Generated AppIcon set at: $icon_dir"
