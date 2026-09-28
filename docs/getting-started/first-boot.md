# First Boot

The prebuilt Pimarchy image installs on the HDMI console. It does not ask you to log in while that install is running. When it finishes, the Pi reboots to the desktop login. The steps below are for a stock Pi OS Lite card, where you install Pimarchy yourself.

After you flash your Pi OS Lite image, follow these steps to prepare your system for Pimarchy.

## 1. Login
When the Pi boots, you will see a text-based login prompt. Log in with the username and password you set in the Raspberry Pi Imager.

## 2. Connect to the Internet
If you didn't configure Wi-Fi in the Imager, use `nmtui` to connect:

```bash
sudo nmtui
```
Navigate to **Activate a connection**, select your Wi-Fi, and enter the password.

## 3. Next Step
You are ready to [Install Pimarchy](installation.md). The installer updates Pi OS before it adds the desktop. It links `/dev/root` to the real root disk first, so the initramfs rebuild during that upgrade can finish.

Git is installed by the installer. A separate `apt install git` step is not required.
