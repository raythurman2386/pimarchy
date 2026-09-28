#!/bin/bash
# Raspberry Pi Imager 2 only offers OS customisation when a repository
# manifest names an init_format. "Use custom" supplies none, so the
# user, Wi-Fi, and SSH step stays hidden. This image is Trixie Lite
# with cloud-init and cc_raspberry_pi, so the format is cloudinit-rpi.
#
#   bash image/write-imager-manifest.sh [image] [manifest]
#
# Then:
#   rpi-imager --repo image/work/pimarchy.rpi-imager-manifest
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${1:-$ROOT/image/work/pimarchy-lite-arm64.img}"
manifest="${2:-$(dirname "$image")/pimarchy.rpi-imager-manifest}"

if [ ! -f "$image" ]; then
    echo "write-imager-manifest.sh: image not found: $image" >&2
    exit 1
fi

python3 - "$image" "$manifest" <<'PY'
import hashlib
import json
import pathlib
import sys
from datetime import datetime, timezone

image = pathlib.Path(sys.argv[1]).resolve()
manifest = pathlib.Path(sys.argv[2])
digest = hashlib.sha256()
with image.open("rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        digest.update(chunk)
size = image.stat().st_size
released = datetime.fromtimestamp(
    image.stat().st_mtime, timezone.utc
).date().isoformat()
sha = digest.hexdigest()
document = {
    "imager": {
        "latest_version": "2.0.11.1",
        "url": "https://www.raspberrypi.com/software/",
        "default_os": "Pimarchy",
        "devices": [
            {
                "name": "Raspberry Pi 5",
                "description": "Raspberry Pi 5, 500, and 500+",
                "tags": ["pi5-64bit"],
                "matching_type": "exclusive",
                "default": True,
            },
            {
                "name": "No filtering",
                "description": "Show every image in this list",
                "tags": [],
                "matching_type": "inclusive",
                "default": False,
            },
        ],
    },
    "os_list": [
        {
            "name": "Pimarchy",
            "description": (
                "Hyprland desktop for Pi 5, 500, and 500+. "
                "Set the user, Wi-Fi, and SSH here. "
                "The desktop installs on first boot."
            ),
            "icon": (
                "https://downloads.raspberrypi.com/"
                "raspios_armhf/Raspberry_Pi_OS_(32-bit).png"
            ),
            "url": image.as_uri(),
            "extract_size": size,
            "extract_sha256": sha,
            "image_download_size": size,
            "image_download_sha256": sha,
            "release_date": released,
            "init_format": "cloudinit-rpi",
            "architecture": "armv8",
            "devices": ["pi5-64bit"],
            "capabilities": ["rpi_connect"],
        }
    ],
}
manifest.parent.mkdir(parents=True, exist_ok=True)
manifest.write_text(json.dumps(document, indent=2) + "\n")
print(f"Wrote {manifest}")
PY
