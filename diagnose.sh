#!/bin/bash
#
# Pimarchy Diagnostic Tool
# Helps troubleshoot common issues
#

echo "=== Pimarchy Diagnostic Tool ==="
echo ""

# Check for duplicate panels
echo "[1/4] Checking for duplicate panels..."
panel_count=$(ps aux | grep -E "wf-panel-pi$" | grep -v grep | wc -l)
if [ "$panel_count" -gt 1 ]; then
    echo "  ⚠ WARNING: Found $panel_count wf-panel-pi processes running!"
    echo "  This usually means you have duplicate autostart files."
    echo ""
    echo "  To fix:"
    echo "    rm ~/.config/labwc/autostart"
    echo "    pkill -f wf-panel-pi"
    echo "    # Then log out and back in"
else
    echo "  ✓ Found $panel_count wf-panel-pi process(es) - OK"
fi

# Check autostart files
echo ""
echo "[2/4] Checking autostart configuration..."
if [ -f ~/.config/labwc/autostart ]; then
    echo "  User autostart: EXISTS"
    if [ -f /etc/xdg/labwc/autostart ]; then
        if diff -q ~/.config/labwc/autostart /etc/xdg/labwc/autostart > /dev/null 2>&1; then
            echo "  ⚠ WARNING: User autostart is IDENTICAL to system autostart"
            echo "  This can cause duplicate panels."
            echo "  Run: rm ~/.config/labwc/autostart"
        fi
    fi
else
    echo "  User autostart: NOT FOUND (OK - using system default)"
fi

echo "  System autostart: $([ -f /etc/xdg/labwc/autostart ] && echo 'EXISTS' || echo 'NOT FOUND')"

# Check for Pimarchy services
echo ""
echo "[3/4] Checking for Pimarchy services..."
waybar_running=$(pgrep -x waybar 2>/dev/null | wc -l)
mako_running=$(pgrep -x mako 2>/dev/null | wc -l)

if [ "$waybar_running" -gt 0 ]; then
    echo "  Waybar: RUNNING ($waybar_running process(es))"
else
    echo "  Waybar: NOT RUNNING"
fi

if [ "$mako_running" -gt 0 ]; then
    echo "  Mako: RUNNING ($mako_running process(es))"
else
    echo "  Mako: NOT RUNNING"
fi

# Check backups
echo ""
echo "[4/4] Checking backups..."
if [ -d ~/.config/Pimarchy-backup ]; then
    echo "  Backup directory: EXISTS"
    if [ -f ~/.config/Pimarchy-backup/.original-backup ]; then
        echo "  Original backup marker: PRESENT"
    else
        echo "  Original backup marker: NOT FOUND"
    fi
    echo "  Backup contents:"
    ls -1 ~/.config/Pimarchy-backup/ | sed 's/^/    - /'
else
    echo "  Backup directory: NOT FOUND"
fi

echo ""
echo "=== Diagnostic Complete ==="
