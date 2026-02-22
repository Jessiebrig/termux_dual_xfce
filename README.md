# Termux XFCE Desktop Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-v1.2.2-blue.svg)](https://github.com/Jessiebrig/termux_dual_xfce/releases/tag/v1.2.2)

A lightweight script to set up native XFCE desktop environment and Debian proot with XFCE in Termux. Optimized for speed and efficiency with a streamlined installation process.

## Key Features
- **No Root Required**: Works on non-rooted Android devices
- **Dual Desktop Environment**: Native Termux XFCE + Debian proot XFCE
- **Hardware Acceleration**: GPU support with auto-detection (Adreno/Mali), Vulkan drivers, and real-time status logging
- **Experimental GPU Driver Management**: Custom Turnip driver installation for Adreno GPUs (tested on Xperia 5 II)
- **Dynamic Branch Selection**: Choose stable or experimental versions for testing new features
- **Fast Installation**: Streamlined setup with essential packages only
- **Modern CLI Tools**: Starship prompt, Fastfetch (auto-displays on startup), eza, bat
- **System Monitor**: Conky integration
- **User-Friendly**: Simple username setup and automated configuration

## Requirements

- **Operating System**: Android 7.0+ (Nougat or higher)
- **Root Access**: NOT required - works on non-rooted devices
- **Architecture**: ARM64/aarch64 recommended (32-bit ARM supported but not recommended due to performance limitations)
- **Storage**: 8GB+ free space recommended
- **RAM**: 3GB+ recommended

⚠️ **Important**: 
- Use Termux from GitHub or F-Droid (NOT Play Store) for full functionality
- Download APK matching your device architecture (arm64-v8a for 64-bit, armeabi-v7a for 32-bit), or use universal APK if unsure

## Quick Start

### Step 1: Download Required Apps

Download and install both apps on your Android device:

1. **Termux** - [Download from GitHub](https://github.com/termux/termux-app/releases/latest) or [F-Droid](https://f-droid.org/packages/com.termux/)
2. **Termux-X11** - [Download from GitHub](https://github.com/termux/termux-x11/releases/latest)

### Step 2: Run Installation

Once both Termux and Termux-X11 are installed, open Termux and copy-paste this command, then follow the installation prompts:

```bash
curl -sL https://raw.githubusercontent.com/Jessiebrig/termux_dual_xfce/main/initialize.sh -o initialize.sh && bash initialize.sh
```

![Start Installation](Screenshots/Installation/3.%20start%20installation.jpg)

This will fetch available branches and let you choose which version to install (stable or experimental).

![Enter to Proceed](Screenshots/Installation/4.%20Enter%20to%20proceed.jpg)

## Installation Details

During installation, you'll be prompted to:
1. Choose installation type: Both (Native Termux XFCE + Debian proot) or Native Termux XFCE only
2. Enter a username for the Debian proot environment (if installing both)
3. Grant storage permissions (if not already granted)

Installation logs are saved to `~/xfce_install.log` for troubleshooting.

## What Gets Installed

### Native Termux Environment
- XFCE4 desktop with goodies and plugins
- Firefox and Chromium browsers
- Starship prompt, Fastfetch, eza, bat, htop
- Papirus icon theme
- Hardware acceleration (ZINK, VIRGL, Turnip)
- glmark2 OpenGL benchmark tool

### Debian Proot Environment
- XFCE4 desktop with goodies
- Firefox ESR and Chromium browsers
- Conky system monitor (conky-std)
- Starship prompt, eza, bat, fastfetch, htop
- Hardware acceleration (ZINK, VIRGL, Turnip)
- glmark2-x11 OpenGL benchmark tool
- Sudo configured for passwordless access

## Available Commands

### Quick Launch Menu

```bash
xrun
```

Interactive menu with numbered options for all commands below.

![Main Menu](Screenshots/Installation/8.%20Main%20Menu.jpg)

### Desktop Launchers
- `xrun xfce` - Launch native Termux XFCE desktop

![Hardware Acceleration](Screenshots/Installation/9.%20Hardware%20Acceleration.jpg)

- `xrun debian_xfce` - Launch Debian proot XFCE desktop
- `xrun debian` - Enter Debian proot shell (interactive, DISPLAY pre-configured)

### System Tools
- `xrun gpu` - Manage GPU drivers (experimental, Adreno optimization)
- `xrun kill_termux_x11` - Stop all Termux-X11 sessions
- `xrun update` - Run initializer to update xrun and setup scripts

### Log Files
- `~/xfce_gpu.log` - GPU acceleration status and runtime logs
- `~/xfce_install.log` - Installation summary log
- `~/xfce_install_full.txt` - Full installation output (optional, saved on request)

## Hardware Acceleration Performance

**Tested Configuration:**
- **Device**: Sony Xperia 5 II (XQ-AS42)
- **Chipset**: Qualcomm Snapdragon 865
- **GPU**: Adreno 650

**Native Termux XFCE with Turnip Hardware Acceleration:**

System Information:

![Fastfetch + htop](Screenshots/Post%20Installation/fastfetch+htop.png)

GPU Benchmark Performance:

![glmark2 Score](Screenshots/Post%20Installation/glmark2%20start.png)

![glmark2 Score](Screenshots/Post%20Installation/glmark2%20score.png)

Browser Performance:

![Firefox](Screenshots/Post%20Installation/Mozilla.png)

![Firefox YouTube](Screenshots/Post%20Installation/Mozilla%20YT.png)

![Chromium GPU](Screenshots/Post%20Installation/Chromium%20GPU.png)

## GPU Driver Management (Experimental)

⚠️ **Research & Testing Area**

This section allows testing custom Turnip drivers in Debian proot environment.

**Current Status (as of February 22, 2026):**
- Custom Turnip drivers can be installed in Debian proot, but provide **no significant performance improvement**
- Based on research with available drivers, Turnip requires direct access to the GPU kernel device which proot cannot provide
- Benchmarks may show high scores using glmark2, but real applications cannot utilize the GPU acceleration
- This is a testing area for future driver versions that may resolve these limitations
- See [PROOT_GPU_LIMITATIONS.md](docs/PROOT_GPU_LIMITATIONS.md) for detailed technical analysis

### Features
- Install custom Turnip drivers for testing purposes
- Restore default Mesa drivers
- Real-time driver status monitoring
- Additional driver versions may be added in the future

### Usage
```bash
xrun gpu
```

Or select option 5 from the interactive menu.

**Note**: This feature is for research and testing only. For actual GPU acceleration in proot, use VIRGL/ZINK server-client architecture.

## 🙏 Credits & Acknowledgments

This project builds upon the Termux desktop community's work:
- **[Termux](https://github.com/termux)** - The powerful terminal emulator for Android
- **[droidmaster](https://www.youtube.com/watch?v=fgGOizUDQpY)** - Hardware acceleration setup and configuration
- **[phoenixbyrd](https://github.com/phoenixbyrd/Termux_XFCE)** - Automation and setup script inspiration

Special thanks to:
- The Termux community for creating an incredible terminal emulator and ecosystem
- Every Android enthusiast who has spent hours configuring Linux environments on mobile devices
- Amazon Q for helping debug and refine the vision during development

Designed for users who want a quick, efficient dual desktop setup on Android.

## ☕ Support This Project

If this project has saved you time and made setting up XFCE on Android easier, consider supporting its continued development:

- ☕ [Buy me a coffee](https://ko-fi.com/jessiebrig) - Help fuel late-night coding sessions and new features!
- 💳 [PayPal](https://www.paypal.com/paypalme/jessiebrig) - Direct support via PayPal

Your support helps keep this project free and continuously improving for the community. Every contribution, no matter how small, makes a difference! 🙏
