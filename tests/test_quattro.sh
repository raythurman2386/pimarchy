#!/bin/bash
#
# Quattro functional tests — sandboxed.
#
# Exercises lib/defaults.sh, lib/packages.sh, lib/upgrade.sh, and the
# bin wrappers without touching the real $HOME or needing sudo/network.
# Any test failure exits non-zero (validate.sh depends on this).
#

set -u

# ── Sandbox setup ────────────────────────────────────────────────────────────
export PIMARCHY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PIMARCHY_ROOT="$PIMARCHY_DIR"

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"
# Keep the sandbox airtight on machines that set XDG_CONFIG_HOME (the
# wrappers and lib/common.sh both resolve user config through it)
export XDG_CONFIG_HOME="$HOME/.config"
unset XDG_DATA_HOME XDG_STATE_HOME 2>/dev/null || true

FAILURES=0
CURRENT_TEST=""

pass() { echo "  ✓ $CURRENT_TEST"; }
fail() {
    echo "  ✗ $CURRENT_TEST: $1"
    FAILURES=$((FAILURES + 1))
}

# run_test <name> <fn>
run_test() {
    CURRENT_TEST="$1"
    "$2"
}

# Source the library against the sandbox HOME
source "$PIMARCHY_DIR/lib/functions.sh"

# ── Package list parsing ─────────────────────────────────────────────────────

test_read_package_list_filters_comments() {
    local lines
    lines=$(read_package_list core)
    if echo "$lines" | grep -qE '^[[:space:]]*(#|$)'; then
        fail "comments/blanks leaked into output"
    elif [ -z "$lines" ]; then
        fail "no lines returned for core"
    else
        pass
    fi
}

test_list_apt_packages() {
    local pkgs
    pkgs=$(list_apt_packages core apt)
    for expected in foot chromium jq fonts-dejavu-core mesa-vulkan-drivers \
                    libspa-0.2-bluetooth dconf-cli gsettings-desktop-schemas \
                    pipewire-pulse xdg-desktop-portal-gtk libnotify-bin qt5ct git; do
        echo "$pkgs" | grep -qx "$expected" || { fail "missing apt: package '$expected'"; return; }
    done
    echo "$pkgs" | grep -qx "network-manager" \
        || { fail "missing apt: package 'network-manager'"; return; }
    echo "$pkgs" | grep -qx "thunar" && { fail "thunar should not be in core apt"; return; }
    echo "$pkgs" | grep -qx "blueman" && { fail "blueman should not be in core apt"; return; }
    echo "$pkgs" | grep -qx "network-manager-gnome" \
        && { fail "network-manager-gnome should not be in core apt"; return; }
    echo "$pkgs" | grep -qx "rofi" \
        && { fail "trixie rofi is X11; launcher must come from sid"; return; }
    pass
}

test_list_sid_packages() {
    local pkgs
    pkgs=$(list_apt_packages core sid)
    for expected in hyprland waybar mako-notifier uwsm rofi; do
        echo "$pkgs" | grep -qx "$expected" || { fail "missing sid: package '$expected'"; return; }
    done
    # apt entries must not leak into the sid set
    echo "$pkgs" | grep -qx "foot" && { fail "apt package foot leaked into sid set"; return; }
    pass
}

test_list_script_labels() {
    local labels
    labels=$(list_script_labels core)
    for expected in zed pifile; do
        echo "$labels" | grep -qx "$expected" || { fail "missing core script: label '$expected'"; return; }
    done
    echo "$labels" | grep -qx "raven" && { fail "raven should be in ai module, not core"; return; }
    labels=$(list_script_labels ai)
    for expected in raven ollama; do
        echo "$labels" | grep -qx "$expected" || { fail "missing ai script: label '$expected'"; return; }
    done
    pass
}

test_dev_list_contents() {
    # Rust in dev via rustup script, node, go, python, docker, gh in core
    local scripts pkgs
    scripts=$(list_script_labels dev)
    pkgs=$(list_apt_packages dev apt)
    echo "$scripts" | grep -qx "rustup" || { fail "dev.list missing script:rustup"; return; }
    echo "$scripts" | grep -qx "cargo-config" || { fail "dev.list missing script:cargo-config"; return; }
    echo "$scripts" | grep -qx "node" || { fail "dev.list missing script:node"; return; }
    echo "$scripts" | grep -qx "go" || { fail "dev.list missing script:go"; return; }
    echo "$pkgs" | grep -qx "docker-ce" || { fail "dev.list missing apt:docker-ce"; return; }
    echo "$pkgs" | grep -qx "mold" || { fail "dev.list missing apt:mold (cargo linker)"; return; }
    for expected in libfontconfig-dev libwayland-dev clang libvulkan-dev; do
        echo "$pkgs" | grep -qx "$expected" \
            || { fail "dev.list missing GPUI build dep '$expected'"; return; }
    done
    # X11 headers must be sid: — core's Hyprland stack (-t sid) installs sid's
    # libxcb1/libxkbcommon runtimes; -dev packages strictly version-match (=)
    # their runtime, so Trixie/RPi-repo headers break the apt transaction.
    local sid_pkgs
    sid_pkgs=$(list_apt_packages dev sid)
    for expected in libxkbcommon-dev libxkbcommon-x11-dev libxcb1-dev libx11-xcb-dev; do
        echo "$sid_pkgs" | grep -qx "$expected" \
            || { fail "dev.list missing sid:X11 header '$expected'"; return; }
    done
    # rustup must NOT be an apt entry (it's not in Debian repos)
    echo "$pkgs" | grep -qx "rustup" && { fail "rustup should be script:, not apt:"; return; }
    # gh is a core package (always installed), so not required in dev
    pass
}

test_cargo_config_template_renders_absolute_home() {
    # cargo does not expand '~' in config files; the shipped template must
    # render to an absolute target-dir path.
    local tmp
    tmp=$(mktemp)
    process_template "$PIMARCHY_ROOT/config/cargo/config.toml.template" "$tmp" >/dev/null 2>&1 \
        || { fail "cargo config template failed to render"; rm -f "$tmp"; return; }
    if grep -q 'target-dir = "~' "$tmp"; then
        fail "cargo target-dir must be absolute (cargo does not expand ~)"
    elif ! grep -qE "target-dir = \"$HOME/.cache/cargo-target\"" "$tmp"; then
        fail "rendered target-dir != $HOME/.cache/cargo-target"
    fi
    rm -f "$tmp"
    pass
}

test_cargo_config_hook_installs_and_preserves_user_edits() {
    local cargo_config="$HOME/.cargo/config.toml"
    local rendered
    rendered=$(mktemp)
    process_template "$PIMARCHY_ROOT/config/cargo/config.toml.template" "$rendered" >/dev/null

    # Stub mold on PATH: the hook refuses to install the config without it
    # (a mold-pointing config with no mold binary breaks every build).
    local stub_dir="$SANDBOX/stub-bin"
    mkdir -p "$stub_dir"
    printf '#!/bin/sh\nexit 0\n' > "$stub_dir/mold"
    chmod +x "$stub_dir/mold"
    local saved_path="$PATH"
    PATH="$stub_dir:$PATH"

    # First run installs
    configure_cargo_build_config >/dev/null 2>&1 \
        || { fail "configure_cargo_build_config failed on first run"; PATH="$saved_path"; return; }
    if ! diff -q "$cargo_config" "$rendered" >/dev/null; then
        fail "installed config does not match rendered template"
        PATH="$saved_path"
        return
    fi

    # Second run refreshes a pristine file
    configure_cargo_build_config >/dev/null 2>&1 \
        || { fail "configure_cargo_build_config failed on pristine re-run"; PATH="$saved_path"; return; }
    grep -q "mold" "$cargo_config" || { fail "pristine re-run lost mold linker config"; PATH="$saved_path"; return; }

    # User edit is left untouched
    echo "# my tweak" >> "$cargo_config"
    if configure_cargo_build_config 2>&1 | grep -q "User-modified, leaving untouched"; then
        grep -q "my tweak" "$cargo_config" || { fail "user edit was clobbered"; PATH="$saved_path"; return; }
    else
        fail "user-modified cargo config was overwritten"
    fi
    PATH="$saved_path"
    rm -f "$rendered"
    pass
}

test_unknown_module_errors() {
    if read_package_list nonexistent 2>/dev/null; then
        fail "unknown module should error"
    else
        pass
    fi
}

# ── Default app policy ────────────────────────────────────────────────────────

test_defaults_defaults() {
    [ "$(defaults_default_for agent)" = "raven" ] || { fail "agent default != raven"; return; }
    [ "$(defaults_default_for editor)" = "zed" ] || { fail "editor default != zed"; return; }
    [ "$(defaults_default_for terminal)" = "foot" ] || { fail "terminal default != foot"; return; }
    [ "$(defaults_default_for browser)" = "chromium" ] || { fail "browser default != chromium"; return; }
    [ "$(defaults_default_for filemanager)" = "pifile" ] || { fail "filemanager default != pifile"; return; }
    pass
}

test_defaults_set_and_read() {
    defaults_set editor zed >/dev/null || { fail "defaults_set failed"; return; }
    [ "$(defaults_read editor)" = "zed" ] || { fail "read after set != zed"; return; }
    pass
}

test_defaults_reject_unknown() {
    if defaults_set agent "evil; rm -rf /" 2>/dev/null; then
        fail "defaults_set accepted an invalid agent (command injection)"
    else
        pass
    fi
}

test_defaults_read_falls_back() {
    # Corrupted agent file must fall back to raven, not crash or exec junk
    mkdir -p "$PIMARCHY_DEFAULTS_DIR"
    echo 'agent=$(reboot)' > "$PIMARCHY_DEFAULTS_DIR/agent"
    local value
    value=$(defaults_read agent)
    [ "$value" = "raven" ] || { fail "corrupt agent file did not fall back to raven (got '$value')"; return; }
    pass
}

test_defaults_install_preserves_user_choice() {
    defaults_install_defaults >/dev/null
    defaults_set agent raven >/dev/null
    defaults_install_defaults >/dev/null
    [ "$(defaults_read agent)" = "raven" ] || { fail "reinstall overwrote user choice"; return; }
    pass
}

# ── Safe upgrade model ────────────────────────────────────────────────────────

test_upgrade_hash_pristine_vs_modified() {
    local target="$HOME/config/hypr/hyprland.lua"
    mkdir -p "$(dirname "$target")"

    # 1. Install a pristine file and record its hash
    echo "pristine-content-v1" > "$target"
    record_installed_hash "$target"
    [ -n "$(manifest_lookup "$target")" ] || { fail "manifest_lookup empty after record"; return; }

    # 2. Pristine file (hash matches) → safe upgrade overwrites
    install_module_target "hypr/hyprland.lua.template" "$target" "safe" >/dev/null 2>&1 || true
    grep -q "Pimarchy Hyprland Configuration" "$target" || { fail "pristine file was not refreshed"; return; }

    # 3. User-modified file → safe upgrade leaves untouched.
    #    (The manifest still holds the install-time hash; user edits are
    #    never recorded — that mismatch is what marks the file as modified.)
    echo "# my custom edits" > "$target"
    install_module_target "hypr/hyprland.lua.template" "$target" "safe" >/dev/null 2>&1 || true
    grep -q "# my custom edits" "$target" || { fail "user-modified file was clobbered"; return; }

    # 4. File with no manifest entry (pre-Quattro / user file) → untouched in safe mode
    rm -f "$PIMARCHY_MANIFEST_FILE"
    install_module_target "hypr/hyprland.lua.template" "$target" "safe" >/dev/null 2>&1 || true
    grep -q "# my custom edits" "$target" || { fail "un-manifested file was clobbered in safe mode"; return; }

    # 5. Force mode (install.sh path) always overwrites and records the new hash
    install_module_target "hypr/hyprland.lua.template" "$target" "force" >/dev/null 2>&1 || true
    grep -q "Pimarchy Hyprland Configuration" "$target" || { fail "force mode did not overwrite"; return; }
    [ -n "$(manifest_lookup "$target")" ] || { fail "force mode did not record hash"; return; }
    pass
}

test_upgrade_missing_file_installs() {
    local target="$HOME/config/waybar/config.jsonc"
    rm -f "$target"
    install_module_target "waybar/config.jsonc.template" "$target" "safe" >/dev/null 2>&1 || true
    [ -f "$target" ] || { fail "missing file was not installed"; return; }
    grep -q '"temperature"' "$target" && { fail "waybar still ships a temperature module"; return; }
    grep -q 'pimarchy-workspace' "$target" || { fail "waybar missing workspace helper"; return; }
    grep -q 'hyprland/workspaces' "$target" && { fail "waybar still uses hyprland/workspaces"; return; }
    pass
}

test_retired_files_cleanup() {
    local retired="$HOME/.config/chromium-flags.conf"
    mkdir -p "$(dirname "$retired")"
    echo "stale" > "$retired"
    remove_retired_files
    [ ! -e "$retired" ] || { fail "retired file still exists after remove_retired_files"; return; }
    [ ! -e "${retired}.pimarchy-upgrade.bak" ] || { fail "upgrade.bak leftover not removed"; return; }
    pass
}

# ── Wrappers (non-network paths only) ─────────────────────────────────────────

test_agent_wrapper_reads_default() {
    # Restrict PATH so a machine-local raven cannot be exec'd (which would
    # replace this test process). Missing-binary messaging is the contract.
    local out
    out=$(PATH="/usr/bin:/bin" bash "$PIMARCHY_DIR/bin/pimarchy-agent" --inline 2>&1) || true
    echo "$out" | grep -q "Raven not installed" \
        || { fail "missing-raven message wrong: $out"; return; }
    grep -q "org.pimarchy.agent" "$PIMARCHY_DIR/bin/pimarchy-agent" \
        || { fail "agent wrapper missing org.pimarchy.agent app-id"; return; }
    grep -q -- "--inline" "$PIMARCHY_DIR/bin/pimarchy-agent" \
        || { fail "agent wrapper missing --inline"; return; }
    pass
}

test_default_agent_wrapper_validates() {
    local out
    out=$(bash "$PIMARCHY_DIR/bin/pimarchy-default-agent" bogus-name 2>&1) || true
    echo "$out" | grep -q "Usage" || { fail "invalid agent not rejected with usage: $out"; return; }
    out=$(bash "$PIMARCHY_DIR/bin/pimarchy-default-agent" 2>&1) || true
    echo "$out" | grep -q "Usage" || { fail "missing arg not rejected with usage: $out"; return; }
    pass
}

test_default_agent_wrapper_writes_file() {
    # Raven is installed on this machine (dev box) or not (Pi) — either way
    # the file write happens first; the lazy install only runs when missing.
    # We cannot hit the network in tests, so accept both paths.
    if command -v raven >/dev/null 2>&1; then
        bash "$PIMARCHY_DIR/bin/pimarchy-default-agent" raven >/dev/null 2>&1 || true
        [ "$(sed -n 's/^agent=//p' "$PIMARCHY_DEFAULTS_DIR/agent")" = "raven" ] \
            || { fail "agent file not written"; return; }
    else
        # Without raven installed the wrapper tries to install (network) — skip
        pass
    fi
    pass
}

test_pimarchy_install_usage() {
    local out
    out=$(bash "$PIMARCHY_DIR/bin/pimarchy-install" 2>&1) || true
    echo "$out" | grep -qi "usage" || { fail "no usage message: $out"; return; }
    out=$(bash "$PIMARCHY_DIR/bin/pimarchy-install" bogus 2>&1) || true
    echo "$out" | grep -qi "no list for module" || { fail "unknown module message wrong: $out"; return; }
    pass
}

test_bindings_template_renders() {
    # The bindings template must reference all DEFAULT_* vars and render
    defaults_export_vars
    local out="$SANDBOX/bindings-rendered"
    process_template "$PIMARCHY_DIR/config/hypr/bindings.lua.template" "$out" >/dev/null
    for var in DEFAULT_TERMINAL DEFAULT_BROWSER DEFAULT_EDITOR DEFAULT_AGENT DEFAULT_FILEMANAGER; do
        local value
        value="${!var}"
        grep -q "$value" "$out" || { fail "rendered bindings missing $var value"; return; }
    done
    # No unresolved placeholders remain
    grep -q "{{" "$out" && { fail "unresolved {{VARS}} left in rendered bindings"; return; }
    # Agent binding present
    grep -q "Coding Agent" "$out" || { fail "agent binding missing"; return; }
    grep -q "Calculator" "$out" || { fail "calculator binding missing"; return; }
    grep -q "picalc" "$out" || { fail "picalc launch missing from bindings"; return; }
    grep -q "thunar" "$out" && { fail "bindings still launch thunar"; return; }
    pass
}

test_hyprland_conf_sources_bindings() {
    defaults_export_vars
    local out="$SANDBOX/hyprland-rendered"
    process_template "$PIMARCHY_DIR/config/hypr/hyprland.lua.template" "$out" >/dev/null
    grep -q 'require("hypr.bindings")' "$out" || { fail "hyprland.lua no longer requires bindings.lua"; return; }
    grep -qF 'org\\.pimarchy\\.agent' "$out" || { fail "agent windowrule missing"; return; }
    grep -qF 'picalc' "$out" || { fail "picalc windowrule missing"; return; }
    grep -qF 'bluetoothctl' "$out" || { fail "bluetoothctl windowrule missing"; return; }
    # Lua format sanity: no hyprlang-only syntax leaked in
    grep -qE "^\s*(exec-once|source)\s*=" "$out" && { fail "hyprlang syntax found in Lua config"; return; }
    pass
}

# fw_same <tmp> <label> — fail when config.txt or cmdline.txt differ from the
# snapshots taken by fw_snap.
fw_snap() {
    FW_CFG="$(cat "$1/config.txt")"
    FW_CMD="$(cat "$1/cmdline.txt")"
}

fw_same() {
    local tmp="$1"
    local label="$2"
    local cfg cmd
    cfg="$(cat "$tmp/config.txt")"
    cmd="$(cat "$tmp/cmdline.txt")"
    if [ "$cfg" != "$FW_CFG" ] || [ "$cmd" != "$FW_CMD" ]; then
        fail "$label changed boot files"
        echo "    config: [$cfg]"
        echo "    cmdline: [$cmd]"
        rm -rf "$tmp"
        return 1
    fi
}

fw_run() {
    local tmp="$1"
    shift
    if ! bash "$PIMARCHY_DIR/lib/pi-firmware.sh" "$@" "$tmp"; then
        fail "pi-firmware.sh $* failed"
        rm -rf "$tmp"
        return 1
    fi
}

test_link_user_unit() {
    # shellcheck disable=SC1091
    source "$PIMARCHY_DIR/lib/functions.sh"
    local dir="$HOME/.config/systemd/user"
    mkdir -p "$dir"
    cat > "$dir/swaybg.service" <<'EOF'
[Install]
WantedBy=graphical-session.target
EOF
    unset XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS
    link_user_unit swaybg.service
    [ -L "$dir/graphical-session.target.wants/swaybg.service" ] \
        || { fail "swaybg was not enabled"; return; }
    [ "$(readlink "$dir/graphical-session.target.wants/swaybg.service")" = "../swaybg.service" ] \
        || { fail "swaybg symlink target is wrong"; return; }
    pass
}

test_wifi_country_cmdline() {
    local tmp line
    tmp=$(mktemp -d)
    mkdir -p "$tmp/boot" "$tmp/root/var/lib/systemd/rfkill"
    printf 'console=tty1 rootwait\n' > "$tmp/boot/cmdline.txt"
    printf '1\n' > "$tmp/root/var/lib/systemd/rfkill/platform-test:wlan"
    bash "$PIMARCHY_DIR/image/wifi-country.sh" --root "$tmp/root" \
        --boot "$tmp/boot" us || { fail "wifi-country failed"; rm -rf "$tmp"; return; }
    line=$(cat "$tmp/boot/cmdline.txt")
    printf '%s' "$line" | grep -q 'cfg80211.ieee80211_regdom=US' \
        || { fail "regdom missing ($line)"; rm -rf "$tmp"; return; }
    [ "$(cat "$tmp/root/var/lib/systemd/rfkill/platform-test:wlan")" = "0" ] \
        || { fail "wlan rfkill stayed blocked"; rm -rf "$tmp"; return; }
    bash "$PIMARCHY_DIR/image/wifi-country.sh" --root "$tmp/root" \
        --boot "$tmp/boot" GB || { fail "second country failed"; rm -rf "$tmp"; return; }
    grep -q 'cfg80211.ieee80211_regdom=GB' "$tmp/boot/cmdline.txt" \
        || { fail "regdom was not replaced"; rm -rf "$tmp"; return; }
    rm -rf "$tmp"
    pass
}

test_dev_root_resolve() {
    local tmp spec
    tmp=$(mktemp -d)
    printf '/dev/nvme0n1p2 / ext4 rw 0 0\n' > "$tmp/mounts"
    printf 'root=PARTUUID=abc console=tty1\n' > "$tmp/cmd"
    spec=$(bash "$PIMARCHY_DIR/lib/ensure-dev-root.sh" --resolve \
        "$tmp/mounts" "$tmp/cmd")
    [ "$spec" = "/dev/nvme0n1p2" ] \
        || { fail "kept real root device ($spec)"; rm -rf "$tmp"; return; }

    printf '/dev/root / ext4 rw 0 0\n' > "$tmp/mounts"
    spec=$(bash "$PIMARCHY_DIR/lib/ensure-dev-root.sh" --resolve \
        "$tmp/mounts" "$tmp/cmd")
    [ "$spec" = "/dev/disk/by-partuuid/abc" ] \
        || { fail "PARTUUID ($spec)"; rm -rf "$tmp"; return; }

    printf 'console=tty1 root=/dev/mmcblk0p2 rootwait\n' > "$tmp/cmd"
    spec=$(bash "$PIMARCHY_DIR/lib/ensure-dev-root.sh" --resolve \
        "$tmp/mounts" "$tmp/cmd")
    [ "$spec" = "/dev/mmcblk0p2" ] \
        || { fail "cmdline device ($spec)"; rm -rf "$tmp"; return; }

    printf 'root=UUID=deadbeef rootwait\n' > "$tmp/cmd"
    spec=$(bash "$PIMARCHY_DIR/lib/ensure-dev-root.sh" --resolve \
        "$tmp/mounts" "$tmp/cmd")
    [ "$spec" = "/dev/disk/by-uuid/deadbeef" ] \
        || { fail "UUID ($spec)"; rm -rf "$tmp"; return; }

    rm -rf "$tmp"
    pass
}

test_pi_firmware_tuning() {
    local tmp count
    local oc_comment old_oc gen3_comment cam_comment
    oc_comment="# Pimarchy: Pi 5 overclock arm_freq=2600 (stock 2400; firmware scales voltage)"
    old_oc="# Pimarchy: Pi 5 mild overclock (2600 MHz, no extra voltage required)"
    gen3_comment="# Pimarchy: NVMe at PCIe Gen 3 (drive trains at 8 GT/s)"
    cam_comment="# Pimarchy: Pi 500 has no camera"
    tmp=$(mktemp -d)

    # Default path is a no-op, including a second run.
    printf 'camera_auto_detect=1\n[all]\nuart_2ndstage=1\n' > "$tmp/config.txt"
    printf 'console=tty1 rootwait\n' > "$tmp/cmdline.txt"
    fw_snap "$tmp"
    fw_run "$tmp" || return
    fw_same "$tmp" "default apply" || return
    fw_run "$tmp" || return
    fw_same "$tmp" "second default apply" || return
    grep -q 'dtparam=pciex1_gen' "$tmp/config.txt" \
        && { fail "default path wrote a PCIe generation"; rm -rf "$tmp"; return; }
    grep -q 'cma=' "$tmp/cmdline.txt" \
        && { fail "default path wrote cma="; rm -rf "$tmp"; return; }

    # Existing cma= and an explicit Gen 2 line stay on apply and revert.
    printf 'camera_auto_detect=1\n[all]\ndtparam=pciex1_gen=2\n' > "$tmp/config.txt"
    printf 'console=tty1 rootwait cma=256M\n' > "$tmp/cmdline.txt"
    fw_snap "$tmp"
    fw_run "$tmp" || return
    fw_same "$tmp" "existing cma and gen2 apply" || return
    fw_run "$tmp" --revert || return
    fw_same "$tmp" "existing cma and gen2 revert" || return
    printf 'console=tty1 rootwait cma=64M\n' > "$tmp/cmdline.txt"
    fw_snap "$tmp"
    fw_run "$tmp" --revert || return
    fw_same "$tmp" "cma=64M revert" || return
    printf 'console=tty1 rootwait cma=128M\n' > "$tmp/cmdline.txt"
    fw_snap "$tmp"
    fw_run "$tmp" --revert || return
    fw_same "$tmp" "cma=128M revert" || return

    # No exact [all] section: do not append one, and do not add Gen 3.
    printf 'dtparam=uart0=1\ncamera_auto_detect=1\n' > "$tmp/config.txt"
    printf 'console=tty1 rootwait\n' > "$tmp/cmdline.txt"
    fw_snap "$tmp"
    fw_run "$tmp" || return
    fw_same "$tmp" "missing [all] apply" || return

    # camera_auto_detect=0 with and without the old comment stays 0.
    printf '%s\ncamera_auto_detect=0\n' "$cam_comment" > "$tmp/config.txt"
    printf 'console=tty1 rootwait\n' > "$tmp/cmdline.txt"
    fw_run "$tmp" || return
    grep -qx 'camera_auto_detect=0' "$tmp/config.txt" \
        || { fail "apply rewrote camera already 0"; rm -rf "$tmp"; return; }
    fw_run "$tmp" --revert || return
    grep -qx 'camera_auto_detect=0' "$tmp/config.txt" \
        || { fail "revert forced camera_auto_detect=1"; rm -rf "$tmp"; return; }
    grep -q 'Pi 500 has no camera' "$tmp/config.txt" \
        && { fail "camera comment survived revert"; rm -rf "$tmp"; return; }

    printf 'camera_auto_detect=0\n[all]\nuart_2ndstage=1\n' > "$tmp/config.txt"
    printf 'console=tty1 rootwait\n' > "$tmp/cmdline.txt"
    fw_snap "$tmp"
    fw_run "$tmp" || return
    fw_same "$tmp" "camera 0 without comment apply" || return
    fw_run "$tmp" --revert || return
    fw_same "$tmp" "camera 0 without comment revert" || return

    # User-owned Gen 3, arm_freq, and a non-trailing cma=512M survive revert.
    printf 'camera_auto_detect=0\n[all]\ndtparam=pciex1_gen=3\narm_freq=2400\narm_freq=2600\n' \
        > "$tmp/config.txt"
    printf 'cma=512M rootwait\ncma=256M\n' > "$tmp/cmdline.txt"
    fw_snap "$tmp"
    fw_run "$tmp" --revert || return
    fw_same "$tmp" "user-owned boot lines" || return
    fw_run "$tmp" --overclock || return
    count=$(grep -c '^arm_freq=' "$tmp/config.txt")
    [ "$count" = 2 ] \
        || { fail "overclock edited a file that already set arm_freq"; rm -rf "$tmp"; return; }

    # Owned Gen 3 inserted under an existing [all], plus a trailing cma=512M.
    printf 'camera_auto_detect=1\n[all]\n%s\ndtparam=pciex1_gen=3\nuart_2ndstage=1\n' \
        "$gen3_comment" > "$tmp/config.txt"
    printf 'console=tty1 rootwait cma=512M\n' > "$tmp/cmdline.txt"
    fw_run "$tmp" --revert || return
    grep -q 'pciex1_gen' "$tmp/config.txt" \
        && { fail "owned Gen 3 line survived revert"; rm -rf "$tmp"; return; }
    grep -qx '\[all\]' "$tmp/config.txt" \
        || { fail "existing [all] was dropped"; rm -rf "$tmp"; return; }
    grep -qx 'uart_2ndstage=1' "$tmp/config.txt" \
        || { fail "line under [all] was dropped"; rm -rf "$tmp"; return; }
    grep -qx 'camera_auto_detect=1' "$tmp/config.txt" \
        || { fail "camera_auto_detect=1 was rewritten"; rm -rf "$tmp"; return; }
    grep -q 'cma=512M' "$tmp/cmdline.txt" \
        && { fail "trailing cma=512M survived revert"; rm -rf "$tmp"; return; }
    grep -qx 'console=tty1 rootwait' "$tmp/cmdline.txt" \
        || { fail "cmdline suffix strip damaged the line"; rm -rf "$tmp"; return; }

    # Owned Gen 3 that appended its own [all]: drop that header too.
    printf 'uart_2ndstage=1\n\n[all]\n%s\ndtparam=pciex1_gen=3\n' \
        "$gen3_comment" > "$tmp/config.txt"
    printf 'cma=512M\n' > "$tmp/cmdline.txt"
    fw_run "$tmp" --revert || return
    grep -q '\[all\]' "$tmp/config.txt" \
        && { fail "appended [all] survived revert"; rm -rf "$tmp"; return; }
    grep -q 'pciex1_gen' "$tmp/config.txt" \
        && { fail "appended Gen 3 survived revert"; rm -rf "$tmp"; return; }
    grep -qx 'uart_2ndstage=1' "$tmp/config.txt" \
        || { fail "pre-existing line was dropped with appended [all]"; rm -rf "$tmp"; return; }
    grep -q 'cma=' "$tmp/cmdline.txt" \
        && { fail "bare cma=512M line survived revert"; rm -rf "$tmp"; return; }

    # A second revert is a no-op.
    fw_snap "$tmp"
    fw_run "$tmp" --revert || return
    fw_same "$tmp" "second revert" || return

    # Opt-in overclock under an existing [all], then revert keeps the section.
    printf 'camera_auto_detect=1\n[all]\nuart_2ndstage=1\n' > "$tmp/config.txt"
    printf 'console=tty1 rootwait cma=256M\n' > "$tmp/cmdline.txt"
    fw_run "$tmp" --overclock || return
    fw_run "$tmp" --overclock || return
    count=$(grep -c '^arm_freq=2600$' "$tmp/config.txt")
    [ "$count" = 1 ] || { fail "overclock arm_freq count is $count"; rm -rf "$tmp"; return; }
    grep -qx "$oc_comment" "$tmp/config.txt" \
        || { fail "overclock comment missing"; rm -rf "$tmp"; return; }
    grep -q 'cma=256M' "$tmp/cmdline.txt" \
        || { fail "overclock rewrote cma="; rm -rf "$tmp"; return; }
    fw_run "$tmp" --revert || return
    grep -q 'arm_freq=' "$tmp/config.txt" \
        && { fail "owned arm_freq survived revert"; rm -rf "$tmp"; return; }
    grep -q 'Pimarchy: Pi 5 overclock' "$tmp/config.txt" \
        && { fail "overclock comment survived revert"; rm -rf "$tmp"; return; }
    grep -qx '\[all\]' "$tmp/config.txt" \
        || { fail "overclock revert dropped existing [all]"; rm -rf "$tmp"; return; }
    grep -qx 'uart_2ndstage=1' "$tmp/config.txt" \
        || { fail "overclock revert dropped uart line"; rm -rf "$tmp"; return; }
    grep -q 'cma=256M' "$tmp/cmdline.txt" \
        || { fail "overclock revert rewrote cma=256M"; rm -rf "$tmp"; return; }

    # Opt-in overclock with no [all] appends the header, and revert removes it.
    printf 'dtparam=uart0=1\n' > "$tmp/config.txt"
    printf 'console=tty1 rootwait\n' > "$tmp/cmdline.txt"
    fw_run "$tmp" --overclock || return
    fw_run "$tmp" --revert || return
    grep -q '\[all\]' "$tmp/config.txt" \
        && { fail "overclock [all] survived revert"; rm -rf "$tmp"; return; }
    grep -q 'arm_freq=' "$tmp/config.txt" \
        && { fail "appended arm_freq survived revert"; rm -rf "$tmp"; return; }
    grep -qx 'dtparam=uart0=1' "$tmp/config.txt" \
        || { fail "uart0 line missing after overclock revert"; rm -rf "$tmp"; return; }

    # Legacy voltage-free comment is still an owned block.
    printf '%s\n[all]\narm_freq=2600\n' "$old_oc" > "$tmp/config.txt"
    printf 'console=tty1 rootwait\n' > "$tmp/cmdline.txt"
    fw_run "$tmp" --revert || return
    grep -q 'arm_freq=' "$tmp/config.txt" \
        && { fail "legacy arm_freq survived revert"; rm -rf "$tmp"; return; }
    grep -q '\[all\]' "$tmp/config.txt" \
        && { fail "legacy overclock [all] survived revert"; rm -rf "$tmp"; return; }
    printf '[all]\n%s\narm_freq=2600\nuart_2ndstage=1\n' "$old_oc" > "$tmp/config.txt"
    fw_run "$tmp" --revert || return
    grep -q 'arm_freq=' "$tmp/config.txt" \
        && { fail "legacy inserted arm_freq survived revert"; rm -rf "$tmp"; return; }
    grep -qx '\[all\]' "$tmp/config.txt" \
        || { fail "legacy revert dropped existing [all]"; rm -rf "$tmp"; return; }
    grep -qx 'uart_2ndstage=1' "$tmp/config.txt" \
        || { fail "legacy revert dropped uart line"; rm -rf "$tmp"; return; }

    rm -rf "$tmp"
    pass
}

test_imager_manifest() {
    local tmp img
    tmp=$(mktemp -d)
    img="$tmp/sample.img"
    printf 'pimarchy' > "$img"
    bash "$PIMARCHY_DIR/image/write-imager-manifest.sh" "$img" \
        "$tmp/sample.rpi-imager-manifest" \
        || { fail "manifest writer failed"; rm -rf "$tmp"; return; }
    if ! python3 - "$tmp/sample.rpi-imager-manifest" "$img" <<'PY'
import json
import pathlib
import sys

manifest, img = sys.argv[1:]
data = json.load(open(manifest))
entry = data["os_list"][0]
image = pathlib.Path(img).resolve()
if entry["init_format"] != "cloudinit-rpi":
    raise SystemExit(f"init_format {entry['init_format']}")
if entry["url"] != image.as_uri():
    raise SystemExit(f"url {entry['url']}")
if "pi5-64bit" not in entry["devices"]:
    raise SystemExit("pi5 tag missing")
if len(entry["extract_sha256"]) != 64:
    raise SystemExit("sha256 missing")
if data["imager"]["default_os"] != "Pimarchy":
    raise SystemExit("default os")
names = [device["name"] for device in data["imager"]["devices"]]
if "Raspberry Pi 5" not in names or "No filtering" not in names:
    raise SystemExit(f"devices {names}")
PY
    then
        fail "manifest contents"
        rm -rf "$tmp"
        return
    fi
    rm -rf "$tmp"
    pass
}

# ── Run ───────────────────────────────────────────────────────────────────────

echo "Quattro tests (sandbox: $SANDBOX):"
run_test "read_package_list filters comments"        test_read_package_list_filters_comments
run_test "core apt list"                             test_list_apt_packages
run_test "pi firmware tuning"                        test_pi_firmware_tuning
run_test "root device resolution"                    test_dev_root_resolve
test_firstboot_owns_console() {
    local unit
    unit=$(sed -n '/pimarchy-firstboot.service/,/^EOF$/p' \
        "$PIMARCHY_DIR/image/build-image.sh")
    printf '%s\n' "$unit" | grep -q 'TTYPath=/dev/tty1' \
        || { fail "firstboot does not claim tty1"; return; }
    printf '%s\n' "$unit" | grep -q 'Conflicts=getty@tty1.service' \
        || { fail "firstboot does not conflict with getty"; return; }
    printf '%s\n' "$unit" | grep -q 'After=network-online.target' \
        && { fail "firstboot waits for network before claiming the console"; return; }
    grep -q '/dev/null.*getty@tty1.service' \
        "$PIMARCHY_DIR/image/build-image.sh" \
        || { fail "image does not mask getty"; return; }
    grep -q 'script -qaef' "$PIMARCHY_DIR/image/firstboot.sh" \
        || { fail "install output is not a terminal session"; return; }
    grep -q 'systemctl --no-block reboot' "$PIMARCHY_DIR/image/firstboot.sh" \
        || { fail "finished install does not reboot"; return; }
    grep -q 'systemctl reboot' "$PIMARCHY_DIR/image/firstboot.sh" \
        && { fail "blocking reboot would stall the oneshot"; return; }
    grep -q 'Log in with the user you set' "$PIMARCHY_DIR/image/build-image.sh" \
        && { fail "issue still invites a login during install"; return; }
    grep -q 'DEBIAN_FRONTEND DEBCONF_NONINTERACTIVE_SEEN' \
        "$PIMARCHY_DIR/lib/packages.sh" \
        || { fail "apt can drop noninteractive and stop on libc6"; return; }
    pass
}

run_test "imager manifest"                           test_imager_manifest
run_test "first boot owns the console"              test_firstboot_owns_console
run_test "wifi country cmdline"                      test_wifi_country_cmdline
run_test "user unit enable without a session"        test_link_user_unit
run_test "core sid list"                             test_list_sid_packages
run_test "core/ai script labels"                        test_list_script_labels
run_test "dev list contents (rustup/node/go/docker)" test_dev_list_contents
run_test "cargo config renders absolute home"        test_cargo_config_template_renders_absolute_home
run_test "cargo config hook install + user-edit guard" test_cargo_config_hook_installs_and_preserves_user_edits
run_test "unknown module errors"                     test_unknown_module_errors
run_test "defaults: shipped defaults"                test_defaults_defaults
run_test "defaults: set + read"                      test_defaults_set_and_read
run_test "defaults: rejects unknown values"          test_defaults_reject_unknown
run_test "defaults: corrupt file falls back"         test_defaults_read_falls_back
run_test "defaults: reinstall preserves choice"      test_defaults_install_preserves_user_choice
run_test "upgrade: pristine vs modified"             test_upgrade_hash_pristine_vs_modified
run_test "upgrade: missing file installs"            test_upgrade_missing_file_installs
run_test "upgrade: retired files cleanup"            test_retired_files_cleanup
run_test "agent wrapper: missing-raven message"      test_agent_wrapper_reads_default
run_test "default-agent wrapper: validation"         test_default_agent_wrapper_validates
run_test "default-agent wrapper: writes file"        test_default_agent_wrapper_writes_file
run_test "pimarchy-install: usage errors"            test_pimarchy_install_usage
run_test "bindings template renders defaults"        test_bindings_template_renders
run_test "hyprland.conf sources bindings"            test_hyprland_conf_sources_bindings

echo ""
if [ $FAILURES -gt 0 ]; then
    echo "$FAILURES test(s) FAILED in $(basename "$0")"
    exit 1
fi
echo "All tests in $(basename "$0") passed!"
exit 0