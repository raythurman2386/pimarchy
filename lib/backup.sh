#!/bin/bash
#
# Pimarchy Library — Backup & Restore
#

PIMARCHY_BACKUP_ITEMS=("hypr" "waybar" "rofi" "mako" "gtk-3.0" "foot")

# backup_configs — first install snapshots originals under $BACKUP_DIR;
# reinstalls snapshot the current state under previous-<timestamp>/.
backup_configs() {
    log_info "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    if [ -f "$BACKUP_DIR/.original-backup" ]; then
        log_info "Original backups already exist, creating timestamped backup..."
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local new_backup_dir="$BACKUP_DIR/previous-${timestamp}"
        mkdir -p "$new_backup_dir"

        local item
        for item in "${PIMARCHY_BACKUP_ITEMS[@]}"; do
            if [ -d "$HOME/.config/$item" ]; then
                log_info "Backing up current ~/.config/$item"
                cp -r "$HOME/.config/$item" "$new_backup_dir/${item}.bak" 2>/dev/null || true
            fi
        done

        if [ -f "$HOME/.gtkrc-2.0" ]; then
            cp "$HOME/.gtkrc-2.0" "$new_backup_dir/gtkrc-2.0.bak" 2>/dev/null || true
        fi

        log_success "Current configs backed up to $new_backup_dir"
    else
        log_info "Creating original backup of system configs..."

        local item
        for item in "${PIMARCHY_BACKUP_ITEMS[@]}"; do
            if [ -d "$HOME/.config/$item" ]; then
                log_info "Backing up ~/.config/$item"
                cp -r "$HOME/.config/$item" "$BACKUP_DIR/${item}.bak" 2>/dev/null || true
            fi
        done

        if [ -f "$HOME/.gtkrc-2.0" ]; then
            log_info "Backing up ~/.gtkrc-2.0"
            cp "$HOME/.gtkrc-2.0" "$BACKUP_DIR/gtkrc-2.0.bak" 2>/dev/null || true
        fi

        echo "Original system configuration backup" > "$BACKUP_DIR/.original-backup"
        date >> "$BACKUP_DIR/.original-backup"

        log_success "Original backups saved to $BACKUP_DIR"
    fi
}

restore_configs() {
    log_info "Restoring configurations from backup..."

    if [ ! -d "$BACKUP_DIR" ]; then
        log_warn "No backup directory found at $BACKUP_DIR"
        return 0
    fi

    if [ ! -f "$BACKUP_DIR/.original-backup" ]; then
        log_warn "No original backup marker found - backup may not contain original configs"
    fi

    local item
    for item in "${PIMARCHY_BACKUP_ITEMS[@]}"; do
        if [ -d "$BACKUP_DIR/${item}.bak" ]; then
            log_info "Restoring ~/.config/$item"
            rm -rf "$HOME/.config/$item"
            cp -r "$BACKUP_DIR/${item}.bak" "$HOME/.config/$item"
        fi
    done

    if [ -f "$BACKUP_DIR/gtkrc-2.0.bak" ]; then
        log_info "Restoring ~/.gtkrc-2.0"
        cp "$BACKUP_DIR/gtkrc-2.0.bak" "$HOME/.gtkrc-2.0"
    fi

    log_success "Configuration restore complete"
}