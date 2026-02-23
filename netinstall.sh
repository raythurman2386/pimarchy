#!/bin/bash
#
# Pimarchy Web Installer
# Downloads, configures, and launches the Pimarchy installation.
#
# Usage: curl -sL https://raw.githubusercontent.com/raythurman2386/pimarchy/main/netinstall.sh | bash
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}          Pimarchy Web Installer            ${NC}"
echo -e "${BLUE}==============================================${NC}"

# 1. Install required packages
echo -e "\n${YELLOW}[*] Checking for required dependencies...${NC}"
if ! command -v git &> /dev/null || ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}[*] Installing git and curl...${NC}"
    sudo apt-get update
    sudo apt-get install -y git curl
else
    echo -e "${GREEN}[OK] Dependencies met.${NC}"
fi

# 2. Configure Git if needed
echo -e "\n${YELLOW}[*] Checking Git configuration...${NC}"
git_name=$(git config --global user.name || echo "")
git_email=$(git config --global user.email || echo "")

if [ -z "$git_name" ] || [ -z "$git_email" ]; then
    echo -e "${YELLOW}[!] Git is not fully configured.${NC}"
    echo -e "Pimarchy requires a basic Git configuration to function properly."
    
    # Read from /dev/tty because this script is likely being piped to bash
    if [ -z "$git_name" ]; then
        read -p "Enter your Name for Git commits: " -u 0 user_name </dev/tty
        if [ -n "$user_name" ]; then
            git config --global user.name "$user_name"
            echo -e "${GREEN}[OK] Git user.name set to: $user_name${NC}"
        else
            echo -e "${RED}[ERROR] Name cannot be empty. Setup aborted.${NC}"
            exit 1
        fi
    fi
    
    if [ -z "$git_email" ]; then
        read -p "Enter your Email for Git commits: " -u 0 user_email </dev/tty
        if [ -n "$user_email" ]; then
            git config --global user.email "$user_email"
            echo -e "${GREEN}[OK] Git user.email set to: $user_email${NC}"
        else
            echo -e "${RED}[ERROR] Email cannot be empty. Setup aborted.${NC}"
            exit 1
        fi
    fi
else
    echo -e "${GREEN}[OK] Git is configured ($git_name <$git_email>).${NC}"
fi

# 3. Clone Pimarchy
INSTALL_DIR="$HOME/.local/share/pimarchy"
REPO_URL="https://github.com/raythurman2386/pimarchy.git"

echo -e "\n${YELLOW}[*] Setting up Pimarchy repository...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}[*] Updating existing repository in $INSTALL_DIR...${NC}"
    cd "$INSTALL_DIR"
    git fetch origin
    git reset --hard origin/main
else
    echo -e "${YELLOW}[*] Cloning repository to $INSTALL_DIR...${NC}"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# 4. Run the main installer
echo -e "\n${GREEN}[OK] Setup complete! Launching Pimarchy installer...${NC}"
echo -e "${BLUE}==============================================${NC}\n"

# Pass any arguments provided to netinstall.sh to install.sh
exec bash "$INSTALL_DIR/install.sh" "$@"
