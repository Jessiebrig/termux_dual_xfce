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

# Generic file download from GitHub repository
download_from_repo() {
    local file_path="$1"        # Path in repo (e.g., ".conkyrc" or "mesa-vulkan-kgsl.deb")
    local target_path="$2"      # Local destination path
    local description="$3"      # Description for messages (e.g., "Conky configuration")
    
    # Determine branch
    local branch
    if [[ -n "${INSTALLER_BRANCH:-}" ]]; then
        branch="$INSTALLER_BRANCH"
    elif [[ "${BASH_SOURCE[0]}" == *"feature/"* ]] || [[ "$0" == *"feature/"* ]]; then
        branch=$(echo "${BASH_SOURCE[0]}" | grep -oP 'feature/[^/]+' | head -1)
    else
        branch="main"
    fi
    
    msg info "Downloading $description from $branch..."
    if curl -L "https://raw.githubusercontent.com/Jessiebrig/termux_dual_xfce/$branch/$file_path" -o "$target_path"; then
        msg ok "$description downloaded successfully"
        return 0
    else
        msg warn "Failed to download $description, skipping..."
        return 1
    fi
}

# Download conky config helper function (wrapper for backward compatibility)
download_conky_config() {
    local target_path="$1"
    local env_name="$2"
    download_from_repo ".conkyrc" "$target_path" "Conky configuration for $env_name"
}

# Install Termux package helper
install_pkg() {
    local pkg_name="$1"
    if pkg list-installed 2>/dev/null | grep -q "^$pkg_name/"; then
        msg ok "$pkg_name already installed, skipping..."
        return 0
    else
        msg info "Installing $pkg_name..."
        if pkg install -y "$pkg_name"; then
            return 0
        else
            return 1
        fi
    fi
}

# Install Debian package helper
install_deb_pkg() {
    local pkg_name="$1"
    if proot-distro login debian --shared-tmp -- dpkg -l "$pkg_name" 2>/dev/null | grep -q "^ii"; then
        msg ok "$pkg_name already installed, skipping..."
        return 0
    else
        msg info "Installing Debian package: $pkg_name..."
        if proot-distro login debian --shared-tmp -- apt install -y "$pkg_name"; then
            return 0
        else
            return 1
        fi
    fi
}

# Create autostart desktop file helper
create_autostart() {
    local dir="$1"
    local name="$2"
    local exec="$3"
    mkdir -p "$dir"
    cat > "$dir/${name}.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=$exec
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=$name
EOF
}

# Get GPU info helper
get_gpu_info() {
    local egl=$(getprop ro.hardware.egl)
    local vulkan=$(getprop ro.hardware.vulkan)
    if [[ "$egl" == "$vulkan" ]]; then
        echo "$egl"
    else
        echo "$egl / $vulkan"
    fi
}

# Log GPU and graphics versions
log_gpu_versions() {
    if pkg list-installed 2>/dev/null | grep -q "^mesa"; then
        local mesa_version=$(pkg list-installed 2>/dev/null | grep "^mesa" | head -1 | awk '{print $2}')
        msg info "Termux Mesa/Zink version: $mesa_version"
    fi
    
    if command -v vulkaninfo &>/dev/null; then
        local vulkan_version=$(vulkaninfo 2>/dev/null | grep -i "vulkan" | grep -i "version" | head -1 | awk '{print $NF}')
        if [[ -n "$vulkan_version" ]]; then
            msg info "Vulkan API version: $vulkan_version"
        else
            log "vulkaninfo command found but no version detected"
        fi
    else
        log "vulkaninfo not installed"
    fi
}

# Install optional Vulkan drivers (device-specific)
install_optional_vulkan_drivers() {
    local gpu_info=$(get_gpu_info)
    log_gpu_versions
    msg info "Installing optional GPU drivers for: $gpu_info"
    
    # Check and install vulkan-loader-android
    if pkg install --dry-run vulkan-loader-android 2>/dev/null | grep -q "vulkan-loader-android"; then
        pkg install -y vulkan-loader-android 2>&1 | tee -a "$LOG_FILE" && msg ok "vulkan-loader-android: installed"
    else
        log "vulkan-loader-android: not available in repository, using system default"
    fi
    
    # Check and install mesa-vulkan-icd-freedreno-dri3 (Adreno)
    if pkg install --dry-run mesa-vulkan-icd-freedreno-dri3 2>/dev/null | grep -q "mesa-vulkan-icd-freedreno-dri3"; then
        pkg install -y mesa-vulkan-icd-freedreno-dri3 2>&1 | tee -a "$LOG_FILE" && msg ok "mesa-vulkan-icd-freedreno-dri3: installed (Adreno)"
    else
        log "mesa-vulkan-icd-freedreno-dri3: not available in repository, using system default"
    fi
    
    # Check and install mesa-vulkan-icd-panfrost (Mali)
    if pkg install --dry-run mesa-vulkan-icd-panfrost 2>/dev/null | grep -q "mesa-vulkan-icd-panfrost"; then
        pkg install -y mesa-vulkan-icd-panfrost 2>&1 | tee -a "$LOG_FILE" && msg ok "mesa-vulkan-icd-panfrost: installed (Mali)"
    else
        log "mesa-vulkan-icd-panfrost: not available in repository, using system default"
    fi
}

# Prompt for username input
prompt_for_username() {
    local username
    echo "" > /dev/tty
    echo "Username requirements: lowercase letters, numbers, hyphens, underscores (must start with letter)" > /dev/tty
    echo "Example: 'Device@123' becomes 'device123'" > /dev/tty
    while true; do
        echo -n "Enter username: " > /dev/tty
        read -r input < /dev/tty
        input=$(echo "$input" | xargs)  # Trim leading/trailing whitespace
        log "DEBUG: User input: '$input'"
        
        if [[ -z "$input" ]]; then
            msg error "Username cannot be empty" > /dev/tty
            continue
        fi
        
        # Clean username
        username=$(echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g' | sed 's/^[^a-z]\+//')
        log "DEBUG: Cleaned username: '$username'"
        
        if [[ -z "$username" ]]; then
            msg error "No valid characters. Use letters, numbers, hyphens, underscores" > /dev/tty
            continue
        fi
        
        if [[ "$input" != "$username" ]]; then
            echo -e "${C_WARN}⚠${C_RESET} Formatted to: $username" > /dev/tty
            echo -n "Accept? (y/N): " > /dev/tty
            read -r confirm < /dev/tty
            log "DEBUG: User confirmation: '$confirm'"
            [[ ! "$confirm" =~ ^[Yy]$ ]] && continue
        fi
        
        echo "$username"
        return 0
    done
}

# Get or create Debian username
get_debian_username() {
    local USERNAME_FILE="$HOME/.xfce_debian_username"
    local username=""
    
    log "DEBUG: get_debian_username() called"
    
    if [[ -f "$USERNAME_FILE" ]]; then
        username=$(tr -d '\n\r\t ' < "$USERNAME_FILE" | xargs)
        log "DEBUG: Found saved username file: $username"
        msg ok "Using saved username: $username"
    elif [[ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]]; then
        log "DEBUG: Debian directory exists, checking for existing user"
        # Detect existing username from Debian home directory
        username=$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/"* 2>/dev/null | grep -v "^root$" | head -n1)
        log "DEBUG: Detected username from Debian home: '$username'"
        if [[ -n "$username" && "$username" != "*" ]]; then
            msg ok "Detected existing Debian user: $username"
            echo "$username" > "$USERNAME_FILE"
            log "DEBUG: Saved detected username to file"
        else
            log "DEBUG: No valid Debian user found, prompting user"
            username=$(prompt_for_username)
            echo -n "$username" > "$USERNAME_FILE"
            log "DEBUG: Saved username to file"
        fi
    else
        log "DEBUG: Fresh install, no Debian directory, prompting user"
        username=$(prompt_for_username)
        echo -n "$username" > "$USERNAME_FILE"
        log "DEBUG: Saved username to file"
    fi
    
    log "DEBUG: Returning username: '$username'"
    echo "$username"
}

# Setup Termux storage access
setup_storage() {
    if [[ ! -d ~/storage ]]; then
        echo ""
        msg info "Requesting storage access..."
        echo "Tap 'Allow' when prompted"
        termux-setup-storage
    else
        msg ok "Storage access already configured"
    fi
}

# Upgrade Termux packages
upgrade_packages() {
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
}

# Install core Termux dependencies
install_core_dependencies() {
    msg info "Installing core dependencies..."
    for pkg_name in proot-distro x11-repo tur-repo pulseaudio util-linux git
    do
        if ! install_pkg "$pkg_name"; then
            msg error "Failed to install $pkg_name"
            show_troubleshooting
            exit 1
        fi
    done
    msg ok "Core dependencies installed successfully"
}

# Install native Termux XFCE packages
install_termux_xfce() {
    msg info "Installing native Termux XFCE desktop..."
    # Core packages from main/x11-repo (critical)
    for pkg_name in xfce4 xfce4-goodies termux-x11-nightly \
        virglrenderer-android mesa-zink virglrenderer-mesa-zink \
        vulkan-tools papirus-icon-theme starship fastfetch eza bat htop
    do
        if ! install_pkg "$pkg_name"; then
            msg error "Failed to install $pkg_name"
            show_troubleshooting
            exit 1
        fi
    done
    
    # TUR packages (non-critical, may fail on some devices)
    msg info "Installing TUR packages (browsers and benchmarks)..."
    for tur_pkg in firefox chromium glmark2
    do
        msg info "Installing $tur_pkg..."
        if pkg install -y "$tur_pkg" 2>&1 | tee -a "$LOG_FILE"; then
            msg ok "$tur_pkg installed successfully"
        else
            msg warn "$tur_pkg installation failed (non-critical, skipping...)"
        fi
    done
}

# Setup Termux XFCE configuration
setup_termux_xfce_config() {
    msg info "Creating directory structure..."
    mkdir -p "$HOME"/{Desktop,Downloads,.config/xfce4/xfconf/xfce-perchannel-xml,.config/autostart}
    
    msg info "Initializing XFCE settings..."
    export DISPLAY=:0
    xfconf-query -c xfce4-session -p /startup/compat/LaunchGNOME -n -t bool -s false 2>&1 | tee -a "$LOG_FILE" || msg warn "xfconf-query LaunchGNOME failed (non-critical)"
    xfconf-query -c xfce4-session -p /general/FailsafeSessionName -n -t string -s "Failsafe" 2>&1 | tee -a "$LOG_FILE" || msg warn "xfconf-query FailsafeSessionName failed (non-critical)"
    
    create_autostart "$HOME/.config/autostart" "Terminal" "xfce4-terminal"
    
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
}

# Install and setup Debian proot
setup_debian_proot() {
    local DEBIAN_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
    
    if [[ -d "$DEBIAN_ROOT" ]]; then
        msg ok "Debian proot already installed, skipping..."
    else
        msg info "Installing Debian proot environment..."
        proot-distro install debian
    fi
    
    msg info "Configuring Debian environment..."
    proot-distro login debian --shared-tmp -- apt update
    proot-distro login debian --shared-tmp -- apt upgrade -y
    
    msg info "Installing Debian packages..."
    for deb_pkg in sudo xfce4 xfce4-goodies dbus-x11 firefox-esr chromium htop curl
    do
        if ! install_deb_pkg "$deb_pkg"; then
            msg error "Failed to install Debian package: $deb_pkg"
            exit 1
        fi
    done
    
    # Install glmark2-x11 (X11 variant of glmark2 benchmark tool)
    install_deb_pkg glmark2-x11 || msg warn "Failed to install glmark2-x11 (non-critical)"
    
    install_deb_pkg conky-std || msg warn "Failed to install conky-std (non-critical)"
    msg ok "Debian packages installed successfully"
}

# Setup Debian user and permissions
setup_debian_user() {
    local username="$1"
    local DEBIAN_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
    
    if ! proot-distro login debian --shared-tmp -- id "$username" &>/dev/null; then
        msg info "Creating Debian user: $username..."
        proot-distro login debian --shared-tmp -- groupadd -f storage
        proot-distro login debian --shared-tmp -- groupadd -f wheel
        proot-distro login debian --shared-tmp -- useradd -m -g users -G wheel,audio,video,storage -s /bin/bash "$username"
    else
        msg ok "Debian user $username already exists, skipping..."
    fi
    
    if ! grep -q "$username ALL=(ALL) NOPASSWD:ALL" "$DEBIAN_ROOT/etc/sudoers" 2>/dev/null; then
        msg info "Configuring sudo for $username..."
        chmod u+rw "$DEBIAN_ROOT/etc/sudoers"
        echo "$username ALL=(ALL) NOPASSWD:ALL" >> "$DEBIAN_ROOT/etc/sudoers"
        chmod u-w "$DEBIAN_ROOT/etc/sudoers"
    else
        msg ok "Sudo already configured for $username, skipping..."
    fi
}

# Setup Debian XFCE configuration
setup_debian_xfce_config() {
    local username="$1"
    local DEBIAN_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
    
    create_autostart "$DEBIAN_ROOT/home/$username/.config/autostart" "Terminal" "xfce4-terminal"
    create_autostart "$DEBIAN_ROOT/home/$username/.config/autostart" "Conky" "conky"
    download_conky_config "$DEBIAN_ROOT/home/$username/.conkyrc" "Debian"
    chown -R $(stat -c '%u:%g' "$DEBIAN_ROOT/home/$username") "$DEBIAN_ROOT/home/$username/.config" 2>&1 | tee -a "$LOG_FILE" || msg warn "chown failed (non-critical)"
    
    if ! grep -q "export DISPLAY=:0" "$DEBIAN_ROOT/home/$username/.bashrc" 2>/dev/null; then
        msg info "Configuring Debian user environment..."
        cat >> "$DEBIAN_ROOT/home/$username/.bashrc" <<EOF

export DISPLAY=:0
alias ls='eza -lF --icons' 2>/dev/null || alias ls='ls --color=auto'
alias cat='bat' 2>/dev/null || alias cat='cat'
eval "\$(starship init bash)" 2>/dev/null || true
EOF
    else
        msg ok "Debian user environment already configured, skipping..."
    fi
}

# Install Debian GPU drivers
install_debian_gpu_drivers() {
    local DEBIAN_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
    
    # Check if Turnip driver already installed
    if [[ -f "$DEBIAN_ROOT/usr/lib/aarch64-linux-gnu/libvulkan_freedreno.so" ]]; then
        msg ok "Turnip GPU driver already installed, skipping..."
        return 0
    fi
    
    # Try to install Turnip driver (Adreno GPUs only)
    msg info "Installing Turnip GPU driver for Debian (Adreno GPUs)..."
    
    local deb_file="mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb"
    local temp_deb="/tmp/$deb_file"
    
    if download_from_repo "$deb_file" "$temp_deb" "Turnip GPU driver"; then
        if proot-distro login debian --shared-tmp -- bash -c "apt install -y $temp_deb && rm -f $temp_deb" 2>&1 | tee -a "$LOG_FILE"; then
            msg ok "Turnip GPU driver installed successfully"
        else
            msg warn "Turnip GPU driver installation failed (non-critical)"
            msg warn "Note: Turnip is for Adreno GPUs only. Mali GPUs will use software rendering."
        fi
    else
        msg warn "Turnip GPU driver download failed (non-critical)"
        msg warn "You can retry by running: xrun update"
        msg warn "Or install manually in proot: proot-distro login debian"
    fi
}

# Install Debian user tools
install_debian_user_tools() {
    local DEBIAN_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
    
    msg info "Installing user tools in Debian..."
    
    if ! proot-distro login debian --shared-tmp -- dpkg -l eza 2>/dev/null | grep -q "^ii"; then
        proot-distro login debian --shared-tmp -- bash -c "
            mkdir -p /etc/apt/keyrings
            curl -L https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
            echo 'deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main' | tee /etc/apt/sources.list.d/gierens.list
            chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
            apt update
        " 2>&1 | tee -a "$LOG_FILE" || msg warn "eza repository setup failed (non-critical)"
    fi
    
    for user_pkg in eza bat fastfetch
    do
        install_deb_pkg "$user_pkg" || msg warn "Failed to install $user_pkg (non-critical)"
    done
    
    if proot-distro login debian --shared-tmp -- command -v starship &>/dev/null; then
        msg ok "starship already installed, skipping..."
    else
        msg info "Installing starship..."
        proot-distro login debian --shared-tmp -- bash -c "curl -L https://starship.rs/install.sh | sh -s -- -y" 2>&1 | tee -a "$LOG_FILE" || msg warn "Failed to install starship (non-critical)"
    fi
    
    msg ok "User tools installation complete"
}

# System verification
verify_system() {
    log "FUNCTION: verify_system() - Starting system verification"
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
    
    # Display script file info
    if [[ -f "${BASH_SOURCE[0]}" ]]; then
        SETUP_DATE=$(ls -l "${BASH_SOURCE[0]}" 2>/dev/null | awk '{print $6, $7, $8}' || stat -c %y "${BASH_SOURCE[0]}" 2>/dev/null || stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "${BASH_SOURCE[0]}" 2>/dev/null || date -r "${BASH_SOURCE[0]}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
        echo ""
        echo "File date: ${SETUP_DATE}"
    fi
    
    echo ""
    echo "┌────────────────────────────────────┐"
    echo "│   Native + Debian XFCE Setup       │"
    echo "└────────────────────────────────────┘"
    echo ""
    
    # Display branch information
    if [[ -n "${INSTALLER_BRANCH:-}" ]]; then
        msg info "GitHub Branch: $INSTALLER_BRANCH"
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
    local username
    username=$(get_debian_username)
    
    # Clear any stale locks
    rm -f "$PREFIX/var/lib/apt/lists/lock" "$PREFIX/var/lib/dpkg/lock" "$PREFIX/var/lib/dpkg/lock-frontend" 2>/dev/null
    
    # Setup Termux environment
    setup_storage
    upgrade_packages
    install_core_dependencies
    install_termux_xfce
    install_optional_vulkan_drivers
    msg ok "XFCE desktop environment installed successfully"
    setup_termux_xfce_config
    
    # Setup Debian environment
    setup_debian_proot
    setup_debian_user "$username"
    setup_debian_xfce_config "$username"
    install_debian_gpu_drivers
    install_debian_user_tools
    
    # Completion message
    echo ""
    echo "┌────────────────────────────────────┐"
    echo "│      Installation Complete!        │"
    echo "└────────────────────────────────────┘"
    echo ""
    msg ok "Setup finished successfully!"
    echo ""
    echo "Run 'xrun' to launch the quick access menu, or 'xrun help' for all commands."
    echo ""
    echo "Tip: Use 'xrun update' to check for updates anytime."
    echo ""
    echo "Note: If 'xrun' is not found, use '~/xrun' or restart Termux."
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
