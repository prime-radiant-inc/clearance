# Clearance

<img src="../../packages/assets/branding/clearance-app-icon.svg" alt="Clearance Icon" width="96" />

Clearance is a native macOS app for reading and editing Markdown files, with first-class support for YAML-frontmatter documents.

For developer setup, build, release, and CI details, see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Install

1. Download the latest release from GitHub.
2. Open the `.dmg` (or `.zip`) and move `Clearance.app` into `Applications`.
3. Launch Clearance and open a Markdown file.

## What You Can Do

- Open `.md` and `.txt` files.
- Keep a recent-files sidebar with full paths, grouped by recency.
- Switch between:
  - `View`: rendered document mode
  - `Edit`: full-pane Markdown editing with syntax highlighting
- Use the right-side outline for heading navigation when a document has headings.
- Open selected files in new windows.
- Follow Markdown links to local files or web URLs.
- Auto-save while editing.

## Keyboard Shortcuts

- `⌘O`: Open Markdown file
- `⇧⌘O`: Open current document in a new window
- `⌘F`: Find in document
- `⇧⌘F`: Find previous match
- `⌘P`: Print (rendered output)
- `⌘Z`: Undo (Edit mode)
- `⇧⌘Z`: Redo (Edit mode)
- `⌘1`: View mode
- `⌘2`: Edit mode

## Privacy and Runtime Behavior

- Clearance is fully local at runtime for normal editing and rendering.
- No CDN dependencies are used.
- Network activity is optional and limited to things you explicitly trigger, such as opening web links or checking for updates.

## Updates

Clearance uses Sparkle for in-app updates. You can use `Clearance → Check for Updates…` from the menu bar.

## About

Copyright 2026 Prime Radiant  
[https://primeradiant.com](https://primeradiant.com)
