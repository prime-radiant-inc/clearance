# New File, CLI Helper, and Heading Code Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land inline code rendering inside headings, add a `File > New…` markdown flow, and ship a bundled `clearance` CLI helper with a best-effort installer in Settings.

**Architecture:** Keep the changes small and reuse one creation/opening path across UI and CLI. Add a focused file-creation service and CLI helper service rather than spreading filesystem logic through views. Test each behavior first, then implement the minimum code to satisfy it.

**Tech Stack:** SwiftUI, AppKit, Foundation, XcodeGen, XCTest

---

## Chunk 1: Inline Code In Headings

### Task 1: Add regression coverage for heading inline code

**Files:**
- Modify: `ClearanceTests/Render/RenderedHTMLBuilderTests.swift`

- [ ] Add a test that renders a heading containing backticks and expects `<code>` markup inside the generated heading HTML.
- [ ] Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests`
- [ ] Confirm the new test fails for the current implementation.

### Task 2: Implement the minimal heading formatter change

**Files:**
- Modify: `Clearance/Views/Render/RenderedMarkdownHTMLFormatter.swift`

- [ ] Change heading rendering to preserve inline markup instead of flattening headings to plain text.
- [ ] Re-run the targeted render tests and confirm they pass.
- [ ] Commit the heading fix and regression test.

## Chunk 2: New File Flow

### Task 3: Add tests for new markdown file creation behavior

**Files:**
- Modify: `ClearanceTests/ViewModels/WorkspaceViewModelTests.swift`
- Modify: `ClearanceTests/Views/WorkspaceToolbarTests.swift`

- [ ] Add a view-model test for creating a new markdown file, opening it as the active session, adding it to History, and switching to Edit mode.
- [ ] Add a command test that locks in the `New…` title and `Cmd-N` shortcut.
- [ ] Run the targeted tests and confirm the new cases fail.

### Task 4: Add a reusable file-creation path

**Files:**
- Create: `Clearance/Services/NewDocumentService.swift`
- Modify: `Clearance/ViewModels/WorkspaceViewModel.swift`
- Modify: `Clearance/Services/OpenPanelService.swift`
- Modify: `Clearance/Views/WorkspaceView.swift`
- Modify: `Clearance/App/ClearanceApp.swift`

- [ ] Add a service that runs a save panel, creates a markdown file with a simple starter heading, and returns its URL.
- [ ] Add a view-model entry point that opens the newly created file in Edit mode.
- [ ] Wire `File > New…`, `Cmd-N`, and the empty-state action to this shared path.
- [ ] Re-run the targeted tests and then the full suite.
- [ ] Commit the new-file flow.

## Chunk 3: CLI Helper And Installer

### Task 5: Add failing tests for helper packaging and install behavior

**Files:**
- Create: `ClearanceTests/Services/CLIInstallerTests.swift`
- Modify: `ClearanceTests/ViewModels/WorkspaceViewModelTests.swift` if shared creation/opening behavior needs more coverage

- [ ] Add tests for best-effort installer behavior: creating a symlink when possible, replacing an existing symlink, and surfacing a write error.
- [ ] If helper argument parsing is factored into testable Swift code, add unit tests for open existing file, open directory, and create missing file cases.
- [ ] Run targeted tests and confirm they fail.

### Task 6: Add the bundled helper and installer

**Files:**
- Create: `ClearanceCLI/main.swift`
- Create: `Clearance/Services/CLIInstaller.swift`
- Create: `Clearance/Services/CLIArgumentPlanner.swift` if needed for shared parsing/creation logic
- Modify: `project.yml`
- Modify: `Clearance/Views/SettingsView.swift`
- Modify: `.github/workflows/release.yml`

- [ ] Add a small Swift executable target for `clearance`.
- [ ] Bundle the helper inside the app.
- [ ] Add a Settings button that symlinks `/usr/local/bin/clearance` to the bundled helper and reports the real filesystem error on failure.
- [ ] Update the release workflow so the bundled helper is signed before the app bundle is signed.
- [ ] Re-run targeted tests, full tests, and a Debug build.
- [ ] Commit the CLI helper and installer.

## Chunk 4: Final Verification

### Task 7: End-to-end verification

**Files:**
- Modify: `CHANGELOG.md` only if Jesse asks for a release in this same turn

- [ ] Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'`
- [ ] Run: `xcodebuild -project Clearance.xcodeproj -scheme Clearance -configuration Debug build`
- [ ] Manually verify the bundled helper path in the built app if feasible.
- [ ] Summarize what landed, what was verified, and any remaining follow-up.
