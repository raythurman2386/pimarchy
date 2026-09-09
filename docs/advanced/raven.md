# Raven AI Agent

Pimarchy includes built-in support for the **Raven AI agent**. Raven is a small, privacy-first coding-agent harness written in Rust for Ollama and any OpenAI-compatible endpoint. It runs a full agent loop — tools, plan mode, verification, and workspace isolation — against a model endpoint you control.

Raven is the **pre-selected default coding agent** (`pimarchy default agent raven`) and installs as part of the core module. Pimarchy also installs **Ollama** by default as Raven's local inference backend; Raven talks to Ollama at `http://localhost:11434/v1`.

## Launching Raven

Omarchy-style, from anywhere:

```bash
# From the keybind: SUPER + SHIFT + CTRL + A
# Opens Foot with app-id org.pimarchy.agent (floating 900×600)
pimarchy agent

# With a prompt
pimarchy agent "fix the failing test in lib/upgrade.sh"

# In the current terminal (also the `a` alias)
pimarchy agent --inline
```

`pimarchy agent` runs `raven --yolo` (skipping confirmations), passing any arguments as the prompt via `-p`. Keybind/menu launches that start in `$HOME` `cd` into `~/Work` when that directory exists, so the agent can remember workspace trust. If the binary is missing, it points you at `pimarchy default agent raven`, which lazy-installs it via the official script.

## Installation Details

Raven is installed by piping the official install script from `github.com/raythurman2386/raven`, and Ollama from `ollama.com` (both as `script:` entries in `config/packages/core.list`).
- **Raven location:** `~/.cargo/bin/`
- **Raven binary:** `~/.cargo/bin/raven`
- **Raven config:** `~/.raven/config.toml`
- **Ollama binary:** `/usr/local/bin/ollama` (symlink to `/usr/local/lib/ollama/ollama`)
- **Ollama service:** `ollama.service` (systemd, listens on `127.0.0.1:11434`)

## Quick Start

You can launch Raven from any terminal:

```bash
raven --help
```

### Initial Configuration

On first run, Raven walks you through provider and model selection. The Pimarchy default config (`config/raven/config.toml`) pre-configures the `ollama` provider and the `ravenwood` TUI theme.

```bash
raven
```

## Features

- **Local First:** Runs against Ollama on your machine by default; dial in OpenRouter when a task needs a bigger model.
- **No Telemetry:** No usage tracking, no phone-home, no cloud sync. All session state stays on disk, locally.
- **Auditable:** A single binary (~23K lines of Rust) you can read end-to-end.
- **Small Footprint:** Runs comfortably on a Raspberry Pi. No daemon, no background indexing.
- **Production-Grade Safety:** Workspace confinement (Landlock + seccomp), shell command filters, git-worktree isolation, and a verify-before-done gate.

## Uninstalling Raven

If you decide you no longer need Raven, you can remove it manually or by running `uninstall.sh`.

Manual removal:
```bash
# Remove the binary and configuration
rm -f ~/.cargo/bin/raven
rm -f ~/.raven/config.toml

# Remove Ollama (optional)
sudo systemctl stop ollama && sudo systemctl disable ollama
sudo rm -f /usr/local/bin/ollama
sudo rm -rf /usr/local/lib/ollama
sudo userdel -r ollama
```

## Troubleshooting Raven

- **Command not found:** Ensure `~/.cargo/bin` is in your `PATH`. Run `source ~/.bashrc` to refresh.
- **Update:** Raven can be updated with `raven self update`.
- **Reinstall:** Re-run the install command:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/raythurman2386/raven/master/install.sh | sh
  ```
