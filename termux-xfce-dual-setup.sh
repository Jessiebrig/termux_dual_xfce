#!/bin/bash

# Configuration
CLEAR_LOG_ON_START=true  # Set to false to keep previous logs

# Strict error handling
set -euo pipefail

# Color palette
C_INFO='\033[38;5;39m'    # Bright blue
C_OK='\033[38;5;46m'      # Bright green
C_WARN='\033[38;5;214m'   # Orange
C_ERR='\033[38;5;196m'    # Bright red
C_RESET='\033[0m'

# Log files
LOG_FILE="$HOME/xfce_install.log"
: "${FULL_OUTPUT_FILE:=$HOME/.xfce_install_full_temp.txt}"
if [[ "$CLEAR_LOG_ON_START" == "true" ]]; then
    echo "=== Installation started at $(date) ===" > "$LOG_FILE"
else
    echo "=== Installation started at $(date) ===" >> "$LOG_FILE"
fi
exec 2>>"$LOG_FILE"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Status message function
msg() {
    local type=$1
    shift
    case $type in
        info) echo -e "${C_INFO}▸${C_RESET} $*" ;;
        ok) echo -e "${C_OK}✓${C_RESET} $*" ;;
        warn) echo -e "${C_WARN}⚠${C_RESET} $*" ;;
        error) echo -e "${C_ERR}✗${C_RESET} $*" ;;
    esac
    log "[$type] $*"
}

# Show troubleshooting tips
show_troubleshooting() {
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check your internet connection"
    echo "  2. Try a different mirror: termux-change-repo"
    echo "  3. Restart Termux and run the script again"
    echo "  4. If issue persists, install the package manually:"
    echo "     pkg install <package-name>"
    echo "     Then re-run this script (it will skip installed packages)"
    echo ""
}

# Cleanup on exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ]; then
        # Add quit instruction at top and bottom
        sed -i "1i=== Press 'q' to close this log viewer ===\n" "$LOG_FILE"
        echo "=== Press 'q' to close this log viewer ===" >> "$LOG_FILE"
        msg error "Installation failed."
        echo ""
        echo -n "View log file? (y/N): " > /dev/tty
        read -r response < /dev/tty
        if [[ "$response" =~ ^[Yy]$ ]]; then
            less "$LOG_FILE" || true
        fi
        
        # Prompt for full output
        if [[ -n "${FULL_OUTPUT_FILE:-}" && -f "$FULL_OUTPUT_FILE" ]]; then
            echo "" > /dev/tty
            echo -n "Full output: [v] View  [s] Save & view  [Enter] Skip: " > /dev/tty
            read -r full_response < /dev/tty
            case "$full_response" in
                [Vv])
                    less "$FULL_OUTPUT_FILE" || true
                    termux-clipboard-set < "$FULL_OUTPUT_FILE" 2>/dev/null && echo "Full output copied to clipboard" > /dev/tty || true
                    [[ "$FULL_OUTPUT_FILE" != "$LOG_FILE" ]] && rm -f "$FULL_OUTPUT_FILE"
                    ;;
                [Ss])
                    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                    SAVED_FILE="$HOME/xfce_install_full_${TIMESTAMP}.txt"
                    cp "$FULL_OUTPUT_FILE" "$SAVED_FILE" || true
                    ls -t "$HOME"/xfce_install_full_*.txt 2>/dev/null | tail -n +6 | xargs -r rm -f 2>/dev/null || true
                    sed -i "1i=== Press 'q' to close this log viewer ===\n" "$SAVED_FILE" 2>/dev/null || true
                    echo "=== Press 'q' to close this log viewer ===" >> "$SAVED_FILE" 2>/dev/null || true
                    echo "Saved to ~/xfce_install_full_${TIMESTAMP}.txt"
                    less "$SAVED_FILE" || true
                    termux-clipboard-set < "$SAVED_FILE" 2>/dev/null && echo "Full output copied to clipboard" || true
                    [[ "$FULL_OUTPUT_FILE" != "$LOG_FILE" ]] && rm -f "$FULL_OUTPUT_FILE"
                    ;;
                *)
                    [[ "$FULL_OUTPUT_FILE" != "$LOG_FILE" ]] && rm -f "$FULL_OUTPUT_FILE"
                    ;;
            esac
        fi
    fi
}
trap cleanup EXIT

# System verification
verify_system() {
    log "FUNCTION: verify_system() - Starting system verification"
    echo ""
    echo "┌────────────────────────────────────┐"
    echo "│   Pre-Installation System Checks   │"
    echo "└────────────────────────────────────┘"
    echo ""
    
    local errors=0
    local warnings=0
    
    # Check Android OS
    if [[ "$(uname -o)" == "Android" ]]; then
        local android_version=$(getprop ro.build.version.release)
        msg ok "Operating System: Android $android_version"
    else
        msg error "Not running on Android OS"
        ((errors++))
    fi
    
    # Display device information
    local device_brand=$(getprop ro.product.brand)
    local device_model=$(getprop ro.product.model)
    if [[ -n "$device_brand" && -n "$device_model" ]]; then
        msg ok "Device: $device_brand $device_model"
    fi
    
    # Check CPU architecture
    local arch=$(uname -m)
    if [[ "$arch" == "aarch64" ]]; then
        msg ok "CPU Architecture: $arch (ARM64)"
    else
        msg error "Unsupported architecture: $arch (requires aarch64/ARM64)"
        ((errors++))
    fi
    
    # Check Termux environment
    if [[ -d "$PREFIX" ]]; then
        msg ok "Termux environment: Detected"
    else
        msg error "Termux PREFIX directory not found"
        ((errors++))
    fi
    
    # Check available storage space
    local free_kb=$(df "$HOME" | awk 'NR==2 {print $4}')
    local free_space=$(df -h "$HOME" | awk 'NR==2 {print $4}')
    if [[ $free_kb -gt 8388608 ]]; then
        msg ok "Available Storage: $free_space (sufficient)"
    else
        msg warn "Available Storage: $free_space (8GB+ recommended)"
        ((warnings++))
    fi
    
    # Check RAM
    if command -v free &> /dev/null; then
        local total_ram=$(free -m | awk 'NR==2 {print $2}')
        if [[ $total_ram -gt 3072 ]]; then
            msg ok "System RAM: ${total_ram}MB (sufficient)"
        else
            msg warn "System RAM: ${total_ram}MB (3GB+ recommended)"
            ((warnings++))
        fi
    fi
    
    echo ""
    if [[ $errors -gt 0 ]]; then
        msg error "System requirements not met ($errors critical error(s))"
        echo ""
        echo "Requirements:"
        echo "  • Android 7.0+ (API 24 or higher)"
        echo "  • ARM64/aarch64 device"
        echo "  • Termux from GitHub (not Play Store)"
        echo "  • 8GB+ free storage space"
        echo "  • 3GB+ RAM recommended"
        echo ""
        exit 1
    fi
    
    if [[ $warnings -gt 0 ]]; then
        msg ok "System verification passed with $warnings warning(s)"
    else
        msg ok "All system requirements met"
    fi
    echo ""
}

# Main installation
main() {
    log "FUNCTION: main() - Starting main installation"
    clear
    echo ""
    echo "┌────────────────────────────────────┐"
    echo "│   Native + Debian XFCE Setup       │"
    echo "└────────────────────────────────────┘"
    echo ""
    
    verify_system
    
    msg info "This will install:"
    echo "  • Native Termux XFCE desktop"
    echo "  • Debian proot with XFCE"
    echo "  • Hardware acceleration support"
    echo ""
    echo "Press Enter to continue or Ctrl+C to cancel..." > /dev/tty
    read -r < /dev/tty
    
    # Get username
    USERNAME_FILE="$HOME/.xfce_debian_username"
    if [[ -f "$USERNAME_FILE" ]]; then
        username=$(cat "$USERNAME_FILE")
        msg ok "Using saved username: $username"
    elif [[ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]]; then
        # Detect existing username from Debian home directory
        username=$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/"* 2>/dev/null | grep -v "^root$" | head -n1)
        if [[ -n "$username" && "$username" != "*" ]]; then
            msg ok "Detected existing Debian user: $username"
            echo "$username" > "$USERNAME_FILE"
        else
            echo ""
            echo -n "Enter username for Debian proot: " > /dev/tty
            read -r username < /dev/tty
            if [[ -z "$username" ]]; then
                msg error "Username cannot be empty"
                exit 1
            fi
            echo "$username" > "$USERNAME_FILE"
        fi
    else
        echo ""
        echo -n "Enter username for Debian proot: " > /dev/tty
        read -r username < /dev/tty
        if [[ -z "$username" ]]; then
            msg error "Username cannot be empty"
            exit 1
        fi
        echo "$username" > "$USERNAME_FILE"
    fi
    
    # Clear any stale locks
    rm -f "$PREFIX/var/lib/apt/lists/lock" "$PREFIX/var/lib/dpkg/lock" "$PREFIX/var/lib/dpkg/lock-frontend" 2>/dev/null
    
    # Update repositories
    msg info "Updating package repositories..."
    if ! pkg update -y; then
        msg warn "Update failed, please select a mirror..."
        termux-change-repo
        # Wait for termux-change-repo to complete and clear locks
        sleep 2
        rm -f "$PREFIX/var/lib/apt/lists/lock" "$PREFIX/var/lib/dpkg/lock" "$PREFIX/var/lib/dpkg/lock-frontend" 2>/dev/null
        msg info "Retrying package update..."
        if ! pkg update -y; then
            msg error "Failed to update package lists after changing mirror"
            show_troubleshooting
            exit 1
        fi
    fi
    msg ok "Package lists updated successfully"
    
    # Setup storage
    if [[ ! -d ~/storage ]]; then
        echo ""
        msg info "Requesting storage access..."
        echo "Tap 'Allow' when prompted"
        termux-setup-storage
    else
        msg ok "Storage access already configured"
    fi
    
    # Upgrade packages
    msg info "Upgrading existing packages..."
    if ! pkg upgrade -y -o Dpkg::Options::="--force-confold"; then
        msg warn "Package upgrade encountered issues, continuing..."
    fi
    
    # Install core dependencies (including util-linux for script command)
    msg info "Installing core dependencies..."
    for pkg_name in proot-distro x11-repo tur-repo pulseaudio git util-linux
    do
        if pkg list-installed 2>/dev/null | grep -q "^$pkg_name/"; then
            msg ok "$pkg_name already installed, skipping..."
        else
            msg info "Installing $pkg_name..."
            if ! pkg install -y "$pkg_name"; then
                msg error "Failed to install $pkg_name"
                show_troubleshooting
                exit 1
            fi
        fi
    done
    msg ok "Core dependencies installed successfully"
    
    # Install native Termux XFCE
    msg info "Installing native Termux XFCE desktop..."
    for pkg_name in xfce4 xfce4-goodies xfce4-pulseaudio-plugin termux-x11-nightly \
        virglrenderer-android firefox starship \
        fastfetch papirus-icon-theme eza bat htop
    do
        if pkg list-installed 2>/dev/null | grep -q "^$pkg_name/"; then
            msg ok "$pkg_name already installed, skipping..."
        else
            msg info "Installing $pkg_name..."
            if ! pkg install -y "$pkg_name"; then
                msg error "Failed to install $pkg_name"
                show_troubleshooting
                exit 1
            fi
        fi
    done
    
    # Try to install optional Vulkan driver (may not be available on all devices)
    msg info "Installing experimental GPU drivers..."
    pkg install -y mesa-vulkan-icd-freedreno-dri3 2>/dev/null || msg warn "Vulkan driver not available for this device (optional)"
    
    msg ok "XFCE desktop environment installed successfully"
    
    # Create directories
    msg info "Creating directory structure..."
    mkdir -p "$HOME"/{Desktop,Downloads,.config/xfce4/xfconf/xfce-perchannel-xml,.config/autostart}
    
    # Auto-start terminal with fastfetch on Termux XFCE startup
    cat > "$HOME/.config/autostart/terminal-fastfetch.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=xfce4-terminal -e "bash -c 'fastfetch; exec bash'"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Terminal with Fastfetch
EOF
    
    # Initialize XFCE settings to prevent first-run errors
    msg info "Initializing XFCE settings..."
    export DISPLAY=:0
    xfconf-query -c xfce4-session -p /startup/compat/LaunchGNOME -n -t bool -s false 2>/dev/null || true
    xfconf-query -c xfce4-session -p /general/FailsafeSessionName -n -t string -s "Failsafe" 2>/dev/null || true
    
    # Setup aliases
    msg info "Configuring shell aliases..."
    if ! grep -q "# XFCE Setup Aliases" "$PREFIX/etc/bash.bashrc"; then
        cat >> "$PREFIX/etc/bash.bashrc" <<EOF

# XFCE Setup Aliases
alias start_debian='xrun start_debian'
alias ls='eza -lF --icons'
alias cat='bat'
eval "\$(starship init bash)"
fastfetch
EOF
    else
        msg ok "Aliases already configured, skipping..."
    fi
    
    # Install Debian proot
    if [[ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]]; then
        msg ok "Debian proot already installed, skipping..."
    else
        msg info "Installing Debian proot environment..."
        proot-distro install debian
    fi
    
    # Setup Debian packages
    msg info "Configuring Debian environment..."
    proot-distro login debian --shared-tmp -- apt update
    proot-distro login debian --shared-tmp -- apt upgrade -y
    
    msg info "Installing Debian packages..."
    for deb_pkg in sudo xfce4 xfce4-goodies dbus-x11 conky-all htop
    do
        if proot-distro login debian --shared-tmp -- dpkg -l "$deb_pkg" 2>/dev/null | grep -q "^ii"; then
            msg ok "$deb_pkg already installed, skipping..."
        else
            msg info "Installing Debian package: $deb_pkg..."
            if ! proot-distro login debian --shared-tmp -- apt install -y "$deb_pkg"; then
                msg error "Failed to install Debian package: $deb_pkg"
                exit 1
            fi
        fi
    done
    msg ok "Debian packages installed successfully"
    
    # Create Debian user
    if ! proot-distro login debian --shared-tmp -- id "$username" &>/dev/null; then
        msg info "Creating Debian user: $username..."
        proot-distro login debian --shared-tmp -- groupadd -f storage
        proot-distro login debian --shared-tmp -- groupadd -f wheel
        proot-distro login debian --shared-tmp -- useradd -m -g users -G wheel,audio,video,storage -s /bin/bash "$username"
    else
        msg ok "Debian user $username already exists, skipping..."
    fi
    
    # Configure sudo
    if ! grep -q "$username ALL=(ALL) NOPASSWD:ALL" "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers" 2>/dev/null; then
        msg info "Configuring sudo for $username..."
        chmod u+rw "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers"
        echo "$username ALL=(ALL) NOPASSWD:ALL" >> "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers"
        chmod u-w "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers"
    else
        msg ok "Sudo already configured for $username, skipping..."
    fi
    
    # Auto-start terminal with fastfetch on Debian XFCE startup
    mkdir -p "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username/.config/autostart"
    cat > "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username/.config/autostart/terminal-fastfetch.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=xfce4-terminal -e "bash -c 'fastfetch; exec bash'"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Terminal with Fastfetch
EOF
    chown -R $(stat -c '%u:%g' "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username") "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username/.config" 2>/dev/null || true
    
    # Setup Debian environment
    if ! grep -q "export DISPLAY=:0" "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username/.bashrc" 2>/dev/null; then
        msg info "Configuring Debian user environment..."
        cat >> "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username/.bashrc" <<EOF

export DISPLAY=:0
alias ls='eza -lF --icons' 2>/dev/null || alias ls='ls --color=auto'
alias cat='bat' 2>/dev/null || alias cat='cat'
eval "\$(starship init bash)" 2>/dev/null || true
fastfetch 2>/dev/null || true
EOF
    else
        msg ok "Debian user environment already configured, skipping..."
    fi
    
    # Setup hardware acceleration in Debian (Turnip driver for Adreno 6XX/7XX)
    if [[ ! -f "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/lib/aarch64-linux-gnu/libvulkan_freedreno.so" ]]; then
        msg info "Configuring hardware acceleration..."
        proot-distro login debian --shared-tmp -- bash -c "
            curl -sLO https://github.com/MatrixhKa/mesa-turnip/releases/download/24.1.0/mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb
            apt install -y ./mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb
            rm mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb
        "
    else
        msg ok "Hardware acceleration already configured, skipping..."
    fi
    
    # Install aesthetic packages in Debian
    msg info "Installing aesthetic packages in Debian..."
    
    # Setup eza repository first (required for eza installation)
    if ! proot-distro login debian --shared-tmp -- dpkg -l eza 2>/dev/null | grep -q "^ii"; then
        proot-distro login debian --shared-tmp -- bash -c "
            apt install -y gpg curl
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
            echo 'deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main' | tee /etc/apt/sources.list.d/gierens.list
            chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
            apt update
        " 2>/dev/null || true
    fi
    
    # Install aesthetic packages
    for aesthetic_pkg in eza bat fastfetch
    do
        if proot-distro login debian --shared-tmp -- dpkg -l "$aesthetic_pkg" 2>/dev/null | grep -q "^ii"; then
            msg ok "$aesthetic_pkg already installed, skipping..."
        else
            msg info "Installing $aesthetic_pkg..."
            proot-distro login debian --shared-tmp -- apt install -y "$aesthetic_pkg" || msg warn "Failed to install $aesthetic_pkg (non-critical)"
        fi
    done
    
    # Install starship (uses different installation method)
    if proot-distro login debian --shared-tmp -- command -v starship &>/dev/null; then
        msg ok "starship already installed, skipping..."
    else
        msg info "Installing starship..."
        proot-distro login debian --shared-tmp -- bash -c "curl -sS https://starship.rs/install.sh | sh -s -- -y" || msg warn "Failed to install starship (non-critical)"
    fi
    
    msg ok "Aesthetic packages installation complete"
    
    # Download xrun utility
    msg info "Installing xrun utility..."
    curl -sL https://raw.githubusercontent.com/Jessiebrig/termux_dual_xfce/main/xrun -o "$PREFIX/bin/xrun"
    chmod +x "$PREFIX/bin/xrun"
    
    # Install app-installer
    msg info "Installing app-installer utility..."
    if [[ -d "$HOME/.config/App-Installer" ]]; then
        msg ok "App-Installer already installed, skipping..."
    else
        git clone -q https://github.com/phoenixbyrd/App-Installer.git "$HOME/.config/App-Installer" || msg warn "Failed to clone App-Installer (may already exist)"
    fi
    chmod +x "$HOME/.config/App-Installer"/* 2>/dev/null || true
    
    cat > "$PREFIX/share/applications/app-installer.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=App Installer
Exec=$HOME/.config/App-Installer/app-installer
Icon=package-install
Categories=System;
Terminal=false
EOF
    
    # Completion message
    echo ""
    echo "┌────────────────────────────────────┐"
    echo "│      Installation Complete!        │"
    echo "└────────────────────────────────────┘"
    echo ""
    msg ok "Setup finished successfully!"
    echo ""
    echo "Available commands:"
    echo -e "  ${C_OK}xrun${C_RESET}                    - Quick access menu with numbered options"
    echo -e "  ${C_OK}xrun start_xfce${C_RESET}         - Launch native Termux XFCE desktop"
    echo -e "  ${C_OK}xrun start_debian_xfce${C_RESET}  - Launch Debian proot XFCE desktop"
    echo -e "  ${C_OK}xrun start_debian${C_RESET}       - Enter Debian proot terminal"
    echo -e "  ${C_OK}xrun drun <command>${C_RESET}     - Run Debian commands from Termux"
    echo -e "  ${C_OK}xrun dgpu <command>${C_RESET}     - Run Debian apps with hardware acceleration"
    echo -e "  ${C_OK}xrun dfps <command>${C_RESET}     - Run Debian with hardware acceleration and FPS overlay"
    echo -e "  ${C_OK}xrun kill_termux_x11${C_RESET}    - Stop all Termux-X11 sessions"
    echo ""
    
    # Prompt for full output on success
    if [[ -n "${FULL_OUTPUT_FILE:-}" && -f "$FULL_OUTPUT_FILE" ]]; then
        set +e  # Disable errexit for log viewing
        echo -n "View log file? (y/N): " > /dev/tty
        read -r response < /dev/tty
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sed -i "1i=== Press 'q' to close this log viewer ===\n" "$LOG_FILE" 2>/dev/null
            echo "=== Press 'q' to close this log viewer ===" >> "$LOG_FILE" 2>/dev/null
            less "$LOG_FILE" || true
        fi
        
        echo "" > /dev/tty
        echo -n "Full output: [v] View  [s] Save & view  [Enter] Skip: " > /dev/tty
        read -r full_response < /dev/tty
        case "$full_response" in
            [Vv])
                less "$FULL_OUTPUT_FILE" || true
                rm -f "$FULL_OUTPUT_FILE"
                ;;
            [Ss])
                TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                SAVED_FILE="$HOME/xfce_install_full_${TIMESTAMP}.txt"
                cp "$FULL_OUTPUT_FILE" "$SAVED_FILE"
                # Keep only the 5 most recent saved files
                ls -t "$HOME"/xfce_install_full_*.txt 2>/dev/null | tail -n +6 | xargs -r rm -f 2>/dev/null
                sed -i "1i=== Press 'q' to close this log viewer ===\n" "$SAVED_FILE" 2>/dev/null
                echo "=== Press 'q' to close this log viewer ===" >> "$SAVED_FILE" 2>/dev/null
                echo "Saved to ~/xfce_install_full_${TIMESTAMP}.txt" > /dev/tty
                less "$SAVED_FILE" || true
                rm -f "$FULL_OUTPUT_FILE"
                ;;
            *)
                rm -f "$FULL_OUTPUT_FILE"
                ;;
        esac
        set -e  # Re-enable errexit
    fi
    
    source "$PREFIX/etc/bash.bashrc" 2>/dev/null || true
    termux-reload-settings 2>/dev/null || true
    
    # Ensure clean exit
    exit 0
}

# Check if script command is available and wrap execution
if command -v script &>/dev/null && [[ "${1:-}" != "--no-script" ]]; then
    # Set and export FULL_OUTPUT_FILE so it's available in the sub-shell
    export FULL_OUTPUT_FILE="${FULL_OUTPUT_FILE:-$HOME/.xfce_install_full_temp.txt}"
    script -q -c "bash '${BASH_SOURCE[0]}' --no-script" "$FULL_OUTPUT_FILE"
else
    main "${@:-}"
fi
