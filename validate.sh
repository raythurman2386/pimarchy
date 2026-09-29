#!/bin/bash
#
# Pimarchy Configuration Validator
# Run this before installing (and before every commit) to check for issues.
#

set -e

PIMARCHY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Pimarchy Configuration Validator ==="
echo ""

# All library modules sourced via the aggregator
LIB_FILES=(
    common
    log
    template
    backup
    repos
    packages
    services
    pi-perf
    apps
    defaults
    upgrade
)

echo "[1/6] Loading configurations..."
source "$PIMARCHY_ROOT/lib/functions.sh"

load_config "$PIMARCHY_ROOT/config/theme.conf"
# Set derived variables
export COLOR_PRIMARY_HEX="${COLOR_PRIMARY#\#}"
export COLOR_SURFACE_HEX="${COLOR_SURFACE#\#}"
export TERM_FG_HEX="${TERM_FG_COLOR#\#}"
export TERM_BG_HEX="${TERM_BG_COLOR#\#}"
for _i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    _palette_var="TERM_PALETTE_${_i}"
    _hex_value="${!_palette_var}"
    _hex_value="${_hex_value#\#}"
    export "TERM_PALETTE_${_i}_HEX=$_hex_value"
done
unset _i _palette_var _hex_value

# Detect keyboard layout (same as install.sh)
export KEYBOARD_LAYOUT=$(detect_keyboard_layout)

# Quattro default app policy variables (same as install.sh)
defaults_export_vars

echo ""
echo "[2/6] Checking script syntax (every sourced file)..."

syntax_failures=()

check_syntax() {
    local file="$1"
    if bash -n "$file"; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file has syntax errors"
        syntax_failures+=("$file")
    fi
}

for entry in install.sh uninstall.sh validate.sh netinstall.sh enable-autologin.sh; do
    check_syntax "$PIMARCHY_ROOT/$entry"
done

check_syntax "$PIMARCHY_ROOT/lib/functions.sh"
check_syntax "$PIMARCHY_ROOT/lib/pi-firmware.sh"
check_syntax "$PIMARCHY_ROOT/lib/ensure-dev-root.sh"
check_syntax "$PIMARCHY_ROOT/image/firstboot.sh"
check_syntax "$PIMARCHY_ROOT/image/firstboot-console.sh"
check_syntax "$PIMARCHY_ROOT/image/wifi-country.sh"
check_syntax "$PIMARCHY_ROOT/image/sync-clock.sh"
check_syntax "$PIMARCHY_ROOT/image/build-image.sh"
check_syntax "$PIMARCHY_ROOT/image/write-imager-manifest.sh"
for lib in "${LIB_FILES[@]}"; do
    check_syntax "$PIMARCHY_ROOT/lib/$lib.sh"
done

for script in bin/pimarchy bin/pimarchy-agent bin/pimarchy-default-agent \
              bin/pimarchy-install bin/pimarchy-upgrade bin/pimarchy-keybindings \
              bin/pimarchy-workspace bin/pimarchy-update-available \
              bin/pimarchy-update-available-reset; do
    check_syntax "$PIMARCHY_ROOT/$script"
done

if [ ${#syntax_failures[@]} -gt 0 ]; then
    echo ""
    echo "=== Validation FAILED (syntax) ==="
    printf '  - %s\n' "${syntax_failures[@]}"
    exit 1
fi

echo ""
echo "[3/6] Checking package lists..."

pkg_failures=()

for list_file in "$PIMARCHY_ROOT"/config/packages/*.list; do
    list="$(basename "$list_file" .list)"
    if [ -f "$list_file" ]; then
        # Every non-comment line must be tagged apt:, sid:, or script:
        bad_lines=$(read_package_list "$list" | grep -vE '^(apt|sid|script):' || true)
        if [ -n "$bad_lines" ]; then
            echo "  ✗ $list.list has untagged lines:"
            echo "$bad_lines" | sed 's/^/      /'
            pkg_failures+=("$list.list untagged lines")
        else
            counts=$(read_package_list "$list" | awk -F: '{print $1}' | sort | uniq -c | awk '{printf "%s %s  ", $1, $2}')
            echo "  ✓ $list.list ($counts)"
        fi
    else
        echo "  ✗ Missing package list: $list.list"
        pkg_failures+=("$list.list missing")
    fi
done

# script: labels must be known to run_module_script_hooks
KNOWN_SCRIPT_LABELS="zed pifile picalc raven ollama rustup cargo-config node go python-dev docker-group"
while IFS= read -r label; do
    [ -z "$label" ] && continue
    if ! grep -qw "$label" <<< "$KNOWN_SCRIPT_LABELS"; then
        echo "  ✗ Unknown script label: $label (no installer in run_module_script_hooks)"
        pkg_failures+=("unknown script label: $label")
    fi
done < <(for list_file in "$PIMARCHY_ROOT"/config/packages/*.list; do list_script_labels "$(basename "$list_file" .list)"; done)

if [ ${#pkg_failures[@]} -gt 0 ]; then
    echo ""
    echo "=== Validation FAILED (package lists) ==="
    printf '  - %s\n' "${pkg_failures[@]}"
    exit 1
fi

echo ""
echo "[4/6] Checking template files..."

# Track missing variables
missing_vars=()

# Check each template for undefined variables
while IFS='|' read -r module template target description; do
    [[ -z "$module" || "$module" =~ ^# ]] && continue

    template_path="$PIMARCHY_ROOT/config/$template"

    if [ ! -f "$template_path" ]; then
        echo "  ✗ Missing template: $template"
        missing_vars+=("missing file: $template")
        continue
    fi

    # Check for undefined variables (scan all {{VAR}} patterns per line)
    while IFS= read -r line; do
        remaining="$line"
        while [[ $remaining =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
            var_name="${BASH_REMATCH[1]}"
            if [ -z "${!var_name+x}" ]; then
                missing_vars+=("$var_name in $template")
            fi
            # Remove the matched portion and continue scanning
            remaining="${remaining#*\}\}}"
        done
    done < "$template_path"

    echo "  ✓ $template"
done < "$PIMARCHY_ROOT/config/modules.conf"

echo ""
echo "[5/6] Checking required variables..."

required_vars=(
    "FONT_FAMILY"
    "GTK_THEME"
    "ICON_THEME"
    "CURSOR_THEME"
    "COLOR_SCHEME"
    "DEFAULT_AGENT"
    "DEFAULT_EDITOR"
    "DEFAULT_TERMINAL"
    "DEFAULT_BROWSER"
    "DEFAULT_FILEMANAGER"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var+x}" ]; then
        echo "  ✗ Missing required variable: $var"
        missing_vars+=("$var (required)")
    else
        echo "  ✓ $var"
    fi
done

# Guard: every theme.conf variable must be consumed by at least one template.
# Prevents dead drift like unused RGBA/HEIGHT vars that once accumulated here.
echo ""
echo "[5b/6] Checking for unused theme variables..."

unused_theme_vars=()
while IFS='=' read -r var_name _; do
    var_name="$(echo "$var_name" | tr -d '[:space:]')"
    # Skip comments and blank lines
    [[ -z "$var_name" || "$var_name" == \#* ]] && continue
    if ! grep -rqF "{{${var_name}}}" "$PIMARCHY_ROOT/config" 2>/dev/null \
       && ! grep -rqw "$var_name" "$PIMARCHY_ROOT/lib" "$PIMARCHY_ROOT/bin" \
                        "$PIMARCHY_ROOT/install.sh" "$PIMARCHY_ROOT/uninstall.sh" \
                        "$PIMARCHY_ROOT/validate.sh" 2>/dev/null \
       && ! grep -rqE "TERM_PALETTE_\\\$\{?_i" "$PIMARCHY_ROOT/install.sh" \
                    "$PIMARCHY_ROOT/bin/pimarchy-upgrade" 2>/dev/null; then
        unused_theme_vars+=("$var_name")
    fi
done < "$PIMARCHY_ROOT/config/theme.conf"

if [ ${#unused_theme_vars[@]} -gt 0 ]; then
    echo "  ✗ Unused theme variables (defined but referenced by no template):"
    printf '    - %s\n' "${unused_theme_vars[@]}"
    missing_vars+=("unused theme vars: ${unused_theme_vars[*]}")
else
    echo "  ✓ all theme variables in use"
fi

echo ""
echo ""
echo "[5c/6] Checking Wayland-only GDK_BACKEND..."
gdk_failures=0
if ! grep -qE '^export GDK_BACKEND=wayland$' "$PIMARCHY_ROOT/config/hypr/start-hyprland.sh.template"; then
    echo "  ✗ start-hyprland.sh.template missing export GDK_BACKEND=wayland"
    gdk_failures=$((gdk_failures + 1))
elif grep -qE 'GDK_BACKEND=wayland,|,x11' "$PIMARCHY_ROOT/config/hypr/start-hyprland.sh.template"; then
    echo "  ✗ start-hyprland.sh.template must not set GDK_BACKEND with ,x11"
    gdk_failures=$((gdk_failures + 1))
else
    echo "  ✓ start-hyprland.sh GDK_BACKEND=wayland"
fi
if ! grep -qE 'hl\.env\("GDK_BACKEND", "wayland"\)' "$PIMARCHY_ROOT/config/hypr/hyprland.lua.template"; then
    echo "  ✗ hyprland.lua.template missing hl.env GDK_BACKEND wayland"
    gdk_failures=$((gdk_failures + 1))
elif grep -qE 'wayland,x11|,x11' "$PIMARCHY_ROOT/config/hypr/hyprland.lua.template"; then
    echo "  ✗ hyprland.lua.template must not set GDK_BACKEND with ,x11"
    gdk_failures=$((gdk_failures + 1))
else
    echo "  ✓ hyprland.lua GDK_BACKEND=wayland"
fi
if [ "$gdk_failures" -gt 0 ]; then
    echo ""
    echo "=== Validation FAILED (GDK_BACKEND) ==="
    exit 1
fi

echo ""
echo "[5d/6] Checking GPUI theme path (omarchy-only)..."
gpui_dests=$(awk -F'|' '$1 == "gpui" { print $3 }' "$PIMARCHY_ROOT/config/modules.conf")
gpui_fail=0
if [ -z "$gpui_dests" ]; then
    echo "  ✗ modules.conf has no gpui entries"
    gpui_fail=1
else
    if ! echo "$gpui_dests" | grep -q 'omarchy/current/theme'; then
        echo "  ✗ modules.conf gpui missing omarchy theme path"
        gpui_fail=1
    fi
    if echo "$gpui_dests" | grep -q 'pimarchy/current/theme'; then
        echo "  ✗ modules.conf still dual-writes pimarchy theme path"
        gpui_fail=1
    fi
    gpui_count=$(echo "$gpui_dests" | grep -c . || true)
    if [ "$gpui_count" -ne 2 ]; then
        echo "  ✗ expected 2 gpui destinations (colors.toml + theme.conf), got $gpui_count"
        gpui_fail=1
    fi
fi
if [ "$gpui_fail" -eq 0 ]; then
    echo "  ✓ modules.conf gpui → omarchy theme path only"
else
    echo ""
    echo "=== Validation FAILED (GPUI theme path) ==="
    exit 1
fi

echo "[6/6] Running functional tests..."

if bash "$PIMARCHY_ROOT/tests/test_template_loop.sh"; then
    echo "  ✓ Template infinite loop protection OK"
else
    echo "  ✗ Template infinite loop protection FAILED"
    exit 1
fi

if bash "$PIMARCHY_ROOT/tests/test_quattro.sh"; then
    echo "  ✓ Quattro module tests OK"
else
    echo "  ✗ Quattro module tests FAILED"
    exit 1
fi

echo ""

if [ ${#missing_vars[@]} -eq 0 ]; then
    echo "=== Validation PASSED ==="
    echo ""
    echo "All configurations look good! You can safely run:"
    echo "  bash install.sh"
    echo ""
    exit 0
else
    echo "=== Validation FAILED ==="
    echo ""
    echo "Missing variables:"
    printf '  - %s\n' "${missing_vars[@]}"
    echo ""
    echo "Please fix these issues before installing."
    echo ""
    exit 1
fi