# Contributing to Pimarchy

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Code of Conduct
Be respectful and constructive in all interactions.

## How to Contribute

### Reporting Issues
When reporting issues, please include:
-   **Hardware:** Raspberry Pi 5 / Pi 500
-   **OS Version:** Pi OS Lite (Debian Bookworm)
-   **Step:** Which part of the `install.sh` or `uninstall.sh` failed?
-   **Error:** Copy and paste the exact error message.
-   **Logs:** Provide any relevant logs from `/tmp/hypr/` or `journalctl`.

### Suggesting Features
Feature suggestions are welcome! Please:
-   Check if the feature has already been suggested.
-   Describe the use case and why it fits the "Pimarchy" aesthetic and goals.

### Pull Requests
1.  Fork the repository.
2.  Create a feature branch (`git checkout -b feature/amazing-feature`).
3.  Make your changes.
4.  **Validate:** Run `bash validate.sh` to ensure your templates and variables are correct.
5.  **Test:** Test your changes on a clean Pi OS Lite installation if possible.
6.  Commit with clear messages (e.g., `feat: Add support for [App]`).
7.  Open a Pull Request.

## Coding Standards

### Shell Scripting
-   Use `#!/bin/bash`.
-   Include `set -e` for safety.
-   Use `local` for all variables inside functions.
-   Quote your variables: `"$my_var"`.
-   Follow the existing indentation (4 spaces).

### Templates
-   Use double curly braces for variables: `{{COLOR_PRIMARY}}`.
-   Always register new templates in `config/modules.conf`.
-   Ensure any new variables are added to `config/theme.conf`.

### Documentation
-   If you add a new feature, please update the documentation in the `docs/` folder.
-   Pimarchy uses [MkDocs Material](https://squidfunk.github.io/mkdocs-material/).

## License
By contributing, you agree that your contributions will be licensed under the MIT License.
