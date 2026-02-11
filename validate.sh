#!/bin/bash
#
# Pimarchy Configuration Validator
# Run this before installing to check for any issues
#

set -e

PIMARCHY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Pimarchy Configuration Validator ==="
echo ""

# Source library and configs
source "$PIMARCHY_ROOT/lib/functions.sh"

echo "[1/4] Loading configurations..."
load_config "$PIMARCHY_ROOT/config/theme.conf"
load_config "$PIMARCHY_ROOT/config/keybinds/keybinds.conf"
# Set SCRIPT_DIR as install.sh does (needed for waybar config template)
SCRIPT_DIR="$HOME/.config/labwc"

echo "[2/4] Checking template files..."

# Track missing variables
missing_vars=()

# Check each template for undefined variables
while IFS='|' read -r module template target description; do
    [[ -z "$module" || "$module" =~ ^# ]] && continue
    
    template_path="$PIMARCHY_ROOT/config/$template"
    
    if [ ! -f "$template_path" ]; then
        echo "  ✗ Missing template: $template"
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
echo "[3/4] Checking required variables..."

required_vars=(
    "FONT_FAMILY"
    "GTK_THEME"
    "ICON_THEME"
    "CURSOR_THEME"
    "COLOR_SCHEME"
    "WORKSPACE_COUNT"
    "KEYBIND_LAUNCHER"
    "LAUNCHER_CMD"
    "KEYBIND_TERMINAL"
    "TERMINAL_CMD"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var+x}" ]; then
        echo "  ✗ Missing required variable: $var"
        missing_vars+=("$var (required)")
    else
        echo "  ✓ $var"
    fi
done

echo ""
echo "[4/4] Validating install/uninstall scripts..."

if bash -n "$PIMARCHY_ROOT/install.sh"; then
    echo "  ✓ install.sh syntax OK"
else
    echo "  ✗ install.sh has syntax errors"
fi

if bash -n "$PIMARCHY_ROOT/uninstall.sh"; then
    echo "  ✓ uninstall.sh syntax OK"
else
    echo "  ✗ uninstall.sh has syntax errors"
fi

if bash -n "$PIMARCHY_ROOT/lib/functions.sh"; then
    echo "  ✓ lib/functions.sh syntax OK"
else
    echo "  ✗ lib/functions.sh has syntax errors"
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
