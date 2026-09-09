# Keybinds & Shortcuts

Pimarchy is built for a keyboard-driven workflow. Master these keybinds to navigate your system efficiently.

Keybinds live in `~/.config/hypr/bindings.lua` (required by `hyprland.lua`) and respect the [default app policy](../development/defaults.md) — changing `pimarchy default browser` or `pimarchy default filemanager` changes Super+Shift+B / Super+E after the next install/update.

## General Navigation

| Shortcut | Action | Description |
|----------|--------|-------------|
| **SUPER + Return** | **Terminal** | Open the default terminal (**Foot**). |
| **SUPER + D** | **Launcher** | Open **Rofi** app launcher. |
| **SUPER + W** | **Close** | Close the focused window. |
| **SUPER + E** | **File Manager** | Open the default file manager (**Pifile**). |
| **SUPER + M** | **System Monitor** | Open **btop** system monitor. |
| **SUPER + SHIFT + B** | **Browser** | Launch the default browser (**Chromium**). |
| **SUPER + SHIFT + CTRL + A** | **Coding Agent** | Launch the default coding agent (**Raven**, `pimarchy agent`) in a floating TUI window (`org.pimarchy.agent`). |
| **SUPER + CTRL + Q** | **Calculator** | Open **Picalc** as a floating calculator window. |
| **XF86Calculator** | **Calculator** | Same as Super+Ctrl+Q (calculator key, if present). |
| **SUPER + K** | **Keybind Viewer** | View all active keybinds in **Rofi**. |

## Window Management

| Shortcut | Action | Description |
|----------|--------|-------------|
| **SUPER + F** | **Fullscreen** | Toggle fullscreen on the focused window. |
| **SUPER + V** | **Float** | Toggle floating mode for the focused window. |
| **SUPER + Arrow keys** | **Focus** | Move focus between windows. |
| **SUPER + SHIFT + Arrows** | **Move** | Move the focused window within the layout. |
| **SUPER + 1–0** | **Workspace** | Switch to workspaces 1 through 10. |
| **SUPER + SHIFT + 1–0** | **Move to Workspace** | Move the focused window to a specific workspace. |
| **SUPER + TAB** | **Next Workspace** | Cycle to the next workspace. |
| **SUPER + SHIFT + TAB** | **Previous Workspace** | Cycle to the previous workspace. |

## Screen Capture

| Shortcut | Action | Description |
|----------|--------|-------------|
| **Print** | **Region** | Select a region of the screen to capture. |
| **SHIFT + Print** | **Fullscreen** | Capture the entire screen. |

!!! info "Saved Location"
    All screenshots are automatically saved to `~/Pictures/Screenshots/` as PNG files.

## Audio & Media

| Shortcut | Action | Description |
|----------|--------|-------------|
| **XF86AudioRaiseVolume** | **Volume Up** | Increase system volume by 5%. |
| **XF86AudioLowerVolume** | **Volume Down** | Decrease system volume by 5%. |
| **XF86AudioMute** | **Mute** | Toggle audio mute. |

These are the standard laptop/media keyboard keys; most keyboards map them to F10–F12 with an Fn modifier.

---

## Power Menu

Click the power icon in the **Waybar** to open the Rofi-based power menu:

-   **Shutdown:** Power off the system.
-   **Reboot:** Restart the system.
-   **Logout:** Exit the Hyprland session and return to Tuigreet.
-   **Suspend:** Put the system to sleep.