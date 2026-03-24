# Clearance Development

This document is for contributors and maintainers.

## Build and Run

1. Generate the Xcode project:

```bash
cd apps/macos && xcodegen generate
```

2. Build:

```bash
cd apps/macos && xcodebuild -project Clearance.xcodeproj -scheme Clearance -configuration Debug -destination 'platform=macOS' build
```

3. Run tests:

```bash
cd apps/macos && xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'
```

4. Open `Clearance.xcodeproj` in Xcode and run `Clearance`.

From the workspace root, that project now lives at `apps/macos/Clearance.xcodeproj`.

## Releases and Sparkle

Tag pushes (`v*`) run `.github/workflows/release.yml` and:

- Build a Release app
- Codesign with Developer ID Application cert
- Notarize and staple
- Package a release ZIP and DMG
- Generate/sign `appcast.xml` with Sparkle EdDSA keys
- Publish release artifacts to GitHub Releases

Versioning automation:

- `CFBundleShortVersionString` is derived from the git tag (`v0.0.5` -> `0.0.5`)
- `CFBundleVersion` is derived from `GITHUB_RUN_NUMBER` (monotonic integer)

Sparkle runtime config:

- `SUFeedURL = $(SPARKLE_FEED_URL)`
- `SUPublicEDKey = $(SPARKLE_PUBLIC_ED_KEY)`

If required Sparkle values are missing, `Check for Updates…` is disabled.

## Required GitHub Secrets

- `DEVELOPER_ID_APPLICATION_CERT_BASE64`
- `DEVELOPER_ID_APPLICATION_CERT_PASSWORD`
- `DEVELOPER_ID_APPLICATION_SIGNING_IDENTITY`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`
- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_PRIVATE_ED_KEY`

## Release Procedure

1. Ensure required GitHub secrets are set.
2. Create and push a version tag:

```bash
git tag v0.0.1
git push origin v0.0.1
```

3. Wait for the release workflow to finish.

## Asset Regeneration

Regenerate app icon assets from the source SVG:

```bash
scripts/generate-app-iconset.sh
```

## Notes

- Markdown rendering and editing operate locally.
- CodeMirror vendor assets remain in-repo under `apps/macos/Clearance/Resources/vendor/codemirror`.
- Shared markdown fixtures live under `packages/demo-corpus`.
- Release artifacts are generated in CI.
