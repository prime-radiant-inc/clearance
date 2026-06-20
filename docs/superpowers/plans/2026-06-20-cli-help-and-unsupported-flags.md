# CLI `--help` and Unsupported-Flag Handling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `clearance` CLI print usage for `--help` and warn on unsupported `--flags` instead of creating files named after them, while still opening valid files.

**Architecture:** Add a pure `parseArguments` function and a `helpText` string to the shared, unit-tested `ClearanceCommandLineTool` enum. Rewrite the untested `main.swift` glue to consume the parse result: help short-circuits to stdout, unsupported flags warn to stderr, flag-only invocations don't launch, and valid file paths flow into the existing `prepareDocumentURLs` + `open -a` path unchanged.

**Tech Stack:** Swift 6, Xcode 26 (`xcodebuild`), XCTest. Build/test from `apps/macos`.

---

## File Structure

- **Modify** `apps/macos/Clearance/Services/ClearanceCommandLineTool.swift` — add the `ParsedArguments` struct, `parseArguments(_:)`, and `helpText`. This file is compiled into both the `Clearance` app target and the `ClearanceCLI` tool target, so the CLI can call it.
- **Modify** `apps/macos/ClearanceCLI/main.swift` — consume `parseArguments`; add help and flag-only early exits before app resolution.
- **Modify** `apps/macos/ClearanceTests/Services/ClearanceCommandLineToolTests.swift` — add tests for `parseArguments` and `helpText`.

## Build & Test Commands

All run from `apps/macos`:

- Build app: `xcodebuild -project Clearance.xcodeproj -scheme Clearance -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
- Run a single test class: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceCommandLineToolTests CODE_SIGNING_ALLOWED=NO`
- Full suite: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

> Note on `xcodebuild test` filtering: `-only-testing` runs just that class but still compiles the whole app + test bundle, so a compile error anywhere fails the run. Expect ~30–90s per run.

---

## Task 1: Argument parser and help text on `ClearanceCommandLineTool`

**Files:**
- Modify: `apps/macos/Clearance/Services/ClearanceCommandLineTool.swift`
- Test: `apps/macos/ClearanceTests/Services/ClearanceCommandLineToolTests.swift`

- [ ] **Step 1: Write the failing tests**

Append these tests inside the `ClearanceCommandLineToolTests` class (before the closing `}` and the `private` helpers), in `apps/macos/ClearanceTests/Services/ClearanceCommandLineToolTests.swift`:

```swift
    func testParseArgumentsTreatsPlainPathsAsFiles() {
        let parsed = ClearanceCommandLineTool.parseArguments(["a.md", "b.md"])

        XCTAssertFalse(parsed.helpRequested)
        XCTAssertEqual(parsed.unsupportedFlags, [])
        XCTAssertEqual(parsed.filePaths, ["a.md", "b.md"])
    }

    func testParseArgumentsDetectsHelpFlag() {
        let parsed = ClearanceCommandLineTool.parseArguments(["--help"])

        XCTAssertTrue(parsed.helpRequested)
        XCTAssertEqual(parsed.unsupportedFlags, [])
        XCTAssertEqual(parsed.filePaths, [])
    }

    func testParseArgumentsHelpFlagIsDetectedAlongsideFiles() {
        let parsed = ClearanceCommandLineTool.parseArguments(["--help", "notes.md"])

        XCTAssertTrue(parsed.helpRequested)
        XCTAssertEqual(parsed.filePaths, ["notes.md"])
    }

    func testParseArgumentsCollectsUnsupportedFlagsWithoutCreatingFiles() {
        let parsed = ClearanceCommandLineTool.parseArguments(["--foo", "notes.md"])

        XCTAssertFalse(parsed.helpRequested)
        XCTAssertEqual(parsed.unsupportedFlags, ["--foo"])
        XCTAssertEqual(parsed.filePaths, ["notes.md"])
    }

    func testParseArgumentsFlagOnlyInvocationHasNoFilePaths() {
        let parsed = ClearanceCommandLineTool.parseArguments(["--bogus"])

        XCTAssertFalse(parsed.helpRequested)
        XCTAssertEqual(parsed.unsupportedFlags, ["--bogus"])
        XCTAssertEqual(parsed.filePaths, [])
    }

    func testParseArgumentsSeparatorTreatsFollowingArgumentsAsFiles() {
        let parsed = ClearanceCommandLineTool.parseArguments(["--", "--weird-name.md"])

        XCTAssertFalse(parsed.helpRequested)
        XCTAssertEqual(parsed.unsupportedFlags, [])
        XCTAssertEqual(parsed.filePaths, ["--weird-name.md"])
    }

    func testParseArgumentsHelpAfterSeparatorIsAFilePath() {
        let parsed = ClearanceCommandLineTool.parseArguments(["--", "--help"])

        XCTAssertFalse(parsed.helpRequested)
        XCTAssertEqual(parsed.filePaths, ["--help"])
    }

    func testParseArgumentsEmptyInputYieldsEmptyResult() {
        let parsed = ClearanceCommandLineTool.parseArguments([])

        XCTAssertFalse(parsed.helpRequested)
        XCTAssertEqual(parsed.unsupportedFlags, [])
        XCTAssertEqual(parsed.filePaths, [])
    }

    func testParseArgumentsLoneSeparatorYieldsEmptyResult() {
        let parsed = ClearanceCommandLineTool.parseArguments(["--"])

        XCTAssertFalse(parsed.helpRequested)
        XCTAssertEqual(parsed.unsupportedFlags, [])
        XCTAssertEqual(parsed.filePaths, [])
    }

    func testParseArgumentsSingleDashIsAFilePath() {
        let parsed = ClearanceCommandLineTool.parseArguments(["-"])

        XCTAssertFalse(parsed.helpRequested)
        XCTAssertEqual(parsed.unsupportedFlags, [])
        XCTAssertEqual(parsed.filePaths, ["-"])
    }

    func testParseArgumentsDuplicateFlagsArePreservedInOrder() {
        let parsed = ClearanceCommandLineTool.parseArguments(["--foo", "--foo"])

        XCTAssertEqual(parsed.unsupportedFlags, ["--foo", "--foo"])
        XCTAssertEqual(parsed.filePaths, [])
    }

    func testParseArgumentsOnlyFirstSeparatorIsHonored() {
        let parsed = ClearanceCommandLineTool.parseArguments(["--", "a", "--", "b"])

        XCTAssertFalse(parsed.helpRequested)
        XCTAssertEqual(parsed.unsupportedFlags, [])
        XCTAssertEqual(parsed.filePaths, ["a", "--", "b"])
    }

    func testParseArgumentsFlagThenSeparatorHasFlagButNoFiles() {
        let parsed = ClearanceCommandLineTool.parseArguments(["--foo", "--"])

        XCTAssertFalse(parsed.helpRequested)
        XCTAssertEqual(parsed.unsupportedFlags, ["--foo"])
        XCTAssertEqual(parsed.filePaths, [])
    }

    func testHelpTextDescribesUsage() {
        XCTAssertTrue(ClearanceCommandLineTool.helpText.contains("usage:"))
        XCTAssertTrue(ClearanceCommandLineTool.helpText.contains("--help"))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceCommandLineToolTests CODE_SIGNING_ALLOWED=NO`
Expected: FAIL — compile error, `parseArguments`/`helpText`/`ParsedArguments` are undefined.

- [ ] **Step 3: Implement `ParsedArguments`, `parseArguments`, and `helpText`**

In `apps/macos/Clearance/Services/ClearanceCommandLineTool.swift`, add these members inside the `enum ClearanceCommandLineTool` body. Place them right after the existing `static let appBundleIdentifier = "com.primeradiant.Clearance"` line:

```swift
    struct ParsedArguments: Equatable {
        var helpRequested: Bool = false
        var unsupportedFlags: [String] = []
        var filePaths: [String] = []
    }

    static let helpText = """
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
        """

    static func parseArguments(_ arguments: [String]) -> ParsedArguments {
        var parsed = ParsedArguments()
        var separatorSeen = false

        for argument in arguments {
            if separatorSeen {
                parsed.filePaths.append(argument)
                continue
            }

            switch argument {
            case "--":
                separatorSeen = true
            case "--help":
                parsed.helpRequested = true
            default:
                if argument.hasPrefix("--") {
                    parsed.unsupportedFlags.append(argument)
                } else {
                    parsed.filePaths.append(argument)
                }
            }
        }

        return parsed
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceCommandLineToolTests CODE_SIGNING_ALLOWED=NO`
Expected: PASS — all `ClearanceCommandLineToolTests` tests green, including the pre-existing ones.

- [ ] **Step 5: Commit**

```bash
git add apps/macos/Clearance/Services/ClearanceCommandLineTool.swift apps/macos/ClearanceTests/Services/ClearanceCommandLineToolTests.swift
git commit -m "feat: parse CLI arguments for --help and unsupported flags"
```

---

## Task 2: Wire `main.swift` to the parser

**Files:**
- Modify: `apps/macos/ClearanceCLI/main.swift`

There is no unit test for `main.swift` (it is in neither test target — it is process-launch glue). Verification is a manual run of the built helper, defined in Step 4. The parsing logic it depends on is already covered by Task 1.

- [ ] **Step 1: Rewrite `main.swift` control flow**

Replace the entire body of `apps/macos/ClearanceCLI/main.swift` with the following. Key ordering: parse first, then handle `--help` and the flag-only case **before** resolving the app bundle, so help works even when the app cannot be located.

```swift
import Foundation

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("\(ClearanceCommandLineTool.name): \(error.localizedDescription)\n".utf8))
    exit(1)
}

private func run() throws {
    let parsed = ClearanceCommandLineTool.parseArguments(
        Array(CommandLine.arguments.dropFirst())
    )

    if parsed.helpRequested {
        print(ClearanceCommandLineTool.helpText)
        exit(0)
    }

    for flag in parsed.unsupportedFlags {
        FileHandle.standardError.write(
            Data("\(ClearanceCommandLineTool.name): unsupported flag: \(flag)\n".utf8)
        )
    }

    // Flag-only invocation (no files): warn but do not launch the app.
    if parsed.filePaths.isEmpty && !parsed.unsupportedFlags.isEmpty {
        exit(0)
    }

    guard let helperExecutableURL = Bundle.main.executableURL,
          let appURL = ClearanceCommandLineTool.appURL(forExecutableURL: helperExecutableURL) else {
        throw CommandError.appBundleNotFound
    }

    let documentURLs = try ClearanceCommandLineTool.prepareDocumentURLs(
        forArguments: parsed.filePaths
    )

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", appURL.path] + documentURLs.map(\.path)
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw CommandError.openFailed(process.terminationStatus)
    }
}

private enum CommandError: LocalizedError {
    case appBundleNotFound
    case openFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .appBundleNotFound:
            return "Could not locate \(ClearanceCommandLineTool.appBundleIdentifier)."
        case .openFailed(let status):
            return "`open` exited with status \(status)."
        }
    }
}
```

- [ ] **Step 2: Build the app (which builds the embedded CLI helper)**

Run: `xcodebuild -project Clearance.xcodeproj -scheme Clearance -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Locate the built helper**

The helper is at `<BUILT_PRODUCTS_DIR>/Clearance.app/Contents/Helpers/clearance`.
Extract `BUILT_PRODUCTS_DIR` space-safely (anchor the line, split on ` = `, stop
at the first match) and guard that the helper exists and is executable:

```bash
BPD="$(xcodebuild -project Clearance.xcodeproj -scheme Clearance -configuration Debug -destination 'platform=macOS' -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR =/{print $2; exit}')"
HELPER="$BPD/Clearance.app/Contents/Helpers/clearance"
[ -x "$HELPER" ] && echo "helper OK: $HELPER" || { echo "MISSING helper at: $HELPER"; }
```
Expected: `helper OK: …/Clearance.app/Contents/Helpers/clearance`.

- [ ] **Step 4: Manually verify the four behaviors**

> These open the GUI Clearance.app, so run them on a logged-in macOS desktop
> session (not headless/SSH), or `open` will fail and report a spurious exit 1.

```bash
# 1. Help prints usage to stdout and exits 0; opens nothing.
"$HELPER" --help; echo "exit=$?"
# Expected: usage text printed, exit=0.

# 2. Unsupported flag warns on stderr; flag-only => no launch, exit 0.
"$HELPER" --bogus; echo "exit=$?"
# Expected: "clearance: unsupported flag: --bogus" on stderr, app does NOT launch, exit=0.

# 3. Unsupported flag + valid file: warns, still opens the file, exit 0.
TMP="$(mktemp -d)/note.md"; "$HELPER" --bogus "$TMP"; echo "exit=$?"
# Expected: warning on stderr, Clearance opens with the new note.md, exit=0. File created at $TMP.

# 4. `--` separator opens a dash-named file literally (no warning).
DASHDIR="$(mktemp -d)"; ( cd "$DASHDIR" && "$HELPER" -- --weird-name.md ); echo "exit=$?"
# Expected: no warning, Clearance opens, file "--weird-name.md" created in $DASHDIR, exit=0.
ls -1 "$DASHDIR"
```

Confirm each `exit=` and the described side effects. (The dev helper opens the **dev** Clearance.app because the enclosing bundle wins over the Launch Services bundle-id lookup.)

- [ ] **Step 5: Commit**

```bash
git add apps/macos/ClearanceCLI/main.swift
git commit -m "feat: honor --help and unsupported flags in clearance CLI"
```

---

## Task 3: Full regression run

**Files:** none (verification only).

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
Expected: `** TEST SUCCEEDED **`, zero failures. Confirms the new parser and `main.swift` changes did not regress existing `prepareDocumentURLs` / installer / app tests.

- [ ] **Step 2: Confirm clean tree**

Run: `git status --short`
Expected: empty output (all changes committed across Tasks 1–2).
