#!/bin/bash
#
# Pimarchy screenshot helper
# Usage: screenshot.sh [region|full]
#
# Saves a PNG to ~/Pictures/Screenshots/ with a timestamp and also copies
# the image to the Wayland clipboard.  Requires grim, slurp, wl-copy.
#
set -e

MODE="${1:-region}"
SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT="$SCREENSHOTS_DIR/screenshot-${TIMESTAMP}.png"

mkdir -p "$SCREENSHOTS_DIR"

case "$MODE" in
    full)
        grim "$OUTPUT"
        ;;
    region)
        REGION="$(slurp)" || exit 0   # exit 0 so cancelling the selection is silent
        grim -g "$REGION" "$OUTPUT"
        ;;
    *)
        echo "Usage: $0 [region|full]" >&2
        exit 1
        ;;
esac

# Copy to clipboard
wl-copy < "$OUTPUT"

# Optional desktop notification (mako must be running)
if command -v notify-send &>/dev/null; then
    notify-send "Screenshot saved" "$OUTPUT" --icon=image-png 2>/dev/null || true
fi
