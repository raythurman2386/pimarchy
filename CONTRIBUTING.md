# Contributing to Pimarchy

Thank you for your interest in contributing to Pimarchy! This document provides guidelines for contributing to the project.

## Code of Conduct

Be respectful and constructive in all interactions.

## How to Contribute

### Reporting Issues

When reporting issues, please include:
- Raspberry Pi model (e.g., Pi 5)
- OS version (e.g., Debian Bookworm)
- What you were trying to do
- What actually happened
- Steps to reproduce
- Any error messages

### Suggesting Features

Feature suggestions are welcome! Please:
- Check if the feature has already been suggested
- Describe the use case
- Explain why it would be useful

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test your changes thoroughly
5. Commit with clear messages
6. Push to your fork
7. Open a Pull Request

### Commit Message Format

```
type: Brief description

Longer explanation if needed

- Bullet points for details
- More details
```

Types:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Formatting changes
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

## Development Setup

1. Clone the repository
2. Make changes to config files in `config/`
3. Test with `bash install.sh --dry-run` first
4. Test actual install on a test system or VM

## Project Structure

- `config/` - All configuration templates
- `lib/` - Shared library functions
- `install.sh` - Main installer
- `uninstall.sh` - Uninstaller

## Questions?

Feel free to open an issue for questions or discussion.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
