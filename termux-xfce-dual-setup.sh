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
        { echo "=== Press 'q' to close this log viewer ==="; echo ""; cat "$LOG_FILE"; } > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
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
                    [[ "$FULL_OUTPUT_FILE" != "$LOG_FILE" ]] && rm -f "$FULL_OUTPUT_FILE"
                    ;;
                [Ss])
                    SAVED_FILE="$HOME/xfce_install_full.txt"
                    cp "$FULL_OUTPUT_FILE" "$SAVED_FILE" || true
                    { echo "=== Press 'q' to close this log viewer ==="; echo ""; cat "$SAVED_FILE"; } > "$SAVED_FILE.tmp" && mv "$SAVED_FILE.tmp" "$SAVED_FILE" 2>/dev/null || true
                    echo "=== Press 'q' to close this log viewer ===" >> "$SAVED_FILE" 2>/dev/null || true
                    echo "Saved to ~/xfce_install_full.txt"
                    less "$SAVED_FILE" || true
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
        local api_level=$(getprop ro.build.version.sdk)
        if [[ $api_level -ge 24 ]]; then
            msg ok "Operating System: Android $android_version (API $api_level)"
        else
            msg warn "Operating System: Android $android_version (API $api_level) - Android 7.0+ recommended"
            ((warnings++))
        fi
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
    elif [[ "$arch" == "armv7l" || "$arch" == "armv8l" ]]; then
        msg warn "CPU Architecture: $arch (32-bit ARM - performance may be limited)"
        ((warnings++))
    else
        msg error "Unsupported architecture: $arch"
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
        echo "  • ARM64/aarch64 device (32-bit ARM supported but not recommended)"
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
    
    # Display branch information
    if [[ -n "${INSTALLER_BRANCH:-}" ]]; then
        msg info "Branch: $INSTALLER_BRANCH"
        echo ""
    fi
    
    verify_system
    
    msg info "This will install:"
    echo "  • Native Termux XFCE desktop"
    echo "  • Debian proot with XFCE"
    echo "  • Hardware acceleration support"
    echo ""
    echo "Press Enter to continue or Ctrl+C to cancel..."
    read -r
    
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
    
    # Setup storage
    if [[ ! -d ~/storage ]]; then
        echo ""
        msg info "Requesting storage access..."
        echo "Tap 'Allow' when prompted"
        termux-setup-storage
    else
        msg ok "Storage access already configured"
    fi
    
    # Upgrade packages (this also updates package lists)
    msg info "Updating and upgrading packages..."
    if ! pkg upgrade -y -o Dpkg::Options::="--force-confold"; then
        msg warn "Upgrade failed, please select a mirror..."
        termux-change-repo
        sleep 2
        rm -f "$PREFIX/var/lib/apt/lists/lock" "$PREFIX/var/lib/dpkg/lock" "$PREFIX/var/lib/dpkg/lock-frontend" 2>/dev/null
        msg info "Retrying package upgrade..."
        if ! pkg upgrade -y -o Dpkg::Options::="--force-confold"; then
            msg error "Failed to upgrade packages after changing mirror"
            show_troubleshooting
            exit 1
        fi
    fi
    msg ok "Packages updated successfully"
    
    # Install core dependencies
    msg info "Installing core dependencies..."
    for pkg_name in proot-distro x11-repo tur-repo pulseaudio util-linux git
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
    for pkg_name in xfce4 xfce4-goodies termux-x11-nightly \
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
    
    # Auto-start terminal on Termux XFCE startup
    cat > "$HOME/.config/autostart/terminal-fastfetch.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=xfce4-terminal
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Terminal
EOF
    
    # Initialize XFCE settings to prevent first-run errors
    msg info "Initializing XFCE settings..."
    export DISPLAY=:0
    xfconf-query -c xfce4-session -p /startup/compat/LaunchGNOME -n -t bool -s false 2>&1 | tee -a "$LOG_FILE" || msg warn "xfconf-query LaunchGNOME failed (non-critical)"
    xfconf-query -c xfce4-session -p /general/FailsafeSessionName -n -t string -s "Failsafe" 2>&1 | tee -a "$LOG_FILE" || msg warn "xfconf-query FailsafeSessionName failed (non-critical)"
    
    # Setup aliases
    msg info "Configuring shell aliases..."
    if ! grep -q "# XFCE Setup Aliases" "$PREFIX/etc/bash.bashrc"; then
        cat >> "$PREFIX/etc/bash.bashrc" <<EOF

# XFCE Setup Aliases
alias start_debian='xrun debian'
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
    for deb_pkg in sudo xfce4 xfce4-goodies dbus-x11 htop
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
    
    # Install conky-std separately (requires explicit selection)
    if proot-distro login debian --shared-tmp -- dpkg -l conky-std 2>/dev/null | grep -q "^ii"; then
        msg ok "conky-std already installed, skipping..."
    else
        msg info "Installing Debian package: conky-std..."
        proot-distro login debian --shared-tmp -- apt install -y conky-std || msg warn "Failed to install conky-std (non-critical)"
    fi
    
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
    
    # Auto-start terminal on Debian XFCE startup
    mkdir -p "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username/.config/autostart"
    cat > "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username/.config/autostart/terminal-fastfetch.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=xfce4-terminal
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Terminal
EOF
    chown -R $(stat -c '%u:%g' "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username") "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username/.config" 2>&1 | tee -a "$LOG_FILE" || msg warn "chown failed (non-critical)"
    
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
            apt install -y curl
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
            echo 'deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main' | tee /etc/apt/sources.list.d/gierens.list
            chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
            apt update
        " 2>&1 | tee -a "$LOG_FILE" || msg warn "eza repository setup failed (non-critical)"
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
        proot-distro login debian --shared-tmp -- bash -c "curl -sS https://starship.rs/install.sh | sh -s -- -y" 2>&1 | tee -a "$LOG_FILE" || msg warn "Failed to install starship (non-critical)"
    fi
    
    msg ok "Aesthetic packages installation complete"
    
    # Download xrun utility
    msg info "Installing xrun utility..."
    
    # Use branch passed from launcher, or detect from script path, or default to main
    if [[ -n "${INSTALLER_BRANCH:-}" ]]; then
        XRUN_BRANCH="$INSTALLER_BRANCH"
        msg info "Using branch from launcher: $XRUN_BRANCH"
    else
        # Fallback: auto-detect from script path
        if [[ "${BASH_SOURCE[0]}" == *"feature/"* ]] || [[ "$0" == *"feature/"* ]]; then
            XRUN_BRANCH=$(echo "${BASH_SOURCE[0]}" | grep -oP 'feature/[^/]+' | head -1)
        else
            XRUN_BRANCH="main"
        fi
        msg info "Auto-detected branch: $XRUN_BRANCH"
    fi
    
    msg info "Downloading xrun from $XRUN_BRANCH branch..."
    if curl -sL "https://raw.githubusercontent.com/Jessiebrig/termux_dual_xfce/$XRUN_BRANCH/xrun" -o "$PREFIX/bin/xrun"; then
        chmod +x "$PREFIX/bin/xrun"
        cp "$PREFIX/bin/xrun" "$HOME/xrun" 2>/dev/null || true
        chmod +x "$HOME/xrun" 2>/dev/null || true
    else
        msg error "Failed to download xrun utility from $XRUN_BRANCH"
        exit 1
    fi
    
    # Verify xrun is accessible
    if command -v xrun &>/dev/null; then
        msg ok "xrun utility installed successfully"
    else
        msg warn "xrun installed at $PREFIX/bin/xrun but not in PATH"
        msg warn "You can run it with: $PREFIX/bin/xrun or ~/xrun"
    fi
    
    # Completion message
    echo ""
    echo "┌────────────────────────────────────┐"
    echo "│      Installation Complete!        │"
    echo "└────────────────────────────────────┘"
    echo ""
    msg ok "Setup finished successfully!"
    echo ""
    echo "Available commands:"
    echo -e "  ${C_OK}xrun${C_RESET} or ${C_OK}~/xrun${C_RESET}        - Quick access menu with numbered options"
    echo -e "  ${C_OK}xrun xfce${C_RESET}              - Launch native Termux XFCE desktop"
    echo -e "  ${C_OK}xrun debian_xfce${C_RESET}       - Launch Debian proot XFCE desktop"
    echo -e "  ${C_OK}xrun debian${C_RESET}            - Enter Debian proot terminal"
    echo -e "  ${C_OK}xrun drun <command>${C_RESET}     - Run Debian commands from Termux"
    echo -e "  ${C_OK}xrun dgpu <command>${C_RESET}     - Run Debian apps with hardware acceleration"
    echo -e "  ${C_OK}xrun dfps <command>${C_RESET}     - Run Debian with hardware acceleration and FPS overlay"
    echo -e "  ${C_OK}xrun kill_termux_x11${C_RESET}    - Stop all Termux-X11 sessions"
    echo ""
    echo "Note: If 'xrun' is not found, use '~/xrun' or restart Termux"
    echo ""
    
    # Prompt for full output on success
    if [[ -n "${FULL_OUTPUT_FILE:-}" && -f "$FULL_OUTPUT_FILE" ]]; then
        set +e  # Disable errexit for log viewing
        echo -n "View log file? (y/N): " > /dev/tty
        read -r response < /dev/tty
        if [[ "$response" =~ ^[Yy]$ ]]; then
            { echo "=== Press 'q' to close this log viewer ==="; echo ""; cat "$LOG_FILE"; } > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
            echo "=== Press 'q' to close this log viewer ===" >> "$LOG_FILE"
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
                SAVED_FILE="$HOME/xfce_install_full.txt"
                cp "$FULL_OUTPUT_FILE" "$SAVED_FILE"
                { echo "=== Press 'q' to close this log viewer ==="; echo ""; cat "$SAVED_FILE"; } > "$SAVED_FILE.tmp" && mv "$SAVED_FILE.tmp" "$SAVED_FILE"
                echo "=== Press 'q' to close this log viewer ===" >> "$SAVED_FILE"
                echo "Saved to ~/xfce_install_full.txt" > /dev/tty
                less "$SAVED_FILE" || true
                rm -f "$FULL_OUTPUT_FILE"
                ;;
            *)
                rm -f "$FULL_OUTPUT_FILE"
                ;;
        esac
    fi
    
    # Don't source bashrc as it may fail with fastfetch/starship in non-interactive context
    # termux-reload-settings will handle the reload
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
