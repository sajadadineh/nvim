#!/usr/bin/env bash

################################################################################
# Neovim Installation Script
# 
# A robust, cross-platform installation script for Neovim with automatic
# dependency management, plugin bootstrapping, and configuration setup.
#
# Features:
# - Automatic latest stable Neovim version detection
# - Multi-architecture support (x86_64, aarch64/arm64)
# - Multi-distro package manager detection
# - Proper sudo/root handling
# - Shell detection and PATH management
# - Plugin manager bootstrap and synchronization
# - Comprehensive error handling and logging
################################################################################

set -Eeuo pipefail

################################################################################
# Global Variables
################################################################################

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly NVIM_INSTALL_DIR="/opt/nvim"
readonly NVIM_REPO="neovim/neovim"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Track installation details for summary
declare -a INSTALLED_DEPS=()
declare NVIM_VERSION=""
declare CONFIG_BACKUP=""
declare ACTUAL_USER=""
declare ACTUAL_HOME=""
declare ACTUAL_SHELL=""

################################################################################
# Logging Functions
################################################################################

info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

fatal() {
    error "$*"
    exit 1
}

################################################################################
# User and Environment Detection
################################################################################

detect_actual_user() {
    # Detect the actual user even when running with sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        ACTUAL_USER="$SUDO_USER"
        ACTUAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        ACTUAL_USER="${USER:-$(whoami)}"
        ACTUAL_HOME="${HOME}"
    fi
    
    # Verify home directory exists
    if [[ ! -d "$ACTUAL_HOME" ]]; then
        fatal "Home directory $ACTUAL_HOME does not exist"
    fi
    
    info "Detected user: $ACTUAL_USER"
    info "Home directory: $ACTUAL_HOME"
}

detect_actual_shell() {
    # Detect the actual user's shell, not root's shell
    if [[ -n "${SUDO_USER:-}" ]]; then
        ACTUAL_SHELL=$(getent passwd "$SUDO_USER" | cut -d: -f7)
    else
        ACTUAL_SHELL="${SHELL:-/bin/bash}"
    fi
    
    # Get just the shell name
    ACTUAL_SHELL=$(basename "$ACTUAL_SHELL")
    info "Detected shell: $ACTUAL_SHELL"
}

################################################################################
# System Detection
################################################################################

detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            echo "linux64"
            ;;
        aarch64|arm64)
            echo "linux64"  # Neovim uses linux64 for both x86_64 and arm64
            ;;
        *)
            fatal "Unsupported architecture: $arch"
            ;;
    esac
}

detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    else
        fatal "No supported package manager found (apt, dnf, yum, pacman, zypper)"
    fi
}

detect_os_release() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

################################################################################
# Dependency Installation
################################################################################

install_dependencies() {
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    local os_id
    os_id=$(detect_os_release)
    
    info "Installing dependencies using $pkg_manager..."
    
    # Check if we have root privileges
    local sudo_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            sudo_cmd="sudo"
        else
            fatal "Root privileges required but sudo not available"
        fi
    fi
    
    case "$pkg_manager" in
        apt)
            info "Updating package lists..."
            $sudo_cmd apt-get update -qq || warning "Failed to update package lists"
            
            local apt_packages=(
                curl git unzip ripgrep fd-find
                build-essential make
                nodejs npm
                python3 python3-pip
            )
            
            for pkg in "${apt_packages[@]}"; do
                if ! dpkg -l | grep -q "^ii  $pkg "; then
                    info "Installing $pkg..."
                    if $sudo_cmd apt-get install -y -qq "$pkg" &>/dev/null; then
                        INSTALLED_DEPS+=("$pkg")
                    else
                        warning "Failed to install $pkg"
                    fi
                fi
            done
            ;;
            
        dnf|yum)
            local dnf_packages=(
                curl git unzip ripgrep fd-find
                gcc gcc-c++ make
                nodejs npm
                python3 python3-pip
            )
            
            for pkg in "${dnf_packages[@]}"; do
                if ! rpm -q "$pkg" &>/dev/null; then
                    info "Installing $pkg..."
                    if $sudo_cmd "$pkg_manager" install -y -q "$pkg" &>/dev/null; then
                        INSTALLED_DEPS+=("$pkg")
                    else
                        warning "Failed to install $pkg"
                    fi
                fi
            done
            ;;
            
        pacman)
            info "Updating package database..."
            $sudo_cmd pacman -Sy --noconfirm &>/dev/null || warning "Failed to update package database"
            
            local pacman_packages=(
                curl git unzip ripgrep fd
                base-devel
                nodejs npm
                python python-pip
            )
            
            for pkg in "${pacman_packages[@]}"; do
                if ! pacman -Q "$pkg" &>/dev/null 2>&1; then
                    info "Installing $pkg..."
                    if $sudo_cmd pacman -S --noconfirm --needed "$pkg" &>/dev/null; then
                        INSTALLED_DEPS+=("$pkg")
                    else
                        warning "Failed to install $pkg"
                    fi
                fi
            done
            ;;
            
        zypper)
            local zypper_packages=(
                curl git unzip ripgrep fd
                gcc gcc-c++ make
                nodejs npm
                python3 python3-pip
            )
            
            for pkg in "${zypper_packages[@]}"; do
                if ! rpm -q "$pkg" &>/dev/null; then
                    info "Installing $pkg..."
                    if $sudo_cmd zypper install -y "$pkg" &>/dev/null; then
                        INSTALLED_DEPS+=("$pkg")
                    else
                        warning "Failed to install $pkg"
                    fi
                fi
            done
            ;;
    esac
    
    # Verify critical dependencies
    local critical_deps=(curl git unzip)
    for dep in "${critical_deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            fatal "Critical dependency $dep is not available"
        fi
    done
    
    if [[ ${#INSTALLED_DEPS[@]} -gt 0 ]]; then
        success "Installed ${#INSTALLED_DEPS[@]} dependencies"
    else
        info "All dependencies already installed"
    fi
}

################################################################################
# Neovim Installation
################################################################################

get_latest_nvim_version() {
    info "Fetching latest Neovim stable release..."
    
    local version
    version=$(curl -fsSL "https://api.github.com/repos/$NVIM_REPO/releases/latest" | 
              grep '"tag_name":' | 
              sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    
    if [[ -z "$version" ]]; then
        fatal "Failed to fetch latest Neovim version"
    fi
    
    echo "$version"
}

remove_old_nvim() {
    local sudo_cmd=""
    if [[ $EUID -ne 0 ]]; then
        sudo_cmd="sudo"
    fi
    
    if [[ -d "$NVIM_INSTALL_DIR" ]]; then
        info "Removing previous Neovim installation..."
        $sudo_cmd rm -rf "$NVIM_INSTALL_DIR" || warning "Failed to remove old installation"
    fi
}

install_neovim() {
    local version
    version=$(get_latest_nvim_version)
    NVIM_VERSION="$version"
    
    local arch
    arch=$(detect_architecture)
    
    local download_url="https://github.com/$NVIM_REPO/releases/download/$version/nvim-$arch.tar.gz"
    local temp_dir
    temp_dir=$(mktemp -d)
    local tarball="$temp_dir/nvim.tar.gz"
    
    info "Downloading Neovim $version for $arch..."
    if ! curl -fsSL "$download_url" -o "$tarball"; then
        rm -rf "$temp_dir"
        fatal "Failed to download Neovim from $download_url"
    fi
    
    info "Extracting Neovim..."
    if ! tar -xzf "$tarball" -C "$temp_dir"; then
        rm -rf "$temp_dir"
        fatal "Failed to extract Neovim tarball"
    fi
    
    # Remove old installation
    remove_old_nvim
    
    # Install new version
    local sudo_cmd=""
    if [[ $EUID -ne 0 ]]; then
        sudo_cmd="sudo"
    fi
    
    info "Installing Neovim to $NVIM_INSTALL_DIR..."
    if ! $sudo_cmd mv "$temp_dir/nvim-$arch" "$NVIM_INSTALL_DIR"; then
        rm -rf "$temp_dir"
        fatal "Failed to install Neovim to $NVIM_INSTALL_DIR"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Verify installation
    if [[ ! -x "$NVIM_INSTALL_DIR/bin/nvim" ]]; then
        fatal "Neovim binary not found or not executable"
    fi
    
    success "Neovim $version installed successfully"
}

################################################################################
# PATH Management
################################################################################

is_in_path() {
    local dir="$1"
    case ":$PATH:" in
        *":$dir:"*) return 0 ;;
        *) return 1 ;;
    esac
}

add_to_path() {
    local shell_name="$1"
    local nvim_bin="$NVIM_INSTALL_DIR/bin"
    
    # Check if already in PATH
    if is_in_path "$nvim_bin"; then
        info "Neovim already in PATH"
        return 0
    fi
    
    local shell_config=""
    local path_command=""
    
    case "$shell_name" in
        bash)
            shell_config="$ACTUAL_HOME/.bashrc"
            path_command="export PATH=\"$nvim_bin:\$PATH\""
            ;;
        zsh)
            shell_config="$ACTUAL_HOME/.zshrc"
            path_command="export PATH=\"$nvim_bin:\$PATH\""
            ;;
        fish)
            shell_config="$ACTUAL_HOME/.config/fish/config.fish"
            path_command="fish_add_path -p \"$nvim_bin\""
            ;;
        *)
            warning "Unsupported shell: $shell_name. Please manually add $nvim_bin to PATH"
            return 1
            ;;
    esac
    
    # Create config file if it doesn't exist
    if [[ ! -f "$shell_config" ]]; then
        mkdir -p "$(dirname "$shell_config")"
        touch "$shell_config"
        # Set proper ownership
        if [[ $EUID -eq 0 ]]; then
            chown "$ACTUAL_USER:$(id -gn "$ACTUAL_USER")" "$shell_config"
        fi
    fi
    
    # Check if PATH entry already exists in config file
    if grep -qF "$nvim_bin" "$shell_config" 2>/dev/null; then
        info "PATH entry already exists in $shell_config"
        return 0
    fi
    
    # Add PATH entry
    info "Adding Neovim to PATH in $shell_config..."
    {
        echo ""
        echo "# Added by Neovim installer"
        echo "$path_command"
    } >> "$shell_config"
    
    success "Added Neovim to PATH"
}

################################################################################
# Configuration Management
################################################################################

backup_existing_config() {
    local config_dir="$ACTUAL_HOME/.config/nvim"
    
    if [[ -d "$config_dir" ]] || [[ -L "$config_dir" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_dir="${config_dir}_backup_${timestamp}"
        
        info "Backing up existing configuration to $backup_dir..."
        if mv "$config_dir" "$backup_dir"; then
            CONFIG_BACKUP="$backup_dir"
            success "Configuration backed up"
        else
            fatal "Failed to backup existing configuration"
        fi
    fi
}

install_config() {
    local config_dir="$ACTUAL_HOME/.config/nvim"
    
    # Backup existing config if present
    backup_existing_config
    
    # Create .config directory if it doesn't exist
    mkdir -p "$ACTUAL_HOME/.config"
    
    info "Installing Neovim configuration..."
    if ! cp -r "$SCRIPT_DIR" "$config_dir"; then
        fatal "Failed to copy configuration files"
    fi
    
    # Set proper ownership if running as root
    if [[ $EUID -eq 0 ]]; then
        chown -R "$ACTUAL_USER:$(id -gn "$ACTUAL_USER")" "$config_dir"
    fi
    
    success "Configuration installed to $config_dir"
}

################################################################################
# Plugin Management
################################################################################

bootstrap_lazy_nvim() {
    local lazy_path="$ACTUAL_HOME/.local/share/nvim/lazy/lazy.nvim"
    
    if [[ -d "$lazy_path" ]]; then
        info "lazy.nvim already installed"
        return 0
    fi
    
    info "Installing lazy.nvim plugin manager..."
    
    # Create parent directory
    mkdir -p "$(dirname "$lazy_path")"
    
    # Clone lazy.nvim
    if ! git clone --filter=blob:none --branch=stable \
         https://github.com/folke/lazy.nvim.git "$lazy_path" &>/dev/null; then
        fatal "Failed to clone lazy.nvim"
    fi
    
    # Set proper ownership if running as root
    if [[ $EUID -eq 0 ]]; then
        chown -R "$ACTUAL_USER:$(id -gn "$ACTUAL_USER")" "$ACTUAL_HOME/.local/share/nvim"
    fi
    
    success "lazy.nvim installed"
}

sync_plugins() {
    info "Synchronizing plugins (this may take a few minutes)..."
    
    # Run as actual user if we're root
    local run_cmd=""
    if [[ $EUID -eq 0 ]]; then
        run_cmd="sudo -u $ACTUAL_USER"
    fi
    
    # Run Neovim in headless mode to install plugins
    local nvim_cmd="$NVIM_INSTALL_DIR/bin/nvim"
    
    # Create a temporary script to run plugin sync
    local temp_script
    temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
-- Headless plugin installation
vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/lazy/lazy.nvim")

-- Load lazy.nvim
local lazy_available, lazy = pcall(require, "lazy")
if not lazy_available then
    print("ERROR: lazy.nvim not found")
    vim.cmd("cquit 1")
end

-- Sync plugins
lazy.sync({ wait = true })

-- Check for errors
local plugins = require("lazy").plugins()
local has_errors = false
for _, plugin in ipairs(plugins) do
    if plugin._.error then
        print("ERROR: Failed to install " .. plugin.name)
        has_errors = true
    end
end

if has_errors then
    vim.cmd("cquit 1")
else
    print("SUCCESS: All plugins installed")
    vim.cmd("quitall")
end
EOF
    
    # Run the sync with timeout
    local exit_code=0
    if ! timeout 300 $run_cmd "$nvim_cmd" --headless -u "$temp_script" 2>&1 | grep -E "(ERROR|SUCCESS)"; then
        exit_code=$?
    fi
    
    rm -f "$temp_script"
    
    if [[ $exit_code -ne 0 ]]; then
        warning "Plugin synchronization completed with warnings or errors"
        warning "You may need to run :Lazy sync manually in Neovim"
        return 1
    fi
    
    success "All plugins synchronized successfully"
    return 0
}

################################################################################
# Summary Display
################################################################################

display_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    success "Installation Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📦 Neovim Version:    $NVIM_VERSION"
    echo "📁 Installation Path: $NVIM_INSTALL_DIR"
    echo "⚙️  Configuration:     $ACTUAL_HOME/.config/nvim"
    
    if [[ -n "$CONFIG_BACKUP" ]]; then
        echo "💾 Backup Location:   $CONFIG_BACKUP"
    fi
    
    if [[ ${#INSTALLED_DEPS[@]} -gt 0 ]]; then
        echo ""
        echo "📚 Installed Dependencies (${#INSTALLED_DEPS[@]}):"
        printf '   - %s\n' "${INSTALLED_DEPS[@]}"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 Next Steps:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Reload your shell configuration:"
    case "$ACTUAL_SHELL" in
        bash)
            echo "   source ~/.bashrc"
            ;;
        zsh)
            echo "   source ~/.zshrc"
            ;;
        fish)
            echo "   source ~/.config/fish/config.fish"
            ;;
        *)
            echo "   (restart your terminal or log out and back in)"
            ;;
    esac
    echo ""
    echo "2. Launch Neovim:"
    echo "   nvim"
    echo ""
    echo "3. If plugins need manual sync, run inside Neovim:"
    echo "   :Lazy sync"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Neovim Installation Script"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Detect user and environment
    detect_actual_user
    detect_actual_shell
    
    # Install dependencies
    install_dependencies
    
    # Install Neovim
    install_neovim
    
    # Add to PATH
    add_to_path "$ACTUAL_SHELL"
    
    # Install configuration
    install_config
    
    # Bootstrap plugin manager
    bootstrap_lazy_nvim
    
    # Sync plugins
    sync_plugins || warning "Plugin sync had issues, but installation continues"
    
    # Display summary
    display_summary
    
    echo ""
    success "Installation completed successfully!"
    echo ""
}

################################################################################
# Error Handler
################################################################################

cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        error "Installation failed with exit code $exit_code"
        error "Please check the error messages above and try again"
        echo ""
    fi
}

trap cleanup_on_error EXIT

################################################################################
# Entry Point
################################################################################

main "$@"