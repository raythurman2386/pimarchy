#!/bin/bash
#
# Pimarchy Library — Aggregator
#
# Historical entry point (install.sh / uninstall.sh / validate.sh / tests).
# The implementation now lives in focused modules under lib/:
#   common.sh    — paths and constants
#   log.sh       — logging
#   template.sh  — load_config / process_template
#   backup.sh    — backup/restore of user configs
#   repos.sh     — external apt repositories (sid, Docker CE)
#   packages.sh  — list-driven package modules (core/dev/office)
#   services.sh  — systemd/greetd/firewall/keyboard setup
#   pi-perf.sh   — Pi 5 governor / overclock
#   apps.sh      — app installs (Zed, Raven, Ollama, rustup, ...), gsettings
#   defaults.sh  — Quattro default-app policy
#   upgrade.sh   — Quattro safe upgrade model (hash-gated config refresh)
#

for _pimarchy_lib in common log template backup repos packages services pi-perf apps defaults upgrade; do
    source "${BASH_SOURCE[0]%/*}/$_pimarchy_lib.sh"
done
unset _pimarchy_lib