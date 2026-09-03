#!/bin/bash
#
# Pimarchy Library — Safe Upgrade Model (Quattro)
#
# `pimarchy update` upgrades shipped config files without clobbering user
# edits. Policy, per target file listed in modules.conf (mode "safe"):
#
#   1. Missing file                → install (always, incl. new Quattro files).
#   2. Current hash == manifest    → pristine: refresh from the new default.
#   3. Current hash != manifest    → user-modified: LEAVE UNTOUCHED, log it.
#   4. File exists, no manifest    → unknown origin (pre-Quattro or user file):
#                                    leave untouched, log it.
#
# Mode "force" (install.sh / `pimarchy install`) always overwrites — that is
# the historical re-apply workflow — and records fresh hashes afterwards so
# the next `pimarchy update` is gated against the new baseline.
#
# Hashes are recorded in ~/.config/pimarchy/manifest. `pimarchy update`
# snapshots pristine hashes with the OLD code before pulling, so files
# unchanged since the last install are recognized as refreshable.
# Retired files (config/packages/retired.conf) are renamed to
# <file>.pimarchy-upgrade.bak and then removed.
#

# hash_file — sha256 of a file ("" if missing).
hash_file() {
    local file="$1"
    if [ -f "$file" ]; then
        sha256sum "$file" | awk '{print $1}'
    else
        echo ""
    fi
}

# manifest_key_for <target> — manifest key for a target path (~ collapsed
# to ~ so the manifest stays portable across users).
manifest_key_for() {
    local target="$1"
    echo "${target/#$HOME/~}"
}

# manifest_lookup <target> — old hash recorded for the target ("" if none).
manifest_lookup() {
    local target="$1"
    local key
    key=$(manifest_key_for "$target")
    if [ -f "$PIMARCHY_MANIFEST_FILE" ]; then
        awk -F'|' -v key="$key" '$1 == key {print $2; exit}' "$PIMARCHY_MANIFEST_FILE"
    else
        echo ""
    fi
}

# record_installed_hash <target> — write/refresh the manifest entry.
record_installed_hash() {
    local target="$1"
    local key hash
    key=$(manifest_key_for "$target")
    hash=$(hash_file "$target")

    mkdir -p "$(dirname "$PIMARCHY_MANIFEST_FILE")"

    if [ -f "$PIMARCHY_MANIFEST_FILE" ]; then
        local tmp="$PIMARCHY_MANIFEST_FILE.tmp"
        awk -F'|' -v key="$key" '$1 != key' "$PIMARCHY_MANIFEST_FILE" > "$tmp"
        mv "$tmp" "$PIMARCHY_MANIFEST_FILE"
    fi
    echo "${key}|${hash}" >> "$PIMARCHY_MANIFEST_FILE"
}

upgrade_needs_sudo() {
    case "$1" in
        /etc/*) return 0 ;;
        *)      return 1 ;;
    esac
}

# render_template_hash <template> — hash of a template as it would render
# right now (non-template files hash the repo file directly).
render_template_hash() {
    local template="$1"
    local template_path="$PIMARCHY_ROOT/config/$template"
    local tmp

    if [[ "$template" == *.template ]]; then
        tmp=$(mktemp)
        process_template "$template_path" "$tmp" >/dev/null 2>&1 || { rm -f "$tmp"; echo ""; return; }
        hash_file "$tmp"
        rm -f "$tmp"
    else
        hash_file "$template_path"
    fi
}

# install_module_target <template> <target> [mode] — install one modules.conf
# entry. mode: "safe" (default; hash-gated) or "force" (always overwrite).
# Both modes record the installed hash. Returns 0 on success, 1 on failure.
install_module_target() {
    local template="$1"
    local raw_target="$2"
    local mode="${3:-safe}"
    local template_path="$PIMARCHY_ROOT/config/$template"
    local target_path="${raw_target/#\~/$HOME}"

    if [ ! -f "$template_path" ]; then
        log_error "Missing template: $template"
        return 1
    fi

    if [ "$mode" = "safe" ] && [ -f "$target_path" ]; then
        local old_hash current_hash
        old_hash=$(manifest_lookup "$target_path")
        current_hash=$(hash_file "$target_path")

        if [ -z "$old_hash" ]; then
            log_info "Not in manifest (user or pre-Quattro file), leaving untouched: $target_path"
            return 0
        fi
        if [ "$current_hash" != "$old_hash" ]; then
            log_info "User-modified, leaving untouched: $target_path"
            return 0
        fi
    fi

    local needs_sudo=false
    if upgrade_needs_sudo "$target_path"; then
        needs_sudo=true
    fi

    if [[ "$template" == *.template ]]; then
        if [ "$needs_sudo" = true ]; then
            local tmp_out
            tmp_out=$(mktemp)
            process_template "$template_path" "$tmp_out" || { rm -f "$tmp_out"; return 1; }
            if ! sudo mkdir -p "$(dirname "$target_path")" \
               || ! sudo cp "$tmp_out" "$target_path" \
               || ! sudo chmod 644 "$target_path"; then
                rm -f "$tmp_out"
                log_error "Failed to write (needs sudo, which may require a tty): $target_path"
                return 1
            fi
            rm -f "$tmp_out"
            log_success "Generated (system): $target_path"
        else
            mkdir -p "$(dirname "$target_path")"
            process_template "$template_path" "$target_path" || return 1
        fi
    else
        if [ "$needs_sudo" = true ]; then
            if ! sudo mkdir -p "$(dirname "$target_path")" \
               || ! sudo cp "$template_path" "$target_path" \
               || ! sudo chmod 644 "$target_path"; then
                log_error "Failed to write (needs sudo, which may require a tty): $target_path"
                return 1
            fi
        else
            mkdir -p "$(dirname "$target_path")"
            cp "$template_path" "$target_path"
        fi
        log_success "Copied: $target_path"
    fi

    if [[ "$raw_target" == *.sh ]] || [[ "$target_path" == */bin/* ]]; then
        chmod +x "$target_path" 2>/dev/null || sudo chmod +x "$target_path"
    fi

    record_installed_hash "$target_path"
    return 0
}

# deploy_module_configs [mode] — walk modules.conf installing every entry
# under the given policy ("safe" or "force").
deploy_module_configs() {
    local mode="${1:-safe}"
    log_info "Applying configuration files (mode: $mode)..."

    local module template target description
    while IFS='|' read -r module template target description; do
        [[ -z "$module" || "$module" =~ ^# ]] && continue
        install_module_target "$template" "$target" "$mode" || true
    done < "$CONFIG_DIR/modules.conf"

    log_success "Configuration files applied"
}

# Back-compat alias for the original Quattro name.
upgrade_module_configs() {
    deploy_module_configs "safe"
}

# snapshot_pristine_hashes — record manifest entries for installed files that
# exactly match a freshly rendered CURRENT template. Called by `pimarchy
# update` BEFORE git pull (old code still checked out) so pristine files —
# including any the manifest missed — are recognized as refreshable after
# the upgrade.
snapshot_pristine_hashes() {
    log_info "Snapshotting pristine config hashes (pre-upgrade)..."
    mkdir -p "$(dirname "$PIMARCHY_MANIFEST_FILE")"

    local module template raw_target target_path rendered_hash current_hash
    while IFS='|' read -r module template raw_target description; do
        [[ -z "$module" || "$module" =~ ^# ]] && continue
        target_path="${raw_target/#\~/$HOME}"

        [ -f "$target_path" ] || continue

        current_hash=$(hash_file "$target_path")
        rendered_hash=$(render_template_hash "$template")
        if [ -n "$rendered_hash" ] && [ "$current_hash" = "$rendered_hash" ]; then
            record_installed_hash "$target_path"
        fi
    done < "$CONFIG_DIR/modules.conf"

    log_success "Pristine hash snapshot complete"
}

# remove_retired_files — for each path in config/packages/retired.conf:
# rename to <path>.pimarchy-upgrade.bak, then remove. Only Pimarchy-owned
# locations are touched (home dotfiles + /etc paths we manage).
remove_retired_files() {
    local retired_file="$PACKAGE_LIST_DIR/retired.conf"

    if [ ! -f "$retired_file" ]; then
        return 0
    fi

    local raw path bak
    while IFS= read -r raw; do
        [[ -z "$raw" || "$raw" =~ ^[[:space:]]*# ]] && continue
        path="${raw/#\~/$HOME}"
        if [ -f "$path" ] || [ -L "$path" ]; then
            bak="${path}.pimarchy-upgrade.bak"
            log_info "Retiring: $path → ${bak}"
            if upgrade_needs_sudo "$path"; then
                sudo mv "$path" "$bak" && sudo rm -f "$bak"
            else
                mv "$path" "$bak" && rm -f "$bak"
            fi
        fi
    done < "$retired_file"
}

# upgrade_full — the complete `pimarchy update` sequence after git pull:
# retired files, defaults, configs (hash-gated), services, CLI symlink.
upgrade_full() {
    log_info "Applying Pimarchy upgrade..."

    remove_retired_files
    defaults_install_defaults
    defaults_export_vars
    deploy_module_configs "safe"

    # Refresh user services so template changes take effect next login
    configure_swaybg
    configure_waybar
    configure_mako

    # Keep the CLI symlink pointing at the (possibly moved) repo checkout.
    # Non-fatal: a missing symlink doesn't invalidate the config upgrade.
    if ! sudo ln -sf "$PIMARCHY_ROOT/bin/pimarchy" /usr/local/bin/pimarchy; then
        log_warn "Could not refresh /usr/local/bin/pimarchy symlink (sudo failed) — run manually if needed"
    fi

    log_success "Pimarchy upgrade applied"
}