# Overclocking Guide

Pimarchy includes an optional overclocking feature designed for the Raspberry Pi 5.

## Performance Modes

During the installation (`bash install.sh`), you will be presented with three performance options:

### 1. Governor Only (`g`)
This is the safest mode. It sets the CPU governor to `performance`, which keeps the CPU at its default maximum clock (2.4 GHz) and prevents it from scaling down. This results in a more responsive desktop experience.
-   **No reboot required.**
-   **Safe for all units.**

### 2. Overclock (`o`)
This mode sets the CPU clock to **2.6 GHz** (up from the default 2.4 GHz).
-   **Requires Active Cooling:** You MUST have an official Raspberry Pi Active Cooler or a comparable cooling solution.
-   **Requires a Reboot:** Changes are written to `/boot/firmware/config.txt`.
-   **Adds `arm_freq=2600`** to your system configuration.

### 3. Skip (`N`)
Leaves the system settings unchanged.

## Manual Overclocking

If you want to manually tune your Pi 5, you can edit `/boot/firmware/config.txt`.

!!! warning "Proceed with Caution"
    Overclocking beyond 2.6 GHz or increasing voltage (`over_voltage_delta`) can void your warranty and may cause permanent damage if not properly cooled.

### Recommended Manual Settings (with cooling):
```ini
# Edit /boot/firmware/config.txt
arm_freq=2600
over_voltage_delta=50000
```

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
