# Raven AI Agent

Pimarchy includes built-in support for the **Raven AI agent**. Raven is a small, privacy-first coding-agent harness written in Rust for Ollama and any OpenAI-compatible endpoint. It runs a full agent loop — tools, plan mode, verification, and workspace isolation — against a model endpoint you control.

Pimarchy also installs **Ollama** by default as Raven's local inference backend. Raven talks to Ollama at `http://localhost:11434/v1`.

## Installation Details

Raven is installed by piping the official install script from `github.com/raythurman2386/raven`, and Ollama from `ollama.com`.
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
