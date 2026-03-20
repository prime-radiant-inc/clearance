# Diagram Overlay Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a click-to-expand overlay for rendered Mermaid and Graphviz diagrams so large diagrams can be viewed at a larger size without leaving the current document.

**Architecture:** Keep diagram rendering inline, but add shared rendered-HTML hooks that mark successfully rendered Mermaid and Graphviz diagrams as expandable. Use one reusable overlay container plus shared client-side open/close logic in the rendered document, and keep the rest of the app unaware of the feature.

**Tech Stack:** Swift, generated HTML/JavaScript in `RenderedHTMLBuilder`, CSS in `render.css`, XCTest

---

## File Map

- Modify: `Clearance/Views/Render/RenderedHTMLBuilder.swift`
  - Add overlay markup, diagram expansion hooks, and shared client-side event handling.
- Modify: `Clearance/Resources/render.css`
  - Add inline affordance styling plus overlay layout and close-button styling.
- Modify: `ClearanceTests/Render/RenderedHTMLBuilderTests.swift`
  - Add regression coverage for expansion hooks and overlay scaffolding.

## Chunk 1: Lock in rendered-diagram hooks

### Task 1: Add failing tests for expandable diagram output

**Files:**
- Modify: `ClearanceTests/Render/RenderedHTMLBuilderTests.swift`
- Test: `ClearanceTests/Render/RenderedHTMLBuilderTests.swift`

- [ ] **Step 1: Add a failing Mermaid expansion test**

Add a test that builds HTML from a Mermaid fence and asserts the output contains hookable markup for expansion, for example:

```swift
func testRenderedMermaidDiagramsExposeExpansionHooks() {
    let html = RenderedHTMLBuilder.build(
        body: """
        ```mermaid
        graph TD
          A[Start] --> B[End]
        ```
        """,
        theme: .neo,
        appearance: .light,
        textScale: 1.0,
        sourceDocumentURL: URL(fileURLWithPath: "/tmp/diagram.md")
    )

    XCTAssertTrue(html.contains("data-clearance-diagram-expandable=\"true\""))
}
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests/testRenderedMermaidDiagramsExposeExpansionHooks`

Expected: FAIL because the current HTML does not expose expansion hooks.

- [ ] **Step 3: Add a failing Graphviz expansion test**

Add a second test for Graphviz that asserts rendered Graphviz output also contains the same shared expansion hook and that raw fallback state is not treated as already expanded content.

- [ ] **Step 4: Run the targeted Graphviz test and verify it fails**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests/testRenderedGraphvizDiagramsExposeExpansionHooks`

Expected: FAIL for the same reason.

- [ ] **Step 5: Commit the red tests**

```bash
git add ClearanceTests/Render/RenderedHTMLBuilderTests.swift
git commit -m "Add failing tests for expandable rendered diagrams"
```

### Task 2: Implement the minimal HTML hooks

**Files:**
- Modify: `Clearance/Views/Render/RenderedHTMLBuilder.swift`
- Test: `ClearanceTests/Render/RenderedHTMLBuilderTests.swift`

- [ ] **Step 1: Mark rendered Mermaid and Graphviz containers as expandable**

Update the rendered HTML so the diagram containers can be targeted consistently, for example by adding attributes like:

```html
data-clearance-diagram-expandable="true"
tabindex="0"
role="button"
```

Only apply those hooks to rendered diagrams, not raw-source fallback content.

- [ ] **Step 2: Re-run the targeted Mermaid and Graphviz tests**

Run:
- `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests/testRenderedMermaidDiagramsExposeExpansionHooks`
- `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests/testRenderedGraphvizDiagramsExposeExpansionHooks`

Expected: PASS.

- [ ] **Step 3: Commit the hook implementation**

```bash
git add Clearance/Views/Render/RenderedHTMLBuilder.swift ClearanceTests/Render/RenderedHTMLBuilderTests.swift
git commit -m "Add expansion hooks for rendered diagrams"
```

## Chunk 2: Build the reusable overlay

### Task 3: Add failing tests for overlay scaffolding and behavior hooks

**Files:**
- Modify: `ClearanceTests/Render/RenderedHTMLBuilderTests.swift`
- Test: `ClearanceTests/Render/RenderedHTMLBuilderTests.swift`

- [ ] **Step 1: Add a failing test for reusable overlay markup**

Add a test that asserts the rendered HTML includes one reusable overlay shell and close control, for example:

```swift
XCTAssertTrue(html.contains("data-clearance-diagram-overlay"))
XCTAssertTrue(html.contains("data-clearance-diagram-overlay-close"))
```

- [ ] **Step 2: Add a failing test for client-side expansion wiring**

Assert the generated script contains the shared open/close wiring for rendered diagrams, such as function names or selector strings that target expandable diagram containers and the overlay.

- [ ] **Step 3: Run the targeted overlay tests and verify they fail**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests`

Expected: FAIL on the new overlay assertions.

- [ ] **Step 4: Commit the new red tests**

```bash
git add ClearanceTests/Render/RenderedHTMLBuilderTests.swift
git commit -m "Add failing tests for diagram overlay scaffolding"
```

### Task 4: Implement overlay markup and shared JavaScript

**Files:**
- Modify: `Clearance/Views/Render/RenderedHTMLBuilder.swift`
- Test: `ClearanceTests/Render/RenderedHTMLBuilderTests.swift`

- [ ] **Step 1: Inject one reusable overlay shell into the generated HTML**

Add markup near the rendered article output for:
- a backdrop container
- a dialog-like content wrapper
- a close button
- a body region that will receive the copied SVG

- [ ] **Step 2: Add shared JavaScript helpers**

Implement the smallest shared functions needed to:
- find expandable diagram containers
- copy the rendered SVG into the overlay body
- open the overlay and move focus into it
- close the overlay on backdrop click, close button, or `Esc`
- restore focus to the launching diagram

- [ ] **Step 3: Make keyboard activation work**

Handle `Enter` and `Space` on the expandable diagram containers so keyboard users can open the overlay.

- [ ] **Step 4: Run the targeted rendered HTML tests**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests`

Expected: PASS.

- [ ] **Step 5: Commit the overlay behavior**

```bash
git add Clearance/Views/Render/RenderedHTMLBuilder.swift ClearanceTests/Render/RenderedHTMLBuilderTests.swift
git commit -m "Add reusable diagram overlay behavior"
```

## Chunk 3: Style and verify the experience

### Task 5: Add overlay and inline-affordance styling

**Files:**
- Modify: `Clearance/Resources/render.css`
- Test: `ClearanceTests/Render/RenderedHTMLBuilderTests.swift`

- [ ] **Step 1: Add minimal inline affordance styles**

Add cursor, focus, and hover styling for expandable diagrams without materially changing the normal reading layout.

- [ ] **Step 2: Add overlay layout styles**

Add CSS for:
- hidden vs open overlay state
- dimmed backdrop
- centered dialog container
- scrollable content area for oversized diagrams
- close button styling

- [ ] **Step 3: Re-run the rendered HTML tests**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/RenderedHTMLBuilderTests`

Expected: PASS.

- [ ] **Step 4: Commit the styling**

```bash
git add Clearance/Resources/render.css ClearanceTests/Render/RenderedHTMLBuilderTests.swift
git commit -m "Style expandable diagram overlay"
```

### Task 6: Run full verification and manual smoke checks

**Files:**
- Modify: none unless verification reveals a real issue
- Test: `ClearanceTests/Render/RenderedHTMLBuilderTests.swift`

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'`

Expected: PASS with no test failures.

- [ ] **Step 2: Run a Debug build**

Run: `xcodebuild -project Clearance.xcodeproj -scheme Clearance -configuration Debug build`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Launch the app and smoke test both diagram types**

Manual checks:
- Open a markdown file with a Mermaid diagram and verify click-to-expand works.
- Open a markdown file with a Graphviz diagram and verify click-to-expand works.
- Verify `Esc` closes the overlay.
- Verify clicking the backdrop closes the overlay.
- Verify the overlay scrolls when the diagram is larger than the window.

- [ ] **Step 4: Commit only if verification required a fix**

If a real bug is found and fixed during verification:

```bash
git add <exact files>
git commit -m "Fix diagram overlay verification issues"
```
