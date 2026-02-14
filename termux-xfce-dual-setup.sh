#!/bin/bash

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
exec 2>>"$LOG_FILE"

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
}

# Cleanup on exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ]; then
        msg error "Installation failed. Check $LOG_FILE for details."
    fi
}
trap cleanup EXIT

# System verification
verify_system() {
    echo ""
    echo "┌──────────────────────────────────┐"
    echo "│  Pre-Installation Checks         │"
    echo "└──────────────────────────────────┘"
    echo ""
    
    local errors=0
    
    # Check Android
    if [[ "$(uname -o)" == "Android" ]]; then
        msg ok "Android $(getprop ro.build.version.release)"
    else
        msg error "Not running on Android"
        ((errors++))
    fi
    
    # Check architecture
    if [[ "$(uname -m)" == "aarch64" ]]; then
        msg ok "Architecture: aarch64"
    else
        msg error "Unsupported architecture (requires aarch64)"
        ((errors++))
    fi
    
    # Check Termux environment
    if [[ -d "$PREFIX" ]]; then
        msg ok "Termux environment detected"
    else
        msg error "Termux PREFIX not found"
        ((errors++))
    fi
    
    # Check storage
    local free_kb=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $free_kb -gt 3145728 ]]; then
        msg ok "Storage: $(df -h "$HOME" | awk 'NR==2 {print $4}') available"
    else
        msg warn "Low storage: $(df -h "$HOME" | awk 'NR==2 {print $4}') (3GB+ recommended)"
    fi
    
    echo ""
    if [[ $errors -gt 0 ]]; then
        msg error "System requirements not met"
        exit 1
    fi
    msg ok "System verification passed"
    echo ""
}

# Main installation
main() {
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
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    
    # Get username
    echo ""
    read -p "Enter username for Debian proot: " username
    if [[ -z "$username" ]]; then
        msg error "Username cannot be empty"
        exit 1
    fi
    
    # Update repositories
    msg info "Updating package repositories..."
    termux-change-repo
    
    # Setup storage
    if [[ ! -d ~/storage ]]; then
        msg info "Setting up storage access..."
        termux-setup-storage
    else
        msg ok "Storage access already configured"
    fi
    
    # Upgrade packages
    msg info "Upgrading existing packages..."
    pkg upgrade -y -o Dpkg::Options::="--force-confold"
    
    # Install core dependencies
    msg info "Installing core dependencies..."
    pkg install -y wget proot-distro x11-repo tur-repo pulseaudio git
    
    # Install XFCE and essentials
    msg info "Installing XFCE desktop environment..."
    pkg install -y xfce4 xfce4-goodies xfce4-pulseaudio-plugin \
        termux-x11-nightly virglrenderer-android mesa-vulkan-icd-freedreno-dri3 \
        firefox starship fastfetch papirus-icon-theme eza bat
    
    # Create directories
    msg info "Creating directory structure..."
    mkdir -p "$HOME"/{Desktop,Downloads,.config/xfce4/xfconf/xfce-perchannel-xml,.config/autostart}
    
    # Setup aliases
    msg info "Configuring shell aliases..."
    cat >> "$PREFIX/etc/bash.bashrc" <<EOF

# XFCE Setup Aliases
alias start_debian='proot-distro login debian --user $username --shared-tmp'
alias ls='eza -lF --icons'
alias cat='bat'
eval "\$(starship init bash)"
EOF
    
    # Install Debian proot
    msg info "Installing Debian proot environment..."
    proot-distro install debian
    
    # Setup Debian packages
    msg info "Configuring Debian environment..."
    proot-distro login debian --shared-tmp -- apt update
    proot-distro login debian --shared-tmp -- apt upgrade -y
    proot-distro login debian --shared-tmp -- apt install -y sudo xfce4 xfce4-goodies \
        dbus-x11 conky-all
    
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
        wget -q https://github.com/phoenixbyrd/Termux_XFCE/raw/main/mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb
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

dbus-launch --exit-with-session env DISPLAY=:0 GALLIUM_DRIVER=virpipe xfce4-session &
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

read -p "Enter number to copy (or 'all' for all): " choice

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
    
    # Create launch menu
    cat > "$PREFIX/bin/launch" <<'LAUNCHEOF'
#!/bin/bash

# Color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

while true; do
    clear
    echo ""
    echo "┌────────────────────────────────────────┐"
    echo "│       Termux XFCE Quick Launch         │"
    echo "└────────────────────────────────────────┘"
    echo ""
    echo "${CYAN}Desktop Environments:${NC}"
    echo "  ${GREEN}1${NC} - Start Native Termux XFCE"
    echo "      Launch XFCE desktop in Termux-X11"
    echo ""
    echo "  ${GREEN}2${NC} - Start Debian XFCE"
    echo "      Launch XFCE desktop in Debian proot"
    echo ""
    echo "  ${GREEN}3${NC} - Start Debian CLI"
    echo "      Enter Debian proot terminal"
    echo ""
    echo "${CYAN}Utilities:${NC}"
    echo "  ${GREEN}4${NC} - prun <command>"
    echo "      Run Debian commands from Termux"
    echo ""
    echo "  ${GREEN}5${NC} - zrun <command>"
    echo "      Run with hardware acceleration"
    echo ""
    echo "  ${GREEN}6${NC} - zrunhud <command>"
    echo "      Run with HW accel + FPS display"
    echo ""
    echo "  ${GREEN}7${NC} - cp2menu"
    echo "      Copy Debian apps to Termux menu"
    echo ""
    echo "  ${GREEN}8${NC} - Kill Termux-X11"
    echo "      Stop all X11 sessions"
    echo ""
    echo "  ${YELLOW}0${NC} - Exit"
    echo ""
    read -p "Select option [0-8]: " choice
    
    case $choice in
        1)
            echo ""
            echo "${GREEN}Starting Native Termux XFCE...${NC}"
            start_xfce
            exit 0
            ;;
        2)
            echo ""
            echo "${GREEN}Starting Debian XFCE...${NC}"
            start_debian_xfce
            exit 0
            ;;
        3)
            echo ""
            echo "${GREEN}Entering Debian CLI...${NC}"
            start_debian
            exit 0
            ;;
        4)
            echo ""
            read -p "Enter command to run: " cmd
            if [[ -n "$cmd" ]]; then
                prun $cmd
            fi
            read -p "Press Enter to continue..."
            ;;
        5)
            echo ""
            read -p "Enter command to run: " cmd
            if [[ -n "$cmd" ]]; then
                zrun $cmd
            fi
            read -p "Press Enter to continue..."
            ;;
        6)
            echo ""
            read -p "Enter command to run: " cmd
            if [[ -n "$cmd" ]]; then
                zrunhud $cmd
            fi
            read -p "Press Enter to continue..."
            ;;
        7)
            echo ""
            cp2menu
            read -p "Press Enter to continue..."
            ;;
        8)
            echo ""
            echo "${YELLOW}Killing Termux-X11...${NC}"
            kill_termux_x11
            echo "Done."
            read -p "Press Enter to continue..."
            ;;
        0)
            echo ""
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo ""
            echo "${YELLOW}Invalid option. Please try again.${NC}"
            sleep 1
            ;;
    esac
done
LAUNCHEOF
    chmod +x "$PREFIX/bin/launch"
    
    # Install app-installer
    msg info "Installing app-installer utility..."
    git clone -q https://github.com/phoenixbyrd/App-Installer.git "$HOME/.config/App-Installer"
    chmod +x "$HOME/.config/App-Installer"/*
    
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
    wget -q https://github.com/phoenixbyrd/Termux_XFCE/raw/main/conky.tar.gz
    tar -xzf conky.tar.gz -C "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/$username/"
    rm conky.tar.gz
    
    cp "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/share/applications/conky.desktop" "$HOME/.config/autostart/"
    sed -i "s|^Exec=.*|Exec=prun conky -c .config/conky/Alterf/Alterf.conf|" "$HOME/.config/autostart/conky.desktop"
    
    # Completion message
    clear
    echo ""
    echo "┌──────────────────────────────────┐"
    echo "│  Installation Complete!          │"
    echo "└──────────────────────────────────┘"
    echo ""
    msg ok "Setup finished successfully!"
    echo ""
    echo "Available commands:"
    echo "  ${GREEN}start_xfce${NC}        - Launch native Termux XFCE"
    echo "  ${GREEN}start_debian_xfce${NC} - Launch Debian XFCE"
    echo "  ${GREEN}start_debian${NC}      - Enter Debian proot CLI"
    echo "  ${GREEN}prun${NC}              - Run Debian commands"
    echo "  ${GREEN}zrun${NC}              - Run with hardware acceleration"
    echo "  ${GREEN}zrunhud${NC}           - Run with HW accel + FPS display"
    echo "  ${GREEN}cp2menu${NC}           - Copy Debian apps to menu"
    echo "  ${GREEN}launch${NC}            - Interactive menu for all commands"
    echo ""
    
    source "$PREFIX/etc/bash.bashrc"
    termux-reload-settings
}

main "$@"
