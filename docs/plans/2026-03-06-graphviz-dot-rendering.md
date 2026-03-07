# Graphviz DOT Rendering Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Graphviz DOT fenced-block rendering to the rendered Markdown view using the same bundled, offline model as Mermaid.

**Architecture:** Extend `RenderedHTMLBuilder` so fenced `dot` and `graphviz` blocks become dedicated render containers instead of plain code blocks. Bundle the browser-ready `@viz-js/viz` global build, render DOT to inline SVG during the existing rich-renderer bootstrap, and sanitize generated SVG so untrusted content does not introduce scriptable attributes or embedded foreign content.

**Tech Stack:** Swift 6, SwiftUI, WebKit, xcodegen, XCTest, bundled browser JavaScript (`@viz-js/viz` 3.25.0).

---

### Task 1: Add red tests for DOT transforms and bootstrap

**Files:**
- Modify: `ClearanceTests/Render/RenderedHTMLBuilderTests.swift`

**Step 1: Write the failing test**

Add tests for:
- ` ```dot ` blocks becoming Graphviz containers.
- ` ```graphviz ` blocks becoming Graphviz containers.
- The rich-renderer bundle including a Graphviz script tag.
- The bootstrap script invoking `Viz.instance()` and ignoring `.graphviz` during inline math rendering.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests`
Expected: FAIL because DOT blocks still render as plain code blocks and no Graphviz bootstrap exists.

**Step 3: Write minimal implementation**

Do not write production code yet.

**Step 4: Run test to verify it still fails**

Run: same command as step 2
Expected: FAIL with the new Graphviz expectations.

**Step 5: Commit**

```bash
git add ClearanceTests/Render/RenderedHTMLBuilderTests.swift
git commit -m "test: define graphviz renderer expectations"
```

### Task 2: Bundle the Graphviz runtime

**Files:**
- Create: `Clearance/Resources/vendor/viz/viz-global.js`
- Create: `Clearance/Resources/vendor/viz/LICENSE`

**Step 1: Write the failing test**

No new test. Existing red tests from Task 1 should cover missing runtime references.

**Step 2: Run test to verify it still fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests`
Expected: FAIL because the Swift renderer still does not include the new vendor asset.

**Step 3: Write minimal implementation**

Vendor `@viz-js/viz` 3.25.0 `dist/viz-global.js` and add its MIT license text.

**Step 4: Run test to verify it still fails**

Run: same command as step 2
Expected: FAIL because the Swift-side renderer has not been wired to load the asset yet.

**Step 5: Commit**

```bash
git add Clearance/Resources/vendor/viz/viz-global.js Clearance/Resources/vendor/viz/LICENSE
git commit -m "chore: vendor graphviz browser runtime"
```

### Task 3: Implement DOT block rendering and SVG sanitization

**Files:**
- Modify: `Clearance/Views/Render/RenderedHTMLBuilder.swift`
- Modify: `Clearance/Resources/render.css`

**Step 1: Write the failing test**

Use the red tests from Task 1.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests`
Expected: FAIL before production changes.

**Step 3: Write minimal implementation**

Implement:
- DOT/Graphviz fenced-block detection in `transformCodeBlocks`.
- A Graphviz vendor script in `richRendererScripts`.
- A Graphviz bootstrap path that creates a single `Viz.instance()` promise and renders `.graphviz` blocks to SVG.
- Sanitization of generated SVG by removing scriptable attributes and dangerous embedded content before inserting it.
- CSS for Graphviz containers and rendered SVG sizing.
- `graphviz` in the inline-math ignored class list so KaTeX never mutates DOT source blocks.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add Clearance/Views/Render/RenderedHTMLBuilder.swift Clearance/Resources/render.css ClearanceTests/Render/RenderedHTMLBuilderTests.swift
git commit -m "feat: render graphviz dot blocks"
```

### Task 4: Regenerate the project and run full verification

**Files:**
- Modify: `Clearance.xcodeproj/project.pbxproj`

**Step 1: Write the failing test**

No new test. This task is verification and project regeneration.

**Step 2: Run test to verify the project picks up new resources**

Run: `xcodegen generate`
Expected: project regenerated successfully with the new vendor files.

**Step 3: Write minimal implementation**

No code change beyond the regenerated project.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'`
Expected: PASS for the full macOS suite.

**Step 5: Commit**

```bash
git add Clearance.xcodeproj/project.pbxproj
git commit -m "chore: regenerate project for graphviz assets"
```
