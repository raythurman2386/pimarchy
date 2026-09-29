# Overclocking Guide

Pimarchy includes an optional overclocking feature designed for the Raspberry Pi 5.

## Performance Modes

During the installation (`bash install.sh`), you will be presented with three performance options:

### 1. Governor Only (`g`)
This is the safest mode. It sets the CPU governor to `performance`, which keeps the CPU at its default maximum clock (2.4 GHz) and prevents it from scaling down. This results in a more responsive desktop experience.
-   **No reboot required.**
-   **Safe for all units.**

### 2. Overclock (`o`)
This mode sets `arm_freq=2600`. The documented stock clock for Pi 5, Pi 500, and Pi 500+ is **2400 MHz**.
-   **Requires Active Cooling:** You MUST have an official Raspberry Pi Active Cooler or a comparable cooling solution. Arm cores throttle between 80°C and 85°C.
-   **Requires a Reboot:** Changes are written to `/boot/firmware/config.txt`.
-   **Firmware scales voltage** to hold the higher clock. Leave that scaling in place. A hand-set `over_voltage` disables it.
-   **Writes a marked block.** Under the first `[all]` section:

    ```ini
    # Pimarchy: Pi 5 overclock arm_freq=2600 (stock 2400; firmware scales voltage)
    arm_freq=2600
    ```

    When the file has no `[all]` section, the same comment is written above a new `[all]` header and `arm_freq=2600`. An `arm_freq=` line that is already in the file is left as it is.

### 3. Skip (`N`)
Leaves the system settings unchanged.

## Manual Overclocking

Stock `arm_freq` for Pi 5, Pi 500, and Pi 500+ is 2400. To set 2600 yourself, add the same lines the installer writes to `/boot/firmware/config.txt` and reboot with active cooling. Current firmware raises voltage for that clock. Leave `over_voltage` and `over_voltage_delta` unset so that scaling stays on.

Pimarchy does not write `dtparam=pciex1_gen=3`, `camera_auto_detect=0`, or a cmdline `cma=` value. PCIe stays at the firmware Gen 2 default. Gen 3 is an uncertified opt-in you add yourself only when that board and drive are known to train at 8 GT/s. A Gen 3 line can stop an NVMe boot.

## Verifying Speed

After rebooting, you can check your current CPU speed with:
```bash
watch -n 1 vcgencmd measure_clock arm
```

To check if your Pi is throttling due to temperature:
```bash
vcgencmd get_throttled
```
A value of `0x0` means no throttling is occurring.
