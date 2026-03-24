# Neutral Monorepo Workspace Design

## Goal

Restructure Clearance from a single-app macOS repository into a neutral monorepo workspace that keeps the current Swift/Xcode app intact under `apps/macos`, creates a conventional home for a future shared Tauri app under `apps/tauri`, and extracts only the genuinely cross-app DNA that both implementations should share.

## Context

The repository currently treats the repo root as the macOS product root. The Swift app source, tests, Xcode project, packaging scripts, build docs, release notes, shared branding assets, and demo fixtures all live at the top level. That has worked while Clearance was a single macOS app, but it is the wrong shape for the next stage of work.

The next stage is not "replace the macOS app with Tauri." It is "turn the repository into a workspace that can hold multiple implementations without pretending they are the same app." The macOS app should remain buildable and releasable without introducing JS monorepo machinery it does not need, while the future Tauri implementation should have an obvious, conventional place to grow.

That means the first cut should focus on repository boundaries, ownership, and path stability. It should not attempt to extract speculative shared logic or scaffold a real Tauri application before the product and native integration decisions exist.

## Approaches Considered

### 1. Recommended: neutral monorepo with `apps/*`, `packages/*`, and lightweight root workspace tooling

Restructure the repository into:

- `apps/macos` for the current Swift/Xcode app
- `apps/tauri` as the future cross-platform app home
- `packages/*` for shared assets and fixtures
- root workspace docs and minimal Node workspace config

Why this is the right cut:

- Matches the conventional modern monorepo shape without premature tooling.
- Keeps the macOS app self-contained and releasable.
- Gives Windows, Linux, and Android a single conventional home through a future shared Tauri app.
- Extracts only the assets and fixtures that are actually cross-app today.

### 2. JS-first monorepo with `turbo` or `nx` immediately

Adopt a heavier JavaScript task runner and cache layer at the same time as the repository move.

Why not now:

- The repo currently has one real shipping app and no Tauri code.
- Adds indirection and maintenance cost before there is enough JS/Rust work to justify it.
- Turns a path-restructuring task into a toolchain migration.

### 3. Soft move without workspace tooling

Move the macOS app under `apps/macos`, add `apps/tauri`, and stop there.

Why not:

- Leaves the repo without a conventional root workspace contract.
- Means the repo will need another structural change as soon as Tauri work begins.
- Misses the chance to establish a stable, obvious monorepo shape now.

## Recommended Design

### Workspace Layout

Adopt this top-level structure:

- `README.md`
- `package.json`
- `pnpm-workspace.yaml`
- `apps/`
- `packages/`
- `docs/`
- `.github/`

Specific first-cut directories:

- `apps/macos/`
- `apps/tauri/`
- `packages/assets/`
- `packages/demo-corpus/`

The workspace root becomes the coordination layer for repo-wide docs, workflows, and future shared tooling. It is no longer the app root for macOS.

### macOS App Boundary

Move the existing macOS app into `apps/macos/` and keep it internally self-contained. That subtree should own:

- app source
- CLI source
- tests
- Xcode project
- XcodeGen spec
- packaging scripts
- macOS-specific docs
- app release notes
- macOS-specific helper scripts

This keeps the current app operational without forcing cross-platform assumptions onto its codebase.

### Future Tauri Boundary

Create `apps/tauri/` now as a placeholder, not a scaffolded application. It should document the intended role of the future app:

- shared Tauri frontend for Windows and Linux
- future Android target through the same Tauri app
- shared product behavior that will eventually align with the macOS app where reasonable

The placeholder should be minimal. The point is to establish the boundary, not to generate unfinished product code.

### Shared DNA

Move only genuinely shared artifacts into `packages/*` in this first cut.

Initial shared packages:

- `packages/assets`
  - shared branding assets such as `clearance-app-icon.svg`
- `packages/demo-corpus`
  - markdown rendering fixtures and similar reusable sample content

Do not extract Swift application logic just to make the tree look symmetrical. The future Tauri app will not consume Swift source, so that kind of extraction would be ceremony rather than shared DNA.

### Documentation Ownership

Split workspace documentation from app documentation.

Root documentation:

- workspace overview
- repo layout
- how to find each app
- workspace-level contribution conventions

macOS app documentation:

- build, test, release, and packaging instructions for the Swift/Xcode app
- product-focused README content for the currently shipping app

That yields:

- root `README.md` as the workspace README
- `apps/macos/README.md` as the app README
- `apps/macos/docs/DEVELOPMENT.md` as the macOS developer/release guide

Existing repo-wide planning/spec documents under `docs/` should remain at the root. They describe workspace history and engineering decisions, not just the macOS app.

### Release and Versioning

Keep release tags and GitHub releases repo-wide for now. The current shipping product is still the macOS app, so tags like `v1.3.1` continue to represent the workspace release for that app.

Do not invent per-app versioning or multi-product release semantics in this cut. That should wait until there is more than one real shipping implementation.

### Root Workspace Tooling

Add lightweight Node workspace metadata now:

- root `package.json`
- root `pnpm-workspace.yaml`

Purpose:

- establish a normal monorepo contract
- give the future Tauri app a conventional home
- expose a few root scripts that delegate into `apps/macos`

Do not add `turbo`, `nx`, or other orchestration layers yet.

## Physical Move Plan

### Move Into `apps/macos`

Move these current root items into `apps/macos/`:

- `Clearance/`
- `ClearanceCLI/`
- `ClearanceTests/`
- `Clearance.xcodeproj/`
- `project.yml`
- `Packaging/`
- `CHANGELOG.md`
- current product README content
- current developer documentation
- macOS-specific scripts and script docs

### Move Into `packages`

Move these current root items into shared packages:

- `assets/branding/...` -> `packages/assets/branding/...`
- `docs/demo-corpus/...` -> `packages/demo-corpus/...`

### Leave At Root

Keep these at the workspace root:

- `.github/`
- `docs/` except the moved macOS developer doc and shared fixture content
- `LICENSE`
- repo-wide planning and superpowers docs

## Workflow and Tooling Changes

### GitHub Actions

Update `.github/workflows/release.yml` so it builds from the new macOS app location. That includes:

- using `apps/macos/Clearance.xcodeproj`
- generating from `apps/macos/project.yml`
- invoking packaging scripts from `apps/macos/Packaging/...`
- keeping release artifacts and tags repo-wide

The workflow remains a workspace-level workflow that explicitly targets the macOS app.

### XcodeGen and Project Paths

Update the XcodeGen spec and generated project so relative paths remain correct after the move. This includes:

- source roots
- `CHANGELOG.md` resource inclusion
- Info.plist location
- test fixture resources
- packaging script paths

### Scripts

Update any scripts that assume the repo root is the app root. In practice that means:

- app icon generation paths
- script README examples
- root documentation examples

## Non-Goals

- Scaffold a real Tauri application.
- Extract speculative shared Rust, TypeScript, or Swift logic.
- Introduce `turbo`, `nx`, or a larger JS build graph.
- Redesign the release model around multiple shipping apps.
- Change the macOS app architecture beyond what the new paths require.

## Verification Strategy

After the move:

1. Generate the Xcode project from `apps/macos/project.yml`.
2. Build the macOS app from `apps/macos`.
3. Run the macOS test suite from `apps/macos`.
4. Sanity-check the release workflow path changes.
5. Confirm the root README accurately describes the workspace layout and entry points.

## Risks

- Path-sensitive XcodeGen and packaging configuration can break in subtle ways if the move is incomplete.
- Shared fixture extraction can quietly break tests if resource paths are not updated consistently.
- Root docs can become misleading if the workspace/app split is only partially reflected.
- Introducing too much placeholder infrastructure now would create maintenance burden before Tauri exists.

## Decision

Proceed with a neutral monorepo conversion that:

- moves the current Swift app into `apps/macos`
- creates `apps/tauri` as a placeholder for the future shared Tauri app
- moves shared branding assets and demo fixtures into `packages/*`
- turns the repo root into the workspace entry point
- updates GitHub Actions and path-sensitive tooling to build the macOS app from its new subtree
- keeps the first cut intentionally light on JS tooling and intentionally conservative on shared-code extraction
