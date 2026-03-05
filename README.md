# Clearance

Clearance is a native macOS Markdown workspace focused on YAML-frontmatter Markdown files.

## Current V1 Capabilities

- Open `.md` / Markdown files from the app.
- Sidebar of recently opened files (file name + full path), newest first.
- View mode:
  - Beautiful rendered Markdown document.
  - Frontmatter rendered as a full metadata table.
- Edit mode:
  - Syntax-highlighted Markdown editing via embedded CodeMirror.
  - Deep undo history (`undoDepth: 10000`).
- Autosave with debounced writes while editing.
- Default open mode setting (`View` or `Edit`).
- Pop-out document windows from the workspace.
- `.md` file association declared in app `Info.plist`.

## Build and Run

1. Generate the Xcode project:

```bash
xcodegen generate
```

2. Build:

```bash
xcodebuild -project Clearance.xcodeproj -scheme Clearance -configuration Debug -destination 'platform=macOS' build
```

3. Test:

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'
```

4. Open in Xcode and run `Clearance`.

## Notes

- CodeMirror assets are vendored under `Clearance/Resources/vendor/codemirror` and loaded locally.
- Autosave is currently debounce-based and writes directly to the source file.
- External file-change conflict handling is not yet implemented.
