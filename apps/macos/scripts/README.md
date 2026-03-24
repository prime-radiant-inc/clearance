# Scripts

## Regenerate App Icon Set

Use this script to rebuild `AppIcon.appiconset` from an SVG source:

```bash
cd apps/macos
scripts/generate-app-iconset.sh
```

By default it reads:

- `packages/assets/branding/clearance-app-icon.svg`

And writes:

- `apps/macos/Clearance/Resources/Assets.xcassets/AppIcon.appiconset`

You can override source and output paths:

```bash
cd apps/macos
scripts/generate-app-iconset.sh /path/to/icon.svg /path/to/AppIcon.appiconset
```

## Generate Sparkle Signing Keys

Generate or retrieve Sparkle EdDSA keys for release signing:

```bash
cd apps/macos
scripts/generate-sparkle-keys.sh
```

Optional custom account name:

```bash
cd apps/macos
scripts/generate-sparkle-keys.sh your-org
```

This prints:

- `SPARKLE_PUBLIC_ED_KEY` for app build settings.
- `SPARKLE_PRIVATE_ED_KEY` for GitHub Actions release signing.
