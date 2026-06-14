---
title: Command-Line Tool
order: 10
---

# Command-Line Tool

Clearance can install a `clearance` command you run in the Terminal to open files in the app. Pass it one or more paths:

```
clearance notes.md
```

Clearance opens each file you name. If a path doesn't exist yet, Clearance creates a new Markdown file there first, then opens it.

## Installing it

From **Clearance** > **Settings…**, choose an install location and click the install button. There are two choices:

- `/usr/local/bin` — installs through the bundled installer package, which opens in the Installer app. This location may require administrator access.
- `~/.local/bin` — installs to your home folder without administrator access. Make sure `~/.local/bin` is on your shell's `PATH` so the `clearance` command is found.

You'll find this in [Settings](09-settings.md).
