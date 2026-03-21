# Privileged CLI Installer Design

**Date:** 2026-03-20
**Status:** Draft

## Problem

The Clearance app ships a `clearance` CLI tool and offers an "Install Command-Line
Tool" button in Settings. The installer creates a symlink at `/usr/local/bin/clearance`
pointing to the bundled helper binary. `/usr/local/bin` is owned by root, so the
installation fails with a permission error on any system where the user lacks write
access — which is most systems.

## Goal

When direct symlink creation fails due to a permission error, prompt the user for
their admin password and complete the installation with elevated privileges. The auth
dialog must appear inline (the native macOS "enter your password" sheet), not redirect
to System Settings.

## Approach

Authorization Services + a one-shot privileged helper binary (`ClearanceInstallHelper`).

The app calls `AuthorizationCreate` to obtain an authorization reference, then
`AuthorizationCopyRights` requesting `"system.privilege.admin"` to show the inline
auth dialog. On success, it calls `AuthorizationExecuteWithPrivileges` to spawn
`ClearanceInstallHelper` as root. The helper creates the symlink and exits. No daemon
is installed; nothing persists after the operation completes.

`AuthorizationExecuteWithPrivileges` is deprecated since macOS 10.7 but remains
available on macOS 14. Apple has not announced a replacement and it is the only
non-daemon mechanism for spawning a helper as root with an inline auth prompt.

## Components

### `ClearanceInstallHelper` (new)

A minimal Swift `tool` target, bundled at `Contents/Helpers/ClearanceInstallHelper`.

**Responsibilities:**
- Validate arguments (see Security below)
- Remove any existing symlink at the destination
- Create the symlink from destination to source
- Write nothing to stdout on success; write a single-line error message to stdout
  and exit non-zero on failure

**Arguments:** `ClearanceInstallHelper <source> <destination>`

- `source` — path to the `clearance` binary inside the app bundle
- `destination` — the symlink to create (must be `/usr/local/bin/clearance`)

The helper communicates success and failure over stdout because
`AuthorizationExecuteWithPrivileges` returns a `FILE*` connected to the helper's
stdout and does not return the child PID (making exit-code retrieval unreliable).
The protocol is simple: the helper writes nothing on success, or a single-line error
message on failure. The app reads from the pipe to EOF; a non-empty result signals
failure.

The helper has no framework dependencies beyond Foundation.

### `ClearanceCommandLineToolInstaller` (modified)

The existing installer already handles the case where `/usr/local/bin` is writable.
This change adds a privileged fallback triggered by a permission error.

**New flow:**
1. Attempt direct symlink creation (existing behaviour).
2. If a permission error is returned, proceed to the privileged code path.
3. Call `AuthorizationCreate` to obtain an `AuthorizationRef`.
4. Call `AuthorizationCopyRights` requesting `"system.privilege.admin"`. macOS
   shows the inline auth dialog.
5. If the user cancels (`errAuthorizationCanceled`), return without error — the
   user's intent is clear and showing an error would be misleading.
6. On success, call `AuthorizationExecuteWithPrivileges` with the full path to
   `ClearanceInstallHelper` and the source and destination paths as arguments.
7. Read from the returned `FILE*` pipe to EOF. An empty result means success; a
   non-empty result is the error message. Close the pipe with `fclose`.
8. If an error message was received, surface it in Settings.

### `SettingsView` (unchanged)

The existing UI already displays errors from the installer. No changes needed.

## Security

**Argument validation in the helper.** The helper validates both arguments before
acting:
- The destination must be exactly `/usr/local/bin/clearance`. Any other path is
  rejected, preventing a compromised caller from creating arbitrary symlinks as root.
- The source must be a readable file whose path both begins with `/Applications/`
  and ends with `Contents/Helpers/clearance`. Checking the suffix alone would allow
  path traversal (e.g. `/tmp/evil/Contents/Helpers/clearance`); checking the prefix
  constrains the source to the standard app installation location.

**App-side path construction.** The app constructs both paths from
`Bundle.main.bundleURL`, never from user input. There is no injection surface.
The helper's validation provides defence in depth.

**Hardened runtime.** `ClearanceInstallHelper` is built with
`ENABLE_HARDENED_RUNTIME = YES`. No additional entitlements are required for
`AuthorizationExecuteWithPrivileges` from a hardened binary. This prevents code
injection into the helper process while it runs as root.

**Code signing.** The helper is signed automatically alongside the app. Tampering
with the helper breaks the app bundle's signature, which Gatekeeper catches.

**No shell interpretation.** The helper uses `FileManager` directly to create the
symlink — no `NSTask`, no shell — eliminating shell expansion as an attack surface.

**Symlink atomicity.** Removing the existing symlink and creating the new one are
two separate operations; a crash between them would leave the destination absent.
The window is small and the consequence is recoverable (re-run the installer), so
this trade-off is acceptable.

## Error Handling

| Situation | Behaviour |
|---|---|
| User cancels auth dialog | Silent cancellation; button resets, no error shown |
| `AuthorizationCopyRights` fails (non-cancel) | Map `OSStatus` to a readable message; display in Settings |
| `AuthorizationExecuteWithPrivileges` fails | Map `OSStatus` to a readable message; display in Settings |
| Helper exits non-zero | Read stdout pipe contents; display in Settings |
| Helper binary missing | Fail fast before calling `AuthorizationExecuteWithPrivileges`; surface an internal error |

## Testing

**`ClearanceInstallHelper` (unit tests):**
- Rejects an invalid destination path
- Rejects a source path that does not end with `Contents/Helpers/clearance`
- Creates the symlink when arguments are valid (temp directory)
- Replaces an existing symlink at the destination
- Writes nothing on success; writes a single-line error message to stdout on failure

**`ClearanceCommandLineToolInstaller` (existing + new unit tests):**
- Existing tests cover the direct (non-privileged) path; these must continue to pass.
- New tests cover error mapping: `errAuthorizationCanceled` produces no error;
  a non-zero helper exit status produces an error with the pipe contents.

**The privileged path end-to-end** cannot be automated (it requires a real auth
dialog). A manual smoke test suffices: click "Install Command-Line Tool" in Settings
on a system where `/usr/local/bin` is not writable, enter the admin password, and
verify the symlink is created.

## Build Configuration

Add to `project.yml`:
- A new `ClearanceInstallHelper` tool target with `ENABLE_HARDENED_RUNTIME: YES`
  and `SWIFT_VERSION: 6.0`
- An embed + copy dependency from `Clearance` to `ClearanceInstallHelper`, placing
  it at `Contents/Helpers/ClearanceInstallHelper`
