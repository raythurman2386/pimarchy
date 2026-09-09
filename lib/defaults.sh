#!/bin/bash
#
# Pimarchy Library — Default App Policy (Quattro)
#
# Default apps are recorded as key=value files in ~/.config/pimarchy/defaults/:
#   agent       → raven    (pre-selected; launcher: `pimarchy agent`)
#   editor      → zed      (Zed, official script install)
#   terminal    → foot     (Foot, apt)
#   browser     → chromium (Chromium, apt)
#   filemanager → pifile   (Pifile, official script install)
#
# Files are consumed by launchers and templates, so values are validated
# against a fixed allowlist — an arbitrary value must never be exec'd.
#

# defaults_allowlist — <key> <allowed values...>
defaults_allowlist() {
    case "$1" in
        agent)        echo "raven" ;;
        editor)       echo "zed" ;;
        terminal)     echo "foot" ;;
        browser)      echo "chromium" ;;
        filemanager)  echo "pifile" ;;
        *)            echo "" ;;
    esac
}

# defaults_default_for <key> — the shipped default when nothing is set yet.
defaults_default_for() {
    case "$1" in
        agent)        echo "raven" ;;
        editor)       echo "zed" ;;
        terminal)     echo "foot" ;;
        browser)      echo "chromium" ;;
        filemanager)  echo "pifile" ;;
        *)            echo "" ;;
    esac
}

# defaults_validate <key> <value> — exit 0 iff value is allowlisted for key.
defaults_validate() {
    local key="$1" value="$2"
    local allowed
    for allowed in $(defaults_allowlist "$key"); do
        if [ "$value" = "$allowed" ]; then
            return 0
        fi
    done
    return 1
}

# defaults_read <key> — print the stored value or the shipped default.
# Never fails: a corrupted/unknown file falls back to the default.
defaults_read() {
    local key="$1"
    local file="$PIMARCHY_DEFAULTS_DIR/$key"
    local value

    if [ -f "$file" ]; then
        value=$(sed -n "s/^${key}=//p" "$file" 2>/dev/null)
        if defaults_validate "$key" "$value"; then
            echo "$value"
            return 0
        fi
        log_warn "Invalid value for default '$key': '$value' — using shipped default" >&2
    fi

    defaults_default_for "$key"
}

# defaults_set <key> <value> — write the default file (validated).
defaults_set() {
    local key="$1" value="$2"

    if ! defaults_validate "$key" "$value"; then
        log_error "Invalid default '$key=$value'. Available: $(defaults_allowlist "$key" | tr '\n' ' ')"
        return 1
    fi

    mkdir -p "$PIMARCHY_DEFAULTS_DIR"
    cat > "$PIMARCHY_DEFAULTS_DIR/$key" <<EOF
# ~/.config/pimarchy/defaults/$key
# Written by: pimarchy default $key <name>
# Read by:    pimarchy $key, install.sh templates
${key}=${value}
EOF
    log_success "Default $key set to $value"
}

# defaults_install_defaults — ship the pre-selected defaults on fresh installs
# (only writes files that don't exist yet, so user choices survive reinstalls).
defaults_install_defaults() {
    local key
    for key in agent editor terminal browser filemanager; do
        if [ ! -f "$PIMARCHY_DEFAULTS_DIR/$key" ]; then
            defaults_set "$key" "$(defaults_default_for "$key")"
        fi
    done
}

# defaults_show — print all defaults and their sources.
defaults_show() {
    local key value source
    for key in agent editor terminal browser filemanager; do
        if [ -f "$PIMARCHY_DEFAULTS_DIR/$key" ]; then
            value=$(sed -n "s/^${key}=//p" "$PIMARCHY_DEFAULTS_DIR/$key" 2>/dev/null)
            source="set"
        else
            value=$(defaults_default_for "$key")
            source="built-in"
        fi
        printf '%-12s %-12s (%s)\n' "$key" "$value" "$source"
    done
}

# defaults_file_value — export template-friendly variables for install.sh:
# DEFAULT_AGENT, DEFAULT_EDITOR, DEFAULT_TERMINAL, DEFAULT_BROWSER,
# DEFAULT_FILEMANAGER.
defaults_export_vars() {
    export DEFAULT_AGENT=$(defaults_read agent)
    export DEFAULT_EDITOR=$(defaults_read editor)
    export DEFAULT_TERMINAL=$(defaults_read terminal)
    export DEFAULT_BROWSER=$(defaults_read browser)
    export DEFAULT_FILEMANAGER=$(defaults_read filemanager)
}

# defaults_remove_files — uninstall hook.
defaults_remove_files() {
    rm -rf "$PIMARCHY_DEFAULTS_DIR"
}