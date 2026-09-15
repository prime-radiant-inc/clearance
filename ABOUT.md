# clearance

> Clearance product workspace: a monorepo currently shipping a native Swift/macOS Markdown viewer, with structure for future shared Tauri implementations.

**Family:** dev-tools · **Type:** app · **Lifecycle:** production · **Owner:** obra

## What it does
This repository is the Clearance product workspace. It currently ships a native macOS Markdown viewer app under `apps/macos` (Swift/Xcode, with release notes, packaging scripts, and CodeMirror-based editing). The monorepo also reserves `apps/tauri` as a placeholder for a future shared Tauri app targeting Windows, Linux, and Android, plus `packages/assets` (shared branding) and `packages/demo-corpus` (shared markdown fixtures).

## How it fits
- Depends on: — (no internal prime-radiant-inc dependencies; Swift packages are external: Sparkle, swift-cmark, swift-markdown, Yams)
- Used by: —
- External: Sparkle (updates), swift-markdown / swift-cmark (Markdown parsing), CodeMirror (vendored editor)

## Runtime & data
- Runs: native macOS SwiftUI app
- Data in: local Markdown files
- Data out: rendered Markdown display; recent-files store

<!-- Maintained by the maintaining-project-map skill. Do not hand-edit; regenerated. -->
