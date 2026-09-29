# Desktop Interface

Pimarchy provides a modern, high-performance desktop environment based on **Wayland** (Xwayland is disabled).

## Components

The desktop is made of several key components working together:

### 1. Hyprland (Compositor)
Hyprland is a dynamic tiling window manager. Config is Lua (`~/.config/hypr/hyprland.lua` + `bindings.lua`).
-   **Tiling:** New windows automatically divide the screen space.
-   **Floating:** You can toggle a window to "float" above others with **SUPER + V**.
-   **Workspaces:** You have 10 virtual desktops (workspaces) accessible via **SUPER + 1–0**.

### 2. Waybar (Status Bar)
Located at the top of your screen, Waybar shows:
-   **Workspaces:** Current active and occupied workspaces (click a chip to focus it).
-   **Clock & Date:** Click to toggle format.
-   **System Stats:** Memory (click to open btop).
-   **Networking:** Wi-Fi or Ethernet status (right-click → nmtui).
-   **Bluetooth / Volume / Power:** See [Waybar Actions](waybar.md).

### 3. Rofi (Launcher)
When you press **SUPER + D**, the Rofi launcher appears. Simply start typing to find and launch applications. The package is **sid rofi 2** (Wayland); Trixie rofi 1.7 is not used.

### 4. Mako (Notifications)
Notifications appear in the top-right corner. You can dismiss them by clicking.

### 5. Pifile (File Manager)
Keyboard-first file manager. **SUPER + E** opens it; folders opened from other apps use Pifile via the `inode/directory` MIME default.

---

## Visuals & Animations

Pimarchy tunes visuals for the Pi 5 (VideoCore):
-   **Gaps:** Small spaces between windows (`GAPS_IN` / `GAPS_OUT` in `theme.conf`).
-   **No rounding, blur, or shadows:** `CORNER_RADIUS=0`; blur and shadows stay disabled for cost.
-   **Animations:** Window open/close animations are on; the expensive **workspace** animation stays off so switching workspaces remains instant.

## Background

Pimarchy uses `swaybg` (systemd user service under `graphical-session.target`, not Hyprland `exec-once`) to set the desktop wallpaper. The default Ravenwood wallpaper is located at `~/.config/hypr/background.jpg`.
