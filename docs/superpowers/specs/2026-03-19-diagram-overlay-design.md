# Expandable Diagram Overlay Design

## Overview

Clearance currently renders Mermaid and Graphviz diagrams inline inside the markdown article body. Large diagrams are constrained by the reading column, which makes them hard to inspect. The first cut should let users click a rendered diagram to view it larger without changing the document into a zoomable canvas.

## Goals

- Make large Mermaid and Graphviz diagrams readable without leaving the current document.
- Keep the primary reading experience simple and document-focused.
- Use one interaction model for both Mermaid and Graphviz.
- Keep the first cut small enough to ship safely.

## Non-Goals

- Add arbitrary zoom controls, pan gestures, or pinch support.
- Add a separate pop-out window for diagrams.
- Change how non-rendered diagram fallbacks behave.
- Add expansion support for images, math blocks, or other rendered content.

## User Experience

### Inline State

- Rendered Mermaid and Graphviz diagrams remain inline in the article where they are today.
- Expandability applies only after a diagram has rendered successfully.
- Expandable diagrams get a subtle affordance so the behavior is discoverable without adding noisy chrome.
- Mouse users can click the diagram to expand it.
- Keyboard users can tab to the diagram and open it with standard activation behavior.

### Expanded State

- Expanding a diagram opens a single in-page overlay above the article content.
- The overlay dims the background and centers a larger copy of the rendered SVG.
- The expanded view scales to fit most of the available window while preserving the diagram's aspect ratio.
- If the expanded diagram is still too large, the overlay content can scroll.
- The overlay can be dismissed by clicking the backdrop, pressing `Esc`, or using an explicit close control.

## Technical Design

### Rendering Hooks

- The HTML builder should mark rendered Mermaid and Graphviz containers as expandable once rendering succeeds.
- The same client-side expansion logic should be shared by both diagram types.
- Raw-source Graphviz fallback blocks should not become expandable, because they are not rendered diagrams.

### Overlay Structure

- Inject one reusable overlay container into the rendered document markup rather than one overlay per diagram.
- When a diagram is activated, copy the rendered SVG into the overlay container.
- On close, clear the overlay contents and return focus to the diagram that launched it.

### Styling

- Keep inline diagrams visually unchanged except for a light affordance and pointer/focus styling.
- Style the overlay to match Clearance's existing reading UI instead of introducing a new visual language.
- The overlay should use scrolling for oversized content rather than clipping the diagram.

### Accessibility

- Expandable diagrams must be keyboard reachable.
- The overlay must support `Esc` to close.
- Focus should move into the overlay on open and return to the source diagram on close.
- The close control should have a clear accessible label.

## Error Handling

- If a diagram fails to render, leave existing fallback behavior unchanged.
- If overlay setup fails, the inline diagram should remain visible and usable as ordinary document content.
- Expansion behavior should not interfere with ordinary article scrolling when no overlay is open.

## Testing

- Add HTML-builder tests that assert rendered Mermaid and Graphviz diagrams receive the expansion hooks.
- Add tests for the overlay scaffolding and the client-side wiring expected in the rendered HTML.
- Manually verify:
  - Mermaid expands and closes.
  - Graphviz expands and closes.
  - `Esc` closes the overlay.
  - Focus returns to the originating diagram.
  - Oversized diagrams remain inspectable via overlay scrolling.

## Recommended Implementation Order

1. Add regression tests for rendered-diagram expansion hooks.
2. Add the reusable overlay markup and styles.
3. Add shared client-side activation and dismissal logic.
4. Verify Mermaid and Graphviz both use the shared path.

## Rationale

This approach solves the readability problem without pushing Clearance toward a diagram-editing workflow. It preserves the app's core identity as a focused markdown reader/editor while still giving large diagrams a practical inspection mode.
