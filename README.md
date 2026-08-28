[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) ![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white) ![Platform: Linux x86_64](https://img.shields.io/badge/platform-Linux%20x86__64-blue) [![Last commit](https://img.shields.io/github/last-commit/Pat9496/install-md-viewer)](https://github.com/Pat9496/install-md-viewer/commits/main)

# install-md-viewer

Installer and updater for [md-viewer](https://github.com/aydiler/md-viewer), a Markdown viewer for Linux.

[Deutsche Version](README.de.md)

## Contents

- [About](#about)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Optional integrations](#optional-integrations)
- [Environment variables](#environment-variables)
- [License](#license)
- [Credits](#credits)

## About

`install-md-viewer` is a Bash script that downloads, verifies, and installs [md-viewer](https://github.com/aydiler/md-viewer) on Linux x86_64 systems. It handles binary installation, license files, and optional integrations with desktop environments, topgrade, and chezmoi.

This repository contains the installer script only — not md-viewer itself.

## Features

- Downloads the latest md-viewer release from GitHub
- Verifies binary integrity via sha256 checksum
- Installs to `~/.local/bin/md-viewer` with license files
- Tracks installed version to skip reinstall if already current
- Installs Noto Sans and DejaVu fallback fonts to `~/.local/share/fonts/md-viewer/` for special and non-Latin character support
- Optionally registers md-viewer as the default handler for Markdown files (with `xdg-mime`) — asks interactively, or set via `--set-default`/`--no-default`
- Optional topgrade integration for automated updates
- Optional chezmoi integration to manage topgrade configuration
- Respects XDG Base Directory specification

## Requirements

**System:**
- Linux x86_64
- Bash

**Runtime dependencies:**
- curl
- grep, head, sed
- tar
- install, mktemp
- sha256sum

**Optional tools:**
- `xdg-mime` and `update-desktop-database` — for desktop integration
- `topgrade` — to use topgrade integration
- `chezmoi` — to use chezmoi integration

## Installation

Clone this repository and run the installer:

```bash
git clone https://github.com/Pat9496/install-md-viewer.git
cd install-md-viewer
bash install-md-viewer.sh
```

The script will install md-viewer to `~/.local/bin/md-viewer`. Ensure `~/.local/bin` is in your `$PATH`.

## Usage

### Full installation

Run the script with no argument or with `install`:

```bash
bash install-md-viewer.sh
# or
bash install-md-viewer.sh install
```

This performs:
1. Downloads and installs the md-viewer binary
2. Installs LICENSE and THIRD_PARTY_NOTICES to `~/.local/share/licenses/md-viewer/`
3. Installs fallback fonts (Noto Sans and DejaVu) to `~/.local/share/fonts/md-viewer/`
4. Sets up desktop integration (installs the `.desktop` file, and decides whether to register md-viewer as the default handler for Markdown files — see below)
5. Sets up topgrade integration (if topgrade is installed)
6. Sets up chezmoi integration (if chezmoi is initialized)

By default, whether md-viewer becomes the default Markdown handler is decided interactively: if run from a terminal, the script asks `[Y/n]`. To skip the prompt, pass one of:

```bash
bash install-md-viewer.sh --set-default   # register as the default handler, no prompt
bash install-md-viewer.sh --no-default    # do not register as the default handler, no prompt
```

These flags are only valid with `install` (the default mode) and cannot be combined with `--update`. If the script is run non-interactively (no terminal attached) with neither flag given, it does not change the default handler.

### Update only

Run with `--update` to download and install a newer version without modifying integrations:

```bash
bash install-md-viewer.sh --update
```

This is useful for updating md-viewer without re-running desktop and integration setup.

## Optional integrations

### Fallback fonts

The script automatically downloads and installs fallback fonts for special and non-Latin character support:
- **Noto Sans** (variable-font TTF from Google Fonts)
- **DejaVu fonts** (full font family from the official DejaVu Fonts release)

Both are installed to `~/.local/share/fonts/md-viewer/` (respecting `XDG_DATA_HOME`). The font cache is refreshed if `fc-cache` is available.

If both fonts are already installed, the step is skipped. If font download fails, a warning is printed to stderr and the installation continues — the fallback fonts improve character coverage but are not required for md-viewer to function.

This step runs only during full installation (`install` mode), not during `--update`.

### Desktop integration

The script always installs a `.desktop` file to `~/.local/share/applications/md-viewer.desktop` and refreshes the desktop database if `update-desktop-database` is available.

If `xdg-mime` is available, the script additionally decides whether to register md-viewer as the default handler for `text/markdown` and `text/x-markdown` MIME types, following the precedence described in [Usage](#usage): an explicit `--set-default`/`--no-default` flag wins; otherwise, in an interactive terminal, it asks; otherwise it leaves the default handler unchanged. If `xdg-mime` is not available at all, MIME type registration is skipped entirely.

### Topgrade integration

If `topgrade` is installed, the script creates a custom command configuration at `~/.config/topgrade.d/md-viewer.toml`. This allows `topgrade` to automatically update md-viewer alongside other system packages.

The script performs a dry-run test of the topgrade configuration if topgrade is available.

### Chezmoi integration

If `chezmoi` is initialized (has a source directory with content), the script adds the topgrade configuration file to chezmoi management. This allows chezmoi to track and sync the topgrade configuration across machines.

If chezmoi is not installed or not initialized, this step is skipped.

## Environment variables

- `XDG_DATA_HOME` — Directory for application data files (default: `~/.local/share`)
- `XDG_CONFIG_HOME` — Directory for configuration files (default: `~/.config`)
- `MD_VIEWER_ALLOW_ROOT` — Set to `1` to allow running the script as root (default: `0`, script refuses root unless this is set)

## License

MIT License — see [LICENSE](LICENSE) file.

## Credits

- [md-viewer](https://github.com/aydiler/md-viewer) — the Markdown viewer that this script installs.
- [topgrade](https://github.com/topgrade-rs/topgrade) — for optional automated update integration.
- [chezmoi](https://github.com/twpayne/chezmoi) — for optional configuration management integration.
- Installer script maintained by [Pat9496](https://github.com/Pat9496).
