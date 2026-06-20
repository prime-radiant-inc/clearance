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
| `--` (exactly two dashes, first one)     | Separator: every argument **after** it is a file path           |
| `--anything-else` (before any `--`)      | Unsupported flag — collected, never becomes a file              |
| Anything not starting with `--`          | File path                                                       |
| Anything (incl. `--foo`) **after** `--`  | File path (literal)                                             |

**Parsing-contract details (so the implementation is unambiguous):**

- The separator is matched by **exact equality** to `--`. `---` (three dashes)
  is not the separator — it starts with `--` and isn't `--help`, so it is an
  **unsupported flag**. A single `-` does not start with `--`, so it is a
  **file path** (consistent with the non-goal of leaving single-dash args
  alone).
- Parsing is a single left-to-right pass that **always populates all three
  fields** regardless of what else is present. `helpRequested` does **not**
  blank out `filePaths`/`unsupportedFlags`; e.g. `parseArguments(["--help",
  "notes.md"])` returns `helpRequested == true` **and** `filePaths ==
  ["notes.md"]`. The short-circuit that ignores those file paths happens later,
  in `main.swift` (step 1 below), not in the parser.
- Unsupported flags are collected **in argument order and not de-duplicated**:
  `--foo --foo` yields `["--foo", "--foo"]` and produces two warnings. This
  keeps the parser a trivial, order-preserving pass.
- Only the **first** `--` is the separator; a later `--` after the separator is
  just a file path (so `-- a -- b` yields file paths `["a", "--", "b"]`).

### Resolution order in `main.swift`

These steps run **in order, and the help and flag-only exits occur *before* the
app bundle is located.** Locating the app can fail (`appBundleNotFound`); `--help`
must still print and exit 0 on a broken/uninstalled app, so bundle resolution
must not run for the help or flag-only paths.

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
clearly intended a flag. The condition takes precedence over the `--`
separator: `clearance --foo --` has an unsupported flag and no files, so it
warns and does **not** launch — an erroneous flag with nothing to open is
treated as an error case regardless of a trailing `--`. (Plain `clearance --`,
with no flags, still launches bare.)

**Exit codes are exit 0 for every non-launch-failure case**, including the
flag-only warn-and-don't-launch path. This is a deliberate, user-chosen
behavior (lenient: a warning is emitted but the process still reports success);
the only non-zero exit is the pre-existing `open` failure (exit 1).

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

1. `--help` alone → `helpRequested == true`, `filePaths == []`,
   `unsupportedFlags == []`.
2. `--help notes.md` → `helpRequested == true` **and** `filePaths ==
   ["notes.md"]` (the parser still collects the path; `main` short-circuits on
   help). Asserting `filePaths` here pins the contract rather than leaving it
   vacuous.
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
9. Empty input (`[]`) → all three fields empty/false (the bare-`clearance`
   launch path).
10. Lone `--` (`["--"]`) → all empty (separator with nothing after; bare
    launch).
11. Single `-` (`["-"]`) → `filePaths == ["-"]` (single-dash stays a file path,
    per non-goals).
12. Duplicate flags (`["--foo", "--foo"]`) → `unsupportedFlags == ["--foo",
    "--foo"]` (order preserved, not de-duplicated).
13. Multiple `--` (`["--", "a", "--", "b"]`) → `filePaths == ["a", "--", "b"]`
    (only the first `--` is the separator).
14. `helpText` is non-empty and contains both `usage:` and `--help` (cheap
    regression guard on the message).

The existing `prepareDocumentURLs` tests remain valid and unchanged, since that
function's contract is untouched — it just receives pre-filtered paths.

## Out of Scope / Future

- UI changes to the main SwiftUI app are tracked separately (their own
  brainstorm → spec → worktree → PR cycle).
```
