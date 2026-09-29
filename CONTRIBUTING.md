# Contributing to Pimarchy

Thank you for your interest in contributing to Pimarchy! This document provides guidelines for contributing to the project.

For the fuller docs-site version, see [docs/development/contributing.md](docs/development/contributing.md).

## Code of Conduct

Be respectful and constructive in all interactions.

## How to Contribute

### Reporting Issues

When reporting issues, please include:
- Raspberry Pi model (e.g., Pi 5, Pi 500, Pi 500+)
- OS version (Pi OS Lite, Debian Trixie, arm64)
- What you were trying to do (netinstall vs custom image / firstboot)
- What actually happened
- Steps to reproduce
- Relevant logs (`~/pimarchy_install.log`, `/var/log/pimarchy-firstboot.log`, `journalctl`)

### Suggesting Features

Feature suggestions are welcome! Please:
- Check if the feature has already been suggested
- Describe the use case
- Explain why it would be useful

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run `bash validate.sh` (includes `enable-autologin.sh` syntax). There is **no arm64 image-build in GitHub Actions** today — SD/`image/build-image.sh` remains manual/hardware.
5. Commit with clear messages
6. Push to your fork
7. Open a Pull Request (**do not merge** unless maintainers ask)

### Commit Message Format

```
type: Brief description

Longer explanation if needed

- Bullet points for details
```

Types: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`

## Development Setup

1. Clone the repository
2. Make changes to config files in `config/`
3. Test with `bash install.sh --dry-run` first
4. Test actual install on Pi OS Lite (or the custom image path) when touching install/image code

## Project Structure

- `config/` — templates, `theme.conf`, `modules.conf`, package lists
- `lib/` — shared library modules (aggregated by `lib/functions.sh`)
- `image/` — custom SD-card image + first-boot pipeline
- `bin/` — CLI entrypoints
- `install.sh` / `uninstall.sh` / `validate.sh` / `netinstall.sh`

## Questions?

Feel free to open an issue for questions or discussion.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
