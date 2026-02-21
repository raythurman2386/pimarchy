# Desktop Interface

Pimarchy provides a modern, high-performance desktop environment based on **Wayland**.

## Components

The desktop is made of several key components working together:

### 1. Hyprland (Compositor)
Hyprland is a dynamic tiling window manager.
-   **Tiling:** New windows automatically divide the screen space.
-   **Floating:** You can toggle a window to "float" above others with **SUPER + V**.
-   **Workspaces:** You have 10 virtual desktops (workspaces) accessible via **SUPER + 1–0**.

### 2. Waybar (Status Bar)
Located at the top of your screen, Waybar shows:
-   **Workspaces:** Current active and occupied workspaces.
-   **Clock & Date:** Click to toggle format.
-   **System Stats:** CPU, Memory, and Disk usage.
-   **Networking:** Current Wi-Fi or Ethernet status.
-   **Volume:** Audio level and mute status.

### 3. Rofi (Launcher)
When you press **SUPER + D**, the Rofi launcher appears. Simply start typing to find and launch applications.

### 4. Mako (Notifications)
Notifications appear in the top-right corner. You can dismiss them by clicking.

### 5. Thunar (File Manager)
A lightweight but powerful file manager that supports icons, thumbnails, and network drives.

---

## Visuals & Animations

Pimarchy includes several visual enhancements by default:
-   **Gaps:** Small spaces between windows for a cleaner look.
-   **Rounded Corners:** Windows have a slight rounding (configurable).
-   **Drop Shadows:** Windows cast shadows on the desktop background.
-   **Animations:** Smooth sliding and fading when switching workspaces or opening windows.

## Background

Pimarchy uses `swaybg` to set the desktop wallpaper. The default Ravenwood wallpaper is located at `~/.config/hypr/background.jpg`.
