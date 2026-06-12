# Private Mode Design

**Status:** Draft
**Date:** 2026-05-10
**Scope:** macOS app at `apps/macos/Clearance`

## Motivation

Clearance unconditionally records every opened file in the persistent recents history (`UserDefaults` key `"recentFiles"`, capped at 200 entries). There is no opt-out. The driving use case for this spec is opening many markdown files via the `clearance` command-line tool without polluting the long-lived recents list.

The user wants the choice to suspend history recording without losing the recents UI as a navigation surface in the current session.

## Goals

- An app-wide preference, persisted in `UserDefaults`, that suspends writes to the recents history.
- The sidebar continues to function as a navigation surface during a private session: files opened while private mode is on appear in the list for the current session only.
- Quitting and relaunching with private mode on restores the sidebar to exactly the persistent history that existed before the session, untouched.
- Visible signal in the UI when private mode is on, so it is never silently active.

## Non-Goals

- Per-window private state (Safari/Chrome-style private windows).
- A "Clear All History" action (deferred to a separate spec).
- A menu bar toggle, toolbar button, or in-window indicator beyond the sidebar header.
- Encryption, secure deletion, or any privacy guarantees beyond "do not write to `UserDefaults`".

## Behavior Summary

When Private Mode is **ON**:
- Files opened during the session appear in the sidebar normally, but are **not persisted to disk**.
- The persistent history on disk is left untouched. Quitting and relaunching restores the sidebar to exactly the state it was in before private mode was first toggled on, plus any non-private opens that happened between.
- The sidebar header reads `History (private mode)`.
- "Remove from History" still works on persisted entries.

When Private Mode is **OFF**: behavior is identical to today.

**Opening a file already in persisted history while private mode is on:** the file appears at the top of the sidebar with a "just opened" feel, but on disk its `lastOpenedAt` and ordering are unchanged. After quit and relaunch, the file appears exactly where it was before.

The setting persists across app launches.

## Architecture

### Data Model Changes

**`AppSettings` (new property):**
```swift
@Published var isPrivateMode: Bool {
    didSet { userDefaults.set(isPrivateMode, forKey: privateModeStorageKey) }
}
```
- Storage key: `"privateMode"` (Bool, defaults to `false`).
- Loaded in `AppSettings.init` alongside the other prefs.

**`RecentFilesStore` (new state):**
```swift
@Published private(set) var ephemeralEntries: [RecentFileEntry]  // session-only
var isPrivateMode: Bool                                            // set externally
```
- `entries` keeps its current meaning (the persisted list, source of truth on disk).
- `ephemeralEntries` is parallel in-memory state for files opened during private mode. Never encoded, never written to `UserDefaults`, lost on quit.
- `isPrivateMode` is a plain `Bool` set by the owner.

**Computed merged view for the UI:**
```swift
var displayEntries: [RecentFileEntry] {
    let ephemeralPaths = Set(ephemeralEntries.map(\.path))
    return ephemeralEntries + entries.filter { !ephemeralPaths.contains($0.path) }
}
```
Dedupes by `path`: an ephemeral open of a file that is also in persisted history shows once, at the top, with the ephemeral timestamp.

**`RecentFileEntry` is unchanged.** No new fields, no `Codable` changes, no on-disk format change, no migration.

### Add/Remove Logic

```swift
func add(url: URL) {
    let key = RecentFileEntry.storageKey(for: url)
    let entry = RecentFileEntry(path: key, lastOpenedAt: .now)

    if isPrivateMode {
        ephemeralEntries.removeAll { $0.path == key }
        ephemeralEntries.insert(entry, at: 0)
        if ephemeralEntries.count > maxEntries {
            ephemeralEntries = Array(ephemeralEntries.prefix(maxEntries))
        }
        return
    }

    entries.removeAll { $0.path == key }
    entries.insert(entry, at: 0)
    if entries.count > maxEntries {
        entries = Array(entries.prefix(maxEntries))
    }
    persist()
}
```

`add(urls:)` mirrors this branching: ephemeral path when `isPrivateMode`, persistent path otherwise. The `maxEntries` cap is applied independently to each list, so a flood of opens during private mode cannot evict persistent history.

`remove(path:)` removes from **both** lists. `persist()` is called only if `entries` actually changed.

**Toggling private mode does not mutate either list.** Flipping OFF mid-session leaves existing ephemeral entries visible until quit; subsequent opens go through the persistent path. Flipping back ON keeps persisted history visible while new opens become ephemeral.

### Wiring

Each `WorkspaceView` is a `@StateObject WorkspaceViewModel`, and each view model constructs its own `RecentFilesStore`. Multiple open windows therefore have independent `RecentFilesStore` instances reading the same shared `UserDefaults` (matches today's architecture). All windows do, however, share a single `AppSettings` instance owned by `ClearanceApp`.

> **Pre-existing limitation, out of scope here:** because each window's `RecentFilesStore` keeps an independent in-memory `entries` array and writes the entire array on every change without reloading from disk, multi-window use today can race — a write from window B can clobber an unobserved write from window A. This bug exists on `main` and is not introduced by private mode (during private mode `entries` is never mutated, so the racy surface area actually shrinks). Fixing it should be a separate spec — most likely "centralize `RecentFilesStore` as a single shared instance" — and is intentionally not bundled into this change.

In `WorkspaceViewModel.init`, subscribe to `appSettings.$isPrivateMode` with a Combine sink that assigns the value into `recentFilesStore.isPrivateMode` (and seed it once at init for the initial value). Every window's view model performs this wiring against the shared `AppSettings`, so toggling the setting updates every window's store. No protocol abstraction, no DI changes.

The four existing `recentFilesStore.add(...)` call sites (`WorkspaceViewModel.openLocal`, `openRemote`, `importFolderURLs`, and `WorkspaceView.popOutSession`) are unchanged. The guard lives entirely inside `RecentFilesStore`.

### UI Changes

**`SettingsView`** gains a new section between the Theme/Appearance section and the Command-Line Tool section, separated by `Divider()`s consistent with the existing pattern:

```
Toggle("Private Mode", isOn: $settings.isPrivateMode)
  When on, files you open are shown in the sidebar for the current session
  but are not saved to your history.
```

The caption uses `.font(.caption)` and `.foregroundStyle(.secondary)`, matching every other caption in `SettingsView`. Caption text exactly: *"When on, files you open are shown in the sidebar for the current session but are not saved to your history."*

**`RecentFilesSidebar`** takes a new `isPrivateMode: Bool` parameter. Its header label switches between `History` and `History (private mode)`. The `(private mode)` suffix uses `.foregroundStyle(.secondary)` so it reads as an annotation, not a badge. No other sidebar changes — context menus, drag-and-drop, selection, time bucketing all unchanged.

**Window title indicator.** Because the setting persists across launches, the user could otherwise relaunch and forget that recording is suspended. Each `WorkspaceView` adjusts its window title to read `Clearance (private mode)` when `isPrivateMode` is on, and `Clearance` (or whatever the active document title is, per existing behavior) when off. This is implemented by setting the `.navigationTitle(...)` / window title binding on `WorkspaceView` and applies uniformly to every window — including pop-outs — because they share `AppSettings`. The combination of sidebar-header annotation + window title suffix is the only in-window UI; no toolbar, no menu bar, no badge.

**`WorkspaceView`** passes `viewModel.appSettings.isPrivateMode` into the sidebar and passes `viewModel.recentFilesStore.displayEntries` (instead of `.entries`) as the entries source.

## Data Flow

**Opening a file with private mode OFF (unchanged from today):**
```
open path → WorkspaceViewModel.openLocal/openRemote/importFolderURLs
          → recentFilesStore.add(url:)
          → isPrivateMode == false branch
          → entries mutated; persist() writes JSON to UserDefaults
          → @Published entries fires
          → displayEntries recomputes
          → RecentFilesSidebar redraws
```

**Opening a file with private mode ON:**
```
open path → recentFilesStore.add(url:)
          → isPrivateMode == true branch
          → ephemeralEntries mutated; no persist()
          → @Published ephemeralEntries fires
          → displayEntries recomputes (dedups against persistent entries)
          → RecentFilesSidebar redraws
```

**Toggling Private Mode in Settings:**
```
SettingsView toggle → AppSettings.isPrivateMode setter
                    → didSet writes to UserDefaults
                    → @Published fires
                    → WorkspaceViewModel's Combine sink
                    → recentFilesStore.isPrivateMode = newValue
                    → RecentFilesSidebar header label updates
```

## Edge Cases

- **Private mode + folder import:** all imported files are ephemeral; none persist.
- **Private mode + popout window:** the new window's `WorkspaceViewModel` subscribes to the same shared `AppSettings`, so it inherits the current value of `isPrivateMode` and tracks subsequent changes. Each window has its own `ephemeralEntries`, so a private open in window A is not visible in window B's sidebar — consistent with how the persisted list already behaves across windows in memory today.
- **`maxEntries` cap:** applied independently to `entries` and `ephemeralEntries`. Worst case: the user has 200 persistent entries plus up to 200 ephemeral entries during a private session.
- **`remove(path:)` on an ephemeral entry:** drops it from `ephemeralEntries`. No disk activity needed but the in-memory removal is performed unconditionally so the API stays uniform.
- **Legacy migration:** `LegacyDefaultsMigration` is unaffected — it migrates `recentFiles` between bundle IDs. The new `privateMode` key has no legacy equivalent and defaults to `false` for migrated users.
- **Defaults absent / corrupted:** absence of `"privateMode"` key yields `false` (today's behavior). A non-Bool value at the key falls through to `false` via the standard `bool(forKey:)` semantics.
- **App launches with private mode on:** the user sees the persisted history they had before, with the `(private mode)` header. Any opens during this session remain ephemeral.

## Testing

### Unit Tests (`ClearanceTests/Models/RecentFilesStoreTests.swift`)

1. **Private add does not persist** — set `isPrivateMode = true`, call `add(url:)`, assert `entries` is unchanged AND `UserDefaults` data is unchanged. Construct a fresh `RecentFilesStore` against the same defaults and assert the file is absent.
2. **Private add appears in `displayEntries`** — same setup, assert `displayEntries.first?.path == newPath`.
3. **Ephemeral dedup with persisted entry** — seed `entries` with file Y, set private mode on, `add(Y)`. Assert `displayEntries` contains Y once at the top with the new timestamp, while `entries` still has Y at its original position with its original timestamp.
4. **Toggling private off mid-session preserves ephemeral entries** — add a private entry, flip `isPrivateMode = false`, assert `displayEntries` still includes it; then add a new (non-private) entry and assert `persist` writes only the non-ephemeral data.
5. **Toggling private on mid-session does not modify persisted entries** — seed entries, flip on, assert nothing changes on disk.
6. **`remove(path:)` works on ephemeral entries** — assert removal updates `displayEntries`; no disk write required.
7. **`add(urls:)` honors private mode** — batch import goes ephemeral when private mode is on.
8. **`maxEntries` cap applies to `ephemeralEntries`** — verify the cap is enforced on the ephemeral list independently.

### AppSettings Tests

Round-trip `isPrivateMode` through `UserDefaults`. Verify default is `false` when the key is absent.

### Manual Verification

- Toggle Private Mode ON; open a file via the file picker → appears in sidebar; header reads `History (private mode)`.
- Quit and relaunch → the file from the previous step is gone; sidebar matches the pre-private state.
- With Private Mode ON, drag a file from Finder into the window → ephemeral.
- With Private Mode ON, run `clearance some.md` from terminal → ephemeral.
- With Private Mode ON, "Open In New Window" from the sidebar → does not promote the entry's `lastOpenedAt` on disk.
- With persisted entries present, Private Mode ON, open one of them via sidebar → it jumps to the top in the current view; original on-disk entry untouched.
- Right-click an ephemeral entry → "Remove from History" hides it from the sidebar.
- Toggle Private Mode OFF mid-session → header label switches back to `History`; ephemeral entries remain visible until quit.

## Out of Scope

- **Clear All History** — useful and complementary, but a separate concern. Today the only way to remove entries is one at a time via the sidebar context menu.
- **Per-window private mode** — explicitly rejected in favor of the simpler app-wide model.
- **Menu bar toggle / toolbar button** — only the Settings pane surfaces the toggle.
- **Stronger privacy guarantees** — this feature prevents `UserDefaults` writes; it does not encrypt, secure-erase, or otherwise harden the existing data.
