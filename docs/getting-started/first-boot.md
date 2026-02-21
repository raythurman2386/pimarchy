# First Boot

After you flash your Pi OS Lite image, follow these steps to prepare your system for Pimarchy.

## 1. Login
When the Pi boots, you will see a text-based login prompt. Log in with the username and password you set in the Raspberry Pi Imager.

## 2. Connect to the Internet
If you didn't configure Wi-Fi in the Imager, use `nmtui` to connect:

```bash
sudo nmtui
```
Navigate to **Activate a connection**, select your Wi-Fi, and enter the password.

## 3. Full System Update
Pimarchy relies on the latest packages and kernel features.

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

## 4. Install Git
Git is essential for cloning the Pimarchy repository.

```bash
sudo apt install -y git
```

## 5. Next Step
You are now ready to [Install Pimarchy](installation.md).
