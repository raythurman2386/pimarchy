# OpenCode AI Agent

Pimarchy includes built-in support for the **OpenCode AI agent**. OpenCode is a specialized tool for AI-assisted development and automation directly on your Raspberry Pi.

## Installation Details

OpenCode is installed by piping the official install script from `opencode.ai`.
- **Location:** `~/.opencode/`
- **Binary:** `~/.opencode/bin/opencode`
- **PATH:** The installer adds `~/.opencode/bin` to your `PATH` in `~/.bashrc`.
- **Config:** The configuration for OpenCode lives at `~/.config/opencode/opencode.json`.

## Quick Start

You can launch OpenCode from any terminal:

```bash
opencode --help
```

### Initial Configuration
When you first run OpenCode, you may need to configure your API keys or settings:
```bash
opencode config
```

## Features

- **Code Generation:** Generate boilerplates, functions, and scripts.
- **System Automation:** Use AI to assist with system maintenance and configuration.
- **Local Context:** OpenCode understands your project structure and can help you develop Pimarchy modules.

## Uninstalling OpenCode

If you decide you no longer need OpenCode, you can remove it manually or by running `uninstall.sh`.

Manual removal:
```bash
# Remove the binaries and configuration
rm -rf ~/.opencode
rm -rf ~/.config/opencode

# Clean up ~/.bashrc
sed -i '/opencode/d' ~/.bashrc
```

## Troubleshooting OpenCode

- **Command not found:** Ensure your `PATH` is updated. Run `source ~/.bashrc` to refresh.
- **Update failure:** OpenCode can be updated manually by running the install command again:
  ```bash
  curl -fsSL https://opencode.ai/install | bash
  ```
