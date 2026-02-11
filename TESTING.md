# Testing Guide for Pimarchy

This guide explains how to safely test the Pimarchy install/uninstall cycle.

## Quick Validation

Before installing, run the validator:

```bash
bash validate.sh
```

This checks:
- All template files exist
- All variables are defined
- Script syntax is valid

## Dry Run

Test the installation without making any changes:

```bash
bash install.sh --dry-run
```

This shows exactly what would be installed without modifying your system.

## Install → Uninstall → Reinstall Cycle

The installer is designed to be fully reversible. Here's how the backup system works:

### First Install

```bash
bash install.sh
```

What happens:
1. Original system configs are backed up to `~/.config/Pimarchy-backup/`
2. A `.original-backup` marker file is created
3. Pimarchy configs are installed

### Uninstall

```bash
bash uninstall.sh
```

What happens:
1. Pimarchy services are stopped
2. Pimarchy config files are removed
3. **Original configs are restored** from the backup
4. Backup directory is preserved (you'll be asked if you want to delete it)

### Reinstall

After uninstalling, you can safely reinstall:

```bash
bash install.sh
```

What happens:
1. Since `.original-backup` marker exists, your current configs (which are the original system defaults) are backed up to a **timestamped directory** (e.g., `Pimarchy-backup/previous-20250211-100530/`)
2. The original backup is **preserved**
3. Pimarchy configs are installed fresh

## Key Safety Features

### 1. Original Backup Protection

The `.original-backup` marker ensures your original system configuration is never overwritten after the first install. Even if you:
- Install Pimarchy
- Uninstall (restore originals)
- Reinstall
- Uninstall again

The uninstaller will always restore the true original system configuration.

### 2. Timestamped Backups

If you reinstall without removing the backup directory first, your current configuration gets backed up with a timestamp. This lets you:
- Keep track of different configuration states
- Roll back to any previous setup
- Never lose a working configuration

### 3. Selective Uninstall

The uninstaller asks before:
- Removing packages (keeps them if you say no)
- Removing backup directory (preserves it if you say no)

## Testing Checklist

- [ ] Run `validate.sh` - should pass
- [ ] Run `install.sh --dry-run` - review the output
- [ ] Run `install.sh` - install Pimarchy
- [ ] Log out and back in - verify desktop works
- [ ] Run `uninstall.sh` - restore original desktop
- [ ] Say 'n' to removing packages and backups
- [ ] Log out and back in - verify original desktop works
- [ ] Run `install.sh` again - reinstall Pimarchy
- [ ] Check `~/.config/Pimarchy-backup/` - should have original + timestamped backup

## Troubleshooting

### "Backup already exists" warnings

This is normal and expected. The installer will create timestamped backups of your current configuration while preserving the original.

### Lost original configuration

If something goes wrong and you need to manually restore:

```bash
# Check what's in your backup directory
ls -la ~/.config/Pimarchy-backup/

# If .original-backup exists, restore from the main backup directory
cp -r ~/.config/Pimarchy-backup/labwc.bak/* ~/.config/labwc/
# ... repeat for other configs
```

### Clean slate

To completely reset everything and start fresh:

```bash
# Uninstall everything
bash uninstall.sh
# Say 'y' to remove packages
# Say 'y' to remove backups

# Now install fresh
bash install.sh
```

## Files and Directories

- **Installation scripts**: `install.sh`, `uninstall.sh`, `validate.sh`
- **Library functions**: `lib/functions.sh`
- **Configuration templates**: `config/` directory
- **Backup location**: `~/.config/Pimarchy-backup/`
- **Installed configs**: `~/.config/labwc/`, `~/.config/waybar/`, etc.

## Customization Testing

After you're comfortable with the install/uninstall cycle, test customization:

1. Edit `config/keybinds/keybinds.conf` to change keybindings
2. Edit `config/theme.conf` to change colors
3. Run `install.sh` to apply changes
4. Test your new configuration
5. Run `uninstall.sh` to revert (original configs preserved!)

## Need Help?

- Run `bash install.sh --help` for options
- Check `PIMARCHY_DOCS.md` for detailed documentation
- Review the backup directory structure if something seems wrong
