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
    for expected in foot rofi chromium jq fonts-dejavu-core mesa-vulkan-drivers \
                    libspa-0.2-bluetooth dconf-cli gsettings-desktop-schemas \
                    pipewire-pulse xdg-desktop-portal-gtk libnotify-bin qt5ct git; do
        echo "$pkgs" | grep -qx "$expected" || { fail "missing apt: package '$expected'"; return; }
    done
    echo "$pkgs" | grep -qx "thunar" && { fail "thunar should not be in core apt"; return; }
    echo "$pkgs" | grep -qx "blueman" && { fail "blueman should not be in core apt"; return; }
    pass
}

test_list_sid_packages() {
    local pkgs
    pkgs=$(list_apt_packages core sid)
    for expected in hyprland waybar mako-notifier uwsm; do
        echo "$pkgs" | grep -qx "$expected" || { fail "missing sid: package '$expected'"; return; }
    done
    # apt entries must not leak into the sid set
    echo "$pkgs" | grep -qx "foot" && { fail "apt package foot leaked into sid set"; return; }
    pass
}

test_list_script_labels() {
    local labels
    labels=$(list_script_labels core)
    for expected in zed pifile raven ollama; do
        echo "$labels" | grep -qx "$expected" || { fail "missing script: label '$expected'"; return; }
    done
    pass
}

test_dev_list_contents() {
    # Rust in dev via rustup script, node, go, python, docker, gh in core
    local scripts pkgs
    scripts=$(list_script_labels dev)
    pkgs=$(list_apt_packages dev apt)
    echo "$scripts" | grep -qx "rustup" || { fail "dev.list missing script:rustup"; return; }
    echo "$scripts" | grep -qx "node" || { fail "dev.list missing script:node"; return; }
    echo "$scripts" | grep -qx "go" || { fail "dev.list missing script:go"; return; }
    echo "$pkgs" | grep -qx "docker-ce" || { fail "dev.list missing apt:docker-ce"; return; }
    for expected in libfontconfig-dev libwayland-dev libxkbcommon-dev clang libvulkan-dev; do
        echo "$pkgs" | grep -qx "$expected" \
            || { fail "dev.list missing GPUI build dep '$expected'"; return; }
    done
    # rustup must NOT be an apt entry (it's not in Debian repos)
    echo "$pkgs" | grep -qx "rustup" && { fail "rustup should be script:, not apt:"; return; }
    # gh is a core package (always installed), so not required in dev
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

# ── Run ───────────────────────────────────────────────────────────────────────

echo "Quattro tests (sandbox: $SANDBOX):"
run_test "read_package_list filters comments"        test_read_package_list_filters_comments
run_test "core apt list"                             test_list_apt_packages
run_test "core sid list"                             test_list_sid_packages
run_test "core script labels"                        test_list_script_labels
run_test "dev list contents (rustup/node/go/docker)" test_dev_list_contents
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