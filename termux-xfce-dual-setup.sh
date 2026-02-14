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

# Log file
LOG_FILE="$HOME/xfce_install.log"
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

# Cleanup on exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ]; then
        # Add quit instruction at top and bottom
        sed -i '1i=== Press '"'"'q'"'"' to close this log viewer ===' "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        echo "=== Press 'q' to close this log viewer ===" >> "$LOG_FILE"
        msg error "Installation failed."
        echo ""
        echo -n "View log file? (y/N): " > /dev/tty
        read -r response < /dev/tty
        if [[ "$response" =~ ^[Yy]$ ]]; then
            less "$LOG_FILE" || cat "$LOG_FILE"
        fi
    fi
}
trap cleanup EXIT

# System verification
verify_system() {
    log "FUNCTION: verify_system() - Starting system verification"
    echo ""
    echo "┌──────────────────────────────────────────┐"
    echo "│     Pre-Installation System Checks       │"
    echo "└──────────────────────────────────────────┘"
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
        if [[ $total_ram -gt 4096 ]]; then
            msg ok "System RAM: ${total_ram}MB (sufficient)"
        else
            msg warn "System RAM: ${total_ram}MB (4GB+ recommended)"
            ((warnings++))
        fi
    fi
    
    echo ""
    if [[ $errors -gt 0 ]]; then
        msg error "System requirements not met ($errors critical error(s))"
        echo ""
        echo "Requirements:"
        echo "  • Android OS (any version)"
        echo "  • ARM64/aarch64 device"
        echo "  • Termux from GitHub (not Play Store)"
        echo "  • 8GB+ free storage space"
        echo "  • 4GB+ RAM recommended"
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
    echo "┌──────────────────────────────────┐"
    echo "│  Native + Debian XFCE Setup      │"
    echo "└──────────────────────────────────┘"
    echo ""
    
    verify_system
    
    msg info "This will install:"
    echo "  • Native Termux XFCE desktop"
    echo "  • Debian proot with XFCE"
    echo "  • Hardware acceleration support"
    echo ""
    msg warn "Termux-X11 app required: https://github.com/termux/termux-x11/releases"
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
            read username < /dev/tty
            if [[ -z "$username" ]]; then
                msg error "Username cannot be empty"
                exit 1
            fi
            echo "$username" > "$USERNAME_FILE"
        fi
    else
        echo ""
        echo -n "Enter username for Debian proot: " > /dev/tty
        read username < /dev/tty
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
        msg warn "Package update failed, trying mirror selection..."
        termux-change-repo
        # Wait for termux-change-repo to complete and clear locks
        sleep 2
        rm -f "$PREFIX/var/lib/apt/lists/lock" "$PREFIX/var/lib/dpkg/lock" "$PREFIX/var/lib/dpkg/lock-frontend" 2>/dev/null
        msg info "Retrying package update..."
        if ! pkg update -y; then
            msg error "Failed to update package lists after changing mirror"
            echo ""
            echo "Troubleshooting:"
            echo "  1. Check your internet connection"
            echo "  2. Try a different mirror in termux-change-repo"
            echo "  3. Restart Termux and try again"
            echo ""
            exit 1
        fi
    fi
    msg ok "Package lists updated successfully"
    
    # Setup storage
    if [[ ! -d ~/storage ]]; then
        msg info "Setting up storage access..."
        termux-setup-storage
    else
        msg ok "Storage access already configured"
    fi
    
    # Upgrade packages
    msg info "Upgrading existing packages..."
    if ! pkg upgrade -y -o Dpkg::Options::="--force-confold"; then
        msg warn "Package upgrade encountered issues, continuing..."
    fi
    
    # Install core dependencies
    msg info "Installing core dependencies..."
    for pkg_name in proot-distro x11-repo tur-repo pulseaudio git; do
        if pkg list-installed 2>/dev/null | grep -q "^$pkg_name/"; then
            msg ok "$pkg_name already installed, skipping..."
        else
            msg info "Installing $pkg_name..."
            if ! pkg install -y "$pkg_name"; then
                msg error "Failed to install $pkg_name"
                exit 1
            fi
        fi
    done
    msg ok "Core dependencies installed successfully"
    
    # Install XFCE and essentials
    msg info "Installing XFCE desktop environment..."
    for pkg_name in xfce4 xfce4-goodies xfce4-pulseaudio-plugin termux-x11-nightly \
        virglrenderer-android firefox starship \
        fastfetch papirus-icon-theme eza bat; do
        if pkg list-installed 2>/dev/null | grep -q "^$pkg_name/"; then
            msg ok "$pkg_name already installed, skipping..."
        else
            msg info "Installing $pkg_name..."
            if ! pkg install -y "$pkg_name"; then
                msg error "Failed to install $pkg_name"
                echo ""
                echo "Possible issues:"
                echo "  1. Network connection unstable"
                echo "  2. Mirror is down - try: termux-change-repo"
                echo "  3. Insufficient storage space"
                exit 1
            fi
        fi
    done
    
    # Try to install optional Vulkan driver (may not be available on all devices)
    msg info "Installing optional GPU drivers..."
    pkg install -y mesa-vulkan-icd-freedreno-dri3 2>/dev/null || msg warn "Vulkan driver not available for this device (optional)"
    
    msg ok "XFCE desktop environment installed successfully"
    
    # Create directories
    msg info "Creating directory structure..."
    mkdir -p "$HOME"/{Desktop,Downloads,.config/xfce4/xfconf/xfce-perchannel-xml,.config/autostart}
    
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
alias start_debian='proot-distro login debian --user $username --shared-tmp'
alias ls='eza -lF --icons'
alias cat='bat'
eval "\$(starship init bash)"
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
    for deb_pkg in sudo xfce4 xfce4-goodies dbus-x11 conky-all; do
        msg info "Installing Debian package: $deb_pkg..."
        if ! proot-distro login debian --shared-tmp -- apt install -y "$deb_pkg"; then
            msg error "Failed to install Debian package: $deb_pkg"
            exit 1
        fi
    done
    msg ok "Debian packages installed successfully"
    
    # Create Debian user
    msg info "Creating Debian user: $username..."
    proot-distro login debian --shared-tmp -- groupadd -f storage
    proot-distro login debian --shared-tmp -- groupadd -f wheel
    proot-distro login debian --shared-tmp -- useradd -m -g users -G wheel,audio,video,storage -s /bin/bash "$username" 2>/dev/null || true
    
    # Configure sudo
    chmod u+rw "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers"
    echo "$username ALL=(ALL) NOPASSWD:ALL" >> "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers"
    chmod u-w "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/sudoers"
    
    # Setup Debian environment
    cat >> "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username/.bashrc" <<EOF

export DISPLAY=:0
alias ls='eza -lF --icons' 2>/dev/null || alias ls='ls --color=auto'
alias cat='bat' 2>/dev/null || alias cat='cat'
eval "\$(starship init bash)" 2>/dev/null || true
EOF
    
    # Setup hardware acceleration in Debian
    msg info "Configuring hardware acceleration..."
    proot-distro login debian --shared-tmp -- bash -c "
        curl -sLO https://github.com/phoenixbyrd/Termux_XFCE/raw/main/mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb
        apt install -y ./mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb
        rm mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb
    "
    
    # Create start script
    msg info "Creating launcher scripts..."
    cat > "$PREFIX/bin/start_xfce" <<'STARTEOF'
#!/bin/bash
kill -9 $(pgrep -f "termux.x11") 2>/dev/null

# Setup audio
if [[ "$(getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')" == "samsung" ]]; then
    LD_PRELOAD=/system/lib64/libskcodec.so pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
else
    pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
fi

export PULSE_SERVER=127.0.0.1
export XDG_RUNTIME_DIR=${TMPDIR}
export DISPLAY=:0

# Ensure D-Bus directories exist
mkdir -p "$XDG_RUNTIME_DIR"

termux-x11 :0 >/dev/null &
sleep 3

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
sleep 1

# GPU detection
gpu_info="$(getprop ro.hardware.egl) $(getprop ro.hardware.vulkan)"
if echo "$gpu_info" | grep -iq "adreno"; then
    MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.3COMPAT MESA_GLES_VERSION_OVERRIDE=3.2 virgl_test_server_android &
elif echo "$gpu_info" | grep -iq "mali"; then
    MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.3COMPAT MESA_GLES_VERSION_OVERRIDE=3.2 virgl_test_server_android --angle-gl &
fi

dbus-launch --exit-with-session env GALLIUM_DRIVER=virpipe xfce4-session &
STARTEOF
    chmod +x "$PREFIX/bin/start_xfce"
    
    # Create start_debian_xfce script
    cat > "$PREFIX/bin/start_debian_xfce" <<'DEBIANEOF'
#!/bin/bash
username=$(basename $PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/*)
proot-distro login debian --user $username --shared-tmp -- env DISPLAY=:0 dbus-launch --exit-with-session xfce4-session
DEBIANEOF
    chmod +x "$PREFIX/bin/start_debian_xfce"
    
    # Create utility scripts
    cat > "$PREFIX/bin/prun" <<'PRUNEOF'
#!/bin/bash
username=$(basename $PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/*)
proot-distro login debian --user $username --shared-tmp -- env DISPLAY=:0 "$@"
PRUNEOF
    chmod +x "$PREFIX/bin/prun"
    
    cat > "$PREFIX/bin/zrun" <<'ZRUNEOF'
#!/bin/bash
username=$(basename $PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/*)
proot-distro login debian --user $username --shared-tmp -- env DISPLAY=:0 MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform "$@"
ZRUNEOF
    chmod +x "$PREFIX/bin/zrun"
    
    cat > "$PREFIX/bin/zrunhud" <<'ZHUDEOF'
#!/bin/bash
username=$(basename $PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/*)
proot-distro login debian --user $username --shared-tmp -- env DISPLAY=:0 MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform GALLIUM_HUD=fps "$@"
ZHUDEOF
    chmod +x "$PREFIX/bin/zrunhud"
    
    cat > "$PREFIX/bin/kill_termux_x11" <<'KILLEOF'
#!/bin/bash
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 >/dev/null 2>&1
pkill -f termux
KILLEOF
    chmod +x "$PREFIX/bin/kill_termux_x11"
    
    # Create cp2menu utility
    cat > "$PREFIX/bin/cp2menu" <<'MENUEOF'
#!/bin/bash
debian_apps="$PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/share/applications"
termux_apps="$PREFIX/share/applications"

if [[ ! -d "$debian_apps" ]]; then
    echo "Error: Debian applications directory not found"
    exit 1
fi

echo "Available Debian applications:"
ls "$debian_apps"/*.desktop 2>/dev/null | nl

echo -n "Enter number to copy (or 'all' for all): " > /dev/tty
read choice < /dev/tty

if [[ "$choice" == "all" ]]; then
    cp "$debian_apps"/*.desktop "$termux_apps/"
    echo "All applications copied"
else
    file=$(ls "$debian_apps"/*.desktop 2>/dev/null | sed -n "${choice}p")
    if [[ -f "$file" ]]; then
        cp "$file" "$termux_apps/"
        echo "Copied: $(basename "$file")"
    else
        echo "Invalid selection"
    fi
fi
MENUEOF
    chmod +x "$PREFIX/bin/cp2menu"
    
    # Download launch menu
    msg info "Installing launch menu..."
    curl -sL https://raw.githubusercontent.com/Jessiebrig/termux_dual_xfce/main/launch -o "$PREFIX/bin/launch"
    chmod +x "$PREFIX/bin/launch"
    
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
    
    # Setup Conky
    msg info "Configuring Conky system monitor..."
    curl -sL https://github.com/phoenixbyrd/Termux_XFCE/raw/main/conky.tar.gz | tar -xz -C "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username/"
    
    cp "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/share/applications/conky.desktop" "$HOME/.config/autostart/"
    sed -i "s|^Exec=.*|Exec=prun conky -c .config/conky/Alterf/Alterf.conf|" "$HOME/.config/autostart/conky.desktop"
    
    # Completion message
    echo ""
    echo "┌──────────────────────────────────┐"
    echo "│  Installation Complete!          │"
    echo "└──────────────────────────────────┘"
    echo ""
    msg ok "Setup finished successfully!"
    echo ""
    echo "Available commands:"
    echo "  ${C_OK}start_xfce${C_RESET}        - Launch native Termux XFCE"
    echo "  ${C_OK}start_debian_xfce${C_RESET} - Launch Debian XFCE"
    echo "  ${C_OK}start_debian${C_RESET}      - Enter Debian proot CLI"
    echo "  ${C_OK}prun${C_RESET}              - Run Debian commands"
    echo "  ${C_OK}zrun${C_RESET}              - Run with hardware acceleration"
    echo "  ${C_OK}zrunhud${C_RESET}           - Run with HW accel + FPS display"
    echo "  ${C_OK}cp2menu${C_RESET}           - Copy Debian apps to menu"
    echo "  ${C_OK}launch${C_RESET}            - Interactive menu for all commands"
    echo ""
    
    set +u  # Disable unbound variable check for sourcing
    source "$PREFIX/etc/bash.bashrc" 2>/dev/null || true
    termux-reload-settings 2>/dev/null || true
}

main "$@"
