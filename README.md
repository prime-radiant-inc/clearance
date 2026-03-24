# Clearance Workspace

This repository is the Clearance product workspace. It currently ships a native macOS app and now has the monorepo structure needed for alternate implementations to grow alongside it.

## Workspace Layout

- `apps/macos`: the current Swift/Xcode app, release notes, packaging scripts, and macOS-specific docs
- `apps/tauri`: placeholder home for the future shared Tauri app targeting Windows, Linux, and Android
- `packages/assets`: shared branding and static assets
- `packages/demo-corpus`: shared markdown fixtures that current and future implementations can reuse
- `docs`: workspace-level specs, plans, and engineering notes

## Current App

The shipping app lives in [apps/macos/README.md](apps/macos/README.md). For macOS build, test, release, and CI details, see [apps/macos/docs/DEVELOPMENT.md](apps/macos/docs/DEVELOPMENT.md).

## Workspace Scripts

- `npm run macos:generate`: generate the macOS Xcode project from `apps/macos/project.yml`
- `npm run macos:build`: build the macOS app from `apps/macos`
- `npm run macos:test`: run the macOS test suite from `apps/macos`

## Contributing

- Put app-specific changes in the owning app directory, not at the workspace root.
- Put genuinely shared assets and fixtures in `packages/*`.
- Keep root docs and workflows workspace-oriented rather than macOS-only unless there is no shared concern.

## About

Copyright 2026 Prime Radiant  
[https://primeradiant.com](https://primeradiant.com)
