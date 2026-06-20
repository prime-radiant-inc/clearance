# CLI `--help` and Unsupported-Flag Handling — Design

## Problem

The `clearance` command-line helper passes every argument straight to
`ClearanceCommandLineTool.prepareDocumentURLs`, which treats each argument as a
file path and **creates a new Markdown file for any path that doesn't exist**.

As a result:

- `clearance --help` creates a file literally named `--help` and opens it,
  instead of printing usage.
- Any mistyped or unsupported `--flag` is silently turned into a new file.

## Goals

1. Add a `--help` flag that prints usage to stdout and exits 0 without opening
   or creating anything.
2. Treat any unrecognized `--`-prefixed argument as an unsupported flag: warn on
   stderr and never turn it into a file.
3. Still open the valid files in the same invocation (lenient handling).
4. Honor the POSIX `--` separator so files whose names begin with dashes can
   still be opened.

## Non-Goals

- Single-dash arguments (`-x`, `-`) are **not** in scope. They keep today's
  behavior (treated as file paths). Only `--`-prefixed arguments are flags.
- No `-h` alias and no `--version` flag — only `--help`.
- No new argument-parsing dependency (e.g. swift-argument-parser).

## Behavior Specification

Given the arguments after the executable name (`CommandLine.arguments.dropFirst()`):

| Argument pattern                         | Treatment                                                        |
| ---------------------------------------- | --------------------------------------------------------------- |
| `--help`                                 | Sets "help requested"                                           |
| `--` (first literal occurrence)          | Separator: every argument **after** it is a file path           |
| `--anything-else` (before any `--`)      | Unsupported flag — collected, never becomes a file              |
| Anything not starting with `--`          | File path                                                       |
| Anything (incl. `--foo`) **after** `--`  | File path (literal)                                             |

### Resolution order in `main.swift`

1. **Help wins and short-circuits.** If "help requested" is set, print the help
   text to **stdout** and `exit(0)`. No files are opened or created, even if
   valid file arguments are present (`clearance --help notes.md` just prints
   help).
2. **Warn about unsupported flags.** For each collected unsupported flag, write
   `clearance: unsupported flag: <flag>` to **stderr**.
3. **Suppress flag-only launch.** If `filePaths` is empty **and** at least one
   unsupported flag was present (e.g. `clearance --bogus`), do **not** launch the
   app — only the warning(s) from step 2 are emitted. `exit(0)`.
4. **Open / launch.** Otherwise call the existing `prepareDocumentURLs` with
   `filePaths` and `open -a` the app. When `filePaths` is non-empty those files
   open; when it is empty (bare `clearance`, or `clearance --`) the app launches
   with no document — preserving today's behavior.
5. **Exit 0** in all non-help, non-error cases — including when unsupported
   flags were warned about but valid files opened successfully. A genuine
   failure to launch (`open` non-zero) still exits 1 as today.

The launch-suppression condition is precisely `filePaths.isEmpty &&
!unsupportedFlags.isEmpty`. This preserves the bare-`clearance` launch (no
flags, no files) while suppressing the surprising empty launch when the user
clearly intended a flag.

### Help text

Printed to stdout, exit 0:

```
clearance — open Markdown files in the Clearance app

usage: clearance [options] [files...]

options:
  --help    Show this help and exit
  --        Treat all following arguments as file paths

Files that don't exist yet are created as new Markdown documents.

examples:
  clearance notes.md
  clearance README.md CHANGELOG.md
  clearance -- --weird-name.md
```

## Architecture

All parsing logic goes into the shared, already-unit-tested
`ClearanceCommandLineTool` enum
(`apps/macos/Clearance/Services/ClearanceCommandLineTool.swift`). That file is
compiled into both the `Clearance` app target and the `ClearanceCLI` tool
target, and is exercised by `ClearanceCommandLineToolTests`. Keeping logic there
(rather than in `main.swift`, which is in neither test target) makes it
testable.

### New API on `ClearanceCommandLineTool`

```swift
struct ParsedArguments: Equatable {
    var helpRequested: Bool
    var unsupportedFlags: [String]
    var filePaths: [String]
}

static func parseArguments(_ arguments: [String]) -> ParsedArguments

static let helpText: String
```

`parseArguments` is a pure function: no I/O, no filesystem, no process launch. It
fully determines control flow from the argument list alone.

### `main.swift` changes

`main.swift` (in `ClearanceCLI`, untested glue) becomes:

1. `let parsed = ClearanceCommandLineTool.parseArguments(Array(CommandLine.arguments.dropFirst()))`
2. If `parsed.helpRequested`: print `helpText` to stdout, `exit(0)`.
3. For each flag in `parsed.unsupportedFlags`: write
   `\(name): unsupported flag: \(flag)\n` to stderr.
4. If `parsed.filePaths.isEmpty && !parsed.unsupportedFlags.isEmpty`: `exit(0)`
   (flag-only invocation, no launch).
5. Otherwise resolve the helper/app URLs, call
   `prepareDocumentURLs(forArguments: parsed.filePaths)`, and `open -a` as today
   (with an empty `filePaths` this launches the app with no document, as before).

The existing app-bundle-resolution and `open` logic is unchanged; only the input
to `prepareDocumentURLs` is now the filtered `filePaths`, and two early exits are
added (help, empty-after-flags).

## Testing

Add to `ClearanceTests/Services/ClearanceCommandLineToolTests.swift` (TDD — write
failing tests first):

1. `--help` anywhere sets `helpRequested` and yields no file paths/flags.
2. `--help notes.md` sets `helpRequested` (help short-circuits; file paths may
   still be collected but are irrelevant because main exits early).
3. An unsupported flag (`--foo`) lands in `unsupportedFlags`, not `filePaths`.
4. `--foo notes.md` → `unsupportedFlags == ["--foo"]`, `filePaths == ["notes.md"]`.
5. `--bogus` alone → `unsupportedFlags == ["--bogus"]`, `filePaths == []`,
   `helpRequested == false` (drives the no-launch path).
6. `--` separator: `-- --weird-name.md` → `filePaths == ["--weird-name.md"]`,
   no unsupported flags, no help.
7. `--help` appearing **after** `--` is a file path, not help
   (`-- --help` → `filePaths == ["--help"]`).
8. Plain paths with no flags are unchanged (`a.md b.md` → `filePaths` both, no
   flags/help) — guards the existing happy path.
9. `helpText` is non-empty and contains `usage:` (cheap regression guard on the
   message).

The existing `prepareDocumentURLs` tests remain valid and unchanged, since that
function's contract is untouched — it just receives pre-filtered paths.

## Out of Scope / Future

- UI changes to the main SwiftUI app are tracked separately (their own
  brainstorm → spec → worktree → PR cycle).
```
