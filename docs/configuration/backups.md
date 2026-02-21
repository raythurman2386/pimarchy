# Backup System

Pimarchy prioritizes your existing data and configuration by creating comprehensive backups during every installation.

## Original Backup
When you first run `bash install.sh`, Pimarchy detects if a backup already exists.
- **Location:** `~/.config/Pimarchy-backup/original/`
- **Marker:** A file named `.original-backup` is created in this folder to mark it as the source of truth for your system's initial state.
- **Restoration:** This is the backup used by `uninstall.sh` to revert your system.

## Incremental Snapshots
Every time you re-run the installer (e.g., after changing `theme.conf`), an incremental snapshot is created.
- **Location:** `~/.config/Pimarchy-backup/previous-YYYYMMDD-HHMMSS/`
- **Contents:** A full copy of your previous `~/.config/` folder.

## How to Restore a Snapshot
If you make a change and want to revert to a previous version of your configuration:

1.  Find the snapshot you want to restore:
    ```bash
    ls -l ~/.config/Pimarchy-backup/
    ```
2.  Copy the files back to your `~/.config/` folder:
    ```bash
    # Example: Replace YYYYMMDD-HHMMSS with your actual timestamp
    cp -r ~/.config/Pimarchy-backup/previous-YYYYMMDD-HHMMSS/* ~/.config/
    ```

## Storage Management
Over time, multiple backups can take up disk space. You can safely delete older snapshots:

```bash
# Delete all but the original and the latest snapshot
cd ~/.config/Pimarchy-backup/
ls -1t | tail -n +3 | xargs rm -rf
```

!!! danger "Do Not Delete the `.original-backup` Folder"
    The folder `~/.config/Pimarchy-backup/original/` contains your system's pre-Pimarchy state. Deleting it will make it impossible for `uninstall.sh` to revert your system accurately.
