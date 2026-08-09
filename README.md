![Multigravity](assets/multigravity-logo.jpg)

# Multigravity

**Run multiple Antigravity IDE profiles simultaneously — each with its own accounts, extensions, and settings.**

No more logging in and out. Launch as many profiles as you need, all at once.

[![GitHub repository](https://img.shields.io/badge/GitHub-Repository-blue?logo=github)](https://github.com/sujitagarwal/multigravity-cli)
[![GitHub profile](https://img.shields.io/badge/GitHub-Profile-lightgrey?logo=github)](https://github.com/sujitagarwal)
[![GitHub stars](https://img.shields.io/github/stars/sujitagarwal/multigravity-cli?style=social)](https://github.com/sujitagarwal/multigravity-cli/stargazers)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)](#install)

---

## Install

**macOS / Linux**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sujitagarwal/multigravity-cli/main/install.sh)"
```

Or install from a local git clone (with auto-updating symlinks):

```bash
./install.sh --link
```

**Windows** — open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/sujitagarwal/multigravity-cli/main/install.ps1 | iex
```

---

## Quick Start

> **Note**: Both `multigravity` and `mgy` commands are supported!

```bash
# Create profiles
mgy new work          # (or: multigravity new work)
mgy new personal

# Launch a profile
mgy work

# Pass arguments straight through to Antigravity
mgy work .
mgy work path/to/project
mgy work --new-window
```

Each profile gets an automatic clickable launcher:

| Platform | Location |
|----------|----------|
| macOS    | `~/Applications/Multigravity <name>.app` |
| Windows  | Start Menu → Programs |
| Linux    | `~/.local/share/applications/multigravity-<name>.desktop` |

---

## Commands

### Profile Management

| Command | Description |
|---------|-------------|
| `multigravity new` | Launch interactive profile creation wizard |
| `multigravity new <name>` | Create a new full profile |
| `multigravity new <name> --shared` | Create a lightweight profile (shared extensions & settings, isolated accounts) |
| `multigravity new <name> --from <template>` | Create a profile from a saved template |
| `multigravity new <name> --from default` | Create a profile seeded from your default logged-in session |
| `multigravity <name>` | Launch a profile |
| `multigravity list` | List all profiles |
| `multigravity status` | Show running state, type, last used, and size per profile |
| `multigravity quota [name]` | Show model quota & remaining limits with visual progress bars |
| `multigravity clone <src> <dest>` | Copy an existing profile |
| `multigravity rename <old> <new>` | Rename a profile |
| `multigravity delete <name>` | Delete a profile and all its data |

### Templates

| Command | Description |
|---------|-------------|
| `multigravity template save <profile> <name>` | Save a profile as a reusable template |
| `multigravity template list` | List saved templates |
| `multigravity template delete <name>` | Remove a template |

### Backup & Transfer

| Command | Description |
|---------|-------------|
| `multigravity export <name> [path]` | Archive a profile to `.tar.gz` (`.zip` on Windows) |
| `multigravity import <archive> [name]` | Restore a profile from an archive |

### Utilities

| Command | Description |
|---------|-------------|
| `multigravity stats` | Show disk usage per profile |
| `multigravity doctor` | Diagnose your environment |
| `multigravity update` | Update Multigravity to the latest version |
| `multigravity completion` | Show shell tab-completion setup |
| `multigravity completion install` | Automatically install shell autocompletion |
| `multigravity help` | Show help |

---

## Shared Profiles

Full profiles are fully isolated — separate extensions, settings, and accounts. That's the default.

**Shared profiles** go lighter: they symlink extensions and settings from your main Antigravity install, isolating only the account/auth layer. Useful when you need a second account but don't want to duplicate gigabytes of extensions.

```bash
multigravity new client-x --shared
```

---

## Templates

Save a configured profile as a template, then spin up new profiles from it instantly:

```bash
# Save your ideal setup as a template
multigravity template save work base

# Create new profiles from it
multigravity new project-a --from base
multigravity new project-b --from base

# See what templates you have
multigravity template list
```

---

## Shell Completion

Enable tab-completion for commands and profile names:

```bash
multigravity completion
```

Follow the instructions to add it to your `.zshrc`, `.bashrc`, or PowerShell `$PROFILE`.

---

## Uninstall

**macOS / Linux**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sujitagarwal/multigravity-cli/main/uninstall.sh)"
```

**Windows**

```powershell
irm https://raw.githubusercontent.com/sujitagarwal/multigravity-cli/main/uninstall.ps1 | iex
```

You'll be asked whether to remove your profile data — nothing is deleted without confirmation.

---

## Profile Name Rules

Letters, numbers, and hyphens only. Must start with a letter or number.

```
✅  work   client-a   test1
❌  -name  my_profile
```

---

## Credits

- **Windows support** — [Samin Yeasar](https://github.com/Solez-ai)
- **Linux support** — [Md Rayyan Nawaz](https://github.com/therayyanawaz)
