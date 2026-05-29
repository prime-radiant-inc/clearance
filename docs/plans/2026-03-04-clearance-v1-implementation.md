# Clearance V1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a first working macOS app for opening YAML-frontmatter Markdown files, viewing rendered output, editing with syntax highlighting, autosaving, and tracking recent files in a sidebar.

**Architecture:** Create a native SwiftUI macOS app shell with AppKit integration for file open and pop-out windows. Use a Swift core for file/session state and YAML frontmatter parsing, and WKWebView-based surfaces for edit (CodeMirror) and rendered display (HTML/CSS). Keep scope minimal and iterative while preserving required behavior.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, WebKit, xcodegen, Yams (YAML parsing), Down (Markdown-to-HTML), XCTest.

---

### Task 1: Bootstrap project

**Files:**
- Create: `project.yml`
- Create: `Clearance/App/ClearanceApp.swift`
- Create: `Clearance/App/AppDelegate.swift`
- Create: `Clearance/Views/WorkspaceView.swift`
- Create: `Clearance/Resources/Assets.xcassets/Contents.json`
- Create: `Clearance/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `ClearanceTests/SmokeTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest

final class SmokeTests: XCTestCase {
    func testProjectCompiles() {
        XCTAssertTrue(true)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodegen generate && xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'`
Expected: FAIL because app source files are not present yet.

**Step 3: Write minimal implementation**

Add minimal app entry and placeholder workspace view so the app target compiles.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'`
Expected: PASS.

**Step 5: Commit**

```bash
git add project.yml Clearance ClearanceTests
git commit -m "chore: bootstrap clearance macos app"
```

### Task 2: Add recent-files LRU model with tests

**Files:**
- Create: `Clearance/Models/RecentFileEntry.swift`
- Create: `Clearance/Models/RecentFilesStore.swift`
- Create: `ClearanceTests/RecentFilesStoreTests.swift`

**Step 1: Write the failing test**

Add tests for:
- New opens go to top.
- Re-opening existing file moves it to top without duplicates.
- Persistence round-trip from UserDefaults.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RecentFilesStoreTests`
Expected: FAIL because store types do not exist.

**Step 3: Write minimal implementation**

Implement `RecentFilesStore` with in-memory list + UserDefaults save/load.

**Step 4: Run test to verify it passes**

Run: same command as step 2
Expected: PASS.

**Step 5: Commit**

```bash
git add Clearance/Models/RecentFileEntry.swift Clearance/Models/RecentFilesStore.swift ClearanceTests/RecentFilesStoreTests.swift
git commit -m "feat: add recent files lru model"
```

### Task 3: Add frontmatter parsing and flattening with tests

**Files:**
- Create: `Clearance/Models/ParsedMarkdownDocument.swift`
- Create: `Clearance/Services/FrontmatterParser.swift`
- Create: `ClearanceTests/FrontmatterParserTests.swift`

**Step 1: Write the failing test**

Add tests for:
- Document with YAML header parses header/body.
- Document without header keeps full body.
- Nested objects/arrays flatten to dot/bracket key paths.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/FrontmatterParserTests`
Expected: FAIL because parser types do not exist.

**Step 3: Write minimal implementation**

Implement parser using Yams and key-flattening utility.

**Step 4: Run test to verify it passes**

Run: same command as step 2
Expected: PASS.

**Step 5: Commit**

```bash
git add Clearance/Models/ParsedMarkdownDocument.swift Clearance/Services/FrontmatterParser.swift ClearanceTests/FrontmatterParserTests.swift project.yml
git commit -m "feat: parse and flatten markdown frontmatter"
```

### Task 4: Add file session + autosave behavior with tests

**Files:**
- Create: `Clearance/Models/DocumentSession.swift`
- Create: `Clearance/Services/FileIO.swift`
- Create: `ClearanceTests/DocumentSessionTests.swift`

**Step 1: Write the failing test**

Add tests for:
- Loading file reads text.
- Editing marks session dirty.
- Debounced autosave writes edited content.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/DocumentSessionTests`
Expected: FAIL due missing types.

**Step 3: Write minimal implementation**

Implement file-backed `DocumentSession` and debounced autosave.

**Step 4: Run test to verify it passes**

Run: same command as step 2
Expected: PASS.

**Step 5: Commit**

```bash
git add Clearance/Models/DocumentSession.swift Clearance/Services/FileIO.swift ClearanceTests/DocumentSessionTests.swift
git commit -m "feat: add document session with autosave"
```

### Task 5: Build workspace UI wiring

**Files:**
- Modify: `Clearance/Views/WorkspaceView.swift`
- Create: `Clearance/Views/Sidebar/RecentFilesSidebar.swift`
- Create: `Clearance/ViewModels/WorkspaceViewModel.swift`
- Create: `Clearance/Services/OpenPanelService.swift`

**Step 1: Write the failing test**

Add view-model tests for:
- Opening URL creates active session.
- Opening URL inserts recent entry at top.
- Selecting recent URL reopens session.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/WorkspaceViewModelTests`
Expected: FAIL due missing view model.

**Step 3: Write minimal implementation**

Implement view model + sidebar list and open-file action.

**Step 4: Run test to verify it passes**

Run: same command as step 2
Expected: PASS.

**Step 5: Commit**

```bash
git add Clearance/Views/WorkspaceView.swift Clearance/Views/Sidebar/RecentFilesSidebar.swift Clearance/ViewModels/WorkspaceViewModel.swift Clearance/Services/OpenPanelService.swift ClearanceTests/WorkspaceViewModelTests.swift
git commit -m "feat: wire workspace open and recent files sidebar"
```

### Task 6: Add rendered view mode

**Files:**
- Create: `Clearance/Views/Render/RenderedMarkdownView.swift`
- Create: `Clearance/Views/Render/RenderedHTMLBuilder.swift`
- Create: `Clearance/Resources/render.css`
- Modify: `Clearance/Views/WorkspaceView.swift`

**Step 1: Write the failing test**

Add tests for HTML builder:
- Frontmatter table rows include flattened keys.
- Markdown body HTML is included.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests`
Expected: FAIL due missing builder.

**Step 3: Write minimal implementation**

Implement HTML builder and SwiftUI view-mode renderer with polished CSS.

**Step 4: Run test to verify it passes**

Run: same command as step 2
Expected: PASS.

**Step 5: Commit**

```bash
git add Clearance/Views/Render Clearance/Resources/render.css Clearance/Views/WorkspaceView.swift ClearanceTests/RenderedHTMLBuilderTests.swift
git commit -m "feat: add rendered markdown view with frontmatter table"
```

### Task 7: Add edit mode with syntax highlighting

**Files:**
- Create: `Clearance/Views/Edit/CodeMirrorEditorView.swift`
- Create: `Clearance/Resources/editor.html`
- Modify: `Clearance/Views/WorkspaceView.swift`

**Step 1: Write the failing test**

Add a lightweight integration test that validates editor bootstrap HTML contains `CodeMirror` setup and markdown mode config.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/EditorTemplateTests`
Expected: FAIL due missing template.

**Step 3: Write minimal implementation**

Implement WKWebView wrapper for CodeMirror editing, text sync, and high undo depth.

**Step 4: Run test to verify it passes**

Run: same command as step 2
Expected: PASS.

**Step 5: Commit**

```bash
git add Clearance/Views/Edit/CodeMirrorEditorView.swift Clearance/Resources/editor.html Clearance/Views/WorkspaceView.swift ClearanceTests/EditorTemplateTests.swift
git commit -m "feat: add markdown editor mode with syntax highlighting"
```

### Task 8: Add settings, pop-out, and file association

**Files:**
- Create: `Clearance/Models/AppSettings.swift`
- Create: `Clearance/Views/SettingsView.swift`
- Create: `Clearance/Windows/PopoutWindowController.swift`
- Modify: `Clearance/App/ClearanceApp.swift`
- Modify: `project.yml`

**Step 1: Write the failing test**

Add tests for settings model:
- Default open mode resolves to view.
- Persisting edit mode restores after reload.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/AppSettingsTests`
Expected: FAIL due missing settings model.

**Step 3: Write minimal implementation**

Implement settings, pop-out window action, and `.md` document type declaration.

**Step 4: Run test to verify it passes**

Run: same command as step 2
Expected: PASS.

**Step 5: Commit**

```bash
git add Clearance/Models/AppSettings.swift Clearance/Views/SettingsView.swift Clearance/Windows/PopoutWindowController.swift Clearance/App/ClearanceApp.swift project.yml ClearanceTests/AppSettingsTests.swift
git commit -m "feat: add settings popout and md association"
```

### Task 9: Final verification

**Files:**
- Modify: `README.md`

**Step 1: Run full tests**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'`
Expected: PASS.

**Step 2: Build app**

Run: `xcodebuild -project Clearance.xcodeproj -scheme Clearance -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

**Step 3: Smoke run app manually**

- Open `.md` file.
- Verify sidebar ordering and path display.
- Toggle view/edit.
- Confirm autosave by editing and reopening file.
- Confirm pop-out opens separate window.

**Step 4: Document run instructions**

Add quick start and known limitations in `README.md`.

**Step 5: Commit**

```bash
git add README.md
git commit -m "docs: add clearance v1 usage and verification notes"
```

## Future Work

- Add richer color coding to the editor, including clearer Markdown token colors and code-fence-aware syntax colors, while preserving fast typing performance on large documents.
