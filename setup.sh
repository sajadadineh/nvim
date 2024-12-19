#!/bin/bash

# Variables
NVIM_VERSION="v0.9.4" # Desired Neovim version
NVIM_URL="https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-linux64.tar.gz"
INSTALL_DIR="/opt/nvim-linux64"
CONFIG_DIR="$HOME/.config/nvim"
CURRENT_DIR=$(dirname "$(realpath "$0")") # The directory where this script is located

# Check for root access
if [[ $EUID -ne 0 ]]; then
   echo "Please run this script as root."
   exit 1
fi

# Download and extract Neovim
echo "Downloading Neovim..."
curl -L $NVIM_URL -o nvim-linux64.tar.gz
echo "Extracting files..."
tar -xzf nvim-linux64.tar.gz
echo "Moving to $INSTALL_DIR ..."
mv nvim-linux64 $INSTALL_DIR
rm nvim-linux64.tar.gz

# Set up config
echo "Setting up Neovim config..."
if [ -d "$CONFIG_DIR" ]; then
  mv "$CONFIG_DIR" "${CONFIG_DIR}_backup_$(date +%s)"
  echo "Existing config has been moved to ${CONFIG_DIR}_backup."
fi
cp -r "$CURRENT_DIR/nvim" "$CONFIG_DIR"

# Install ripgrep for searching
echo "Installing ripgrep..."
if command -v apt &>/dev/null; then
  apt update && apt install -y ripgrep
elif command -v yum &>/dev/null; then
  yum install -y ripgrep
elif command -v pacman &>/dev/null; then
  pacman -Sy --noconfirm ripgrep
else
  echo "Unsupported package manager. Please install ripgrep manually."
fi

# Detect user shell and update PATH
SHELL_NAME=$(basename "$SHELL")
echo "Detected user shell: $SHELL_NAME"

case $SHELL_NAME in
  bash)
    echo "export PATH=$INSTALL_DIR/bin:\$PATH" >> "$HOME/.bashrc"
    ;;
  zsh)
    echo "export PATH=$INSTALL_DIR/bin:\$PATH" >> "$HOME/.zshrc"
    ;;
  fish)
    echo "set -U fish_user_paths $INSTALL_DIR/bin \$fish_user_paths" >> "$HOME/.config/fish/config.fish"
    ;;
  *)
    echo "Unknown shell. Please manually add $INSTALL_DIR/bin to your PATH."
    ;;
esac

echo "Installation and setup complete. Please reload your shell or log in again."
