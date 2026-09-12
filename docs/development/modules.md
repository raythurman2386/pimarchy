# Adding New Modules

Pimarchy is designed to be easily extendable. You can add support for new components or configurations by following this guide.

## 1. Create the Template
A module consists of a template file (usually ending in `.template`) located in the `config/` directory.

Example: `config/myapp/config.template`

```bash
# Example template content
color = "{{COLOR_PRIMARY}}"
font = "{{FONT_MAIN}}"
```

## 2. Register the Module
Open `config/modules.conf` and add a new line for your module.

Format:
`module_name|source_path|~/.config/target_path|Human description`

Example:
`myapp|myapp/config.template|~/.config/myapp/config|My App Configuration`

## 3. Define Variables (Optional)
If your new module uses new variables, add them to `config/theme.conf`.

```bash
export MY_VAR="#ff00ff"
```

## 4. Update the Package Lists (If Necessary)
If your module requires a new package, add it to the right list in `config/packages/`:

```bash
# Core (always installed) — keep this lean; memory efficiency is the priority
echo "apt:myapp-package" >> config/packages/core.list

# Or a lazy module
echo "apt:myapp-package" >> config/packages/dev.list
```

For apps not in Debian repos, add a `script:<label>` line and register the installer in `run_module_script_hooks` (in `lib/apps.sh`).

## 5. Test with the Validator
Before committing your changes, run `validate.sh` to ensure:
1.  The template file exists.
2.  The target path is valid.
3.  All variables in the template are defined in `theme.conf`.

```bash
bash validate.sh
```

## 6. Run the Install
Apply your changes to your system:
```bash
bash install.sh
```

!!! info "Contributing Modules"
    If you've created a useful module (e.g., support for a new bar, launcher, or terminal), we'd love to see it! Please submit a Pull Request.
    See the [Contributing Guide](contributing.md) for more information.
