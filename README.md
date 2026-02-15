# Termux XFCE Desktop Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-v1.0.0-blue.svg)](https://github.com/Jessiebrig/termux_dual_xfce/releases/tag/v1.0.0)

A lightweight script to set up native XFCE desktop environment and Debian proot with XFCE in Termux. Optimized for speed and efficiency with a streamlined installation process.

## Key Features
- **Dual Desktop Environment**: Native Termux XFCE + Debian proot XFCE
- **Fast Installation**: Streamlined setup process with essential packages only
- **Hardware Acceleration**: GPU support with auto-detection (Adreno/Mali) and logging
- **Modern CLI Tools**: Starship prompt, Fastfetch, eza, bat pre-installed
- **System Monitor**: Conky integration for system stats
- **Auto-launch Terminal**: Fastfetch displays automatically on desktop startup
- **User-Friendly**: Simple username setup and automated configuration

## Requirements

- **Operating System**: Android (any version)
- **Architecture**: ARM64/aarch64 (32-bit armeabi is not supported - too slow for full desktop experience)
- **Termux**: Must be from [GitHub](https://github.com/termux/termux-app/releases) or F-Droid (NOT Play Store)
- **Termux-X11**: Required from [GitHub releases](https://github.com/termux/termux-x11/releases)
- **Storage**: 8GB+ free space recommended
- **RAM**: 3GB+ recommended

## Quick Start

### Step 1: Download Required Apps

Download and install both apps on your Android device:

1. **Termux** - [Download from GitHub](https://github.com/termux/termux-app/releases/latest) or [F-Droid](https://f-droid.org/packages/com.termux/) (select arm64-v8a version)
2. **Termux-X11** - [Download from GitHub](https://github.com/termux/termux-x11/releases/latest) (select arm64-v8a version)

⚠️ **Important**: Use Termux from GitHub or F-Droid for full functionality.

### Step 2: Run Installation

Once both Termux and Termux-X11 are installed, open Termux and copy-paste this command, then follow the installation prompts:

```bash
curl -sL https://raw.githubusercontent.com/Jessiebrig/termux_dual_xfce/refs/heads/feature/gpu-autostart/termux-xfce-dual-setup.sh -o termux-xfce-dual-setup.sh && bash termux-xfce-dual-setup.sh
```

## Installation Details

During installation, you'll be prompted to:
1. Enter a username for the Debian proot environment
2. Grant storage permissions (if not already granted)

Installation logs are saved to `~/xfce_install.log` for troubleshooting.

## What Gets Installed

### Native Termux Environment
- XFCE4 desktop with goodies and plugins
- Firefox browser
- Starship prompt, Fastfetch (auto-displays on startup), eza, bat, htop
- Papirus icon theme
- Hardware acceleration (virglrenderer, optional Vulkan) with status logging

### Debian Proot Environment
- XFCE4 desktop with goodies
- Conky system monitor (auto-starts with desktop)
- Starship prompt, eza, bat, fastfetch (auto-displays on startup), htop
- Hardware acceleration (mesa-vulkan-kgsl/Turnip) with status logging
- Sudo configured for passwordless access

## Starting the Desktop

### Quick Launch Menu

For easy access to all commands, use the interactive menu:

```bash
xrun
```

This provides a numbered menu to quickly start desktops or run utilities.

### Native Termux XFCE

Launch the native XFCE desktop environment:

```bash
xrun start_xfce
```

This command initiates a Termux-X11 session, starts the XFCE4 desktop, and opens the Termux-X11 app directly into the desktop. A terminal with Fastfetch system info will automatically appear on startup, along with GPU acceleration status logging.

### Debian Proot CLI

Access the Debian proot environment from terminal:

```bash
xrun start_debian
```

Note: The display is pre-configured in the Debian proot environment, allowing you to launch GUI applications directly from the terminal.

### Debian Proot XFCE

Launch Debian XFCE desktop environment:

```bash
xrun start_debian_xfce
```

This starts a full Debian XFCE desktop session within the proot environment. A terminal with Fastfetch system info will automatically appear on startup, along with GPU acceleration status logging.

## Available Commands

### Interactive Menu
- `xrun` - Quick access menu with numbered options for all commands below

### Desktop Launchers
- `xrun start_xfce` - Launch native Termux XFCE desktop
- `xrun start_debian_xfce` - Launch Debian proot XFCE desktop
- `xrun start_debian` - Enter Debian proot terminal (display pre-configured for GUI apps)

### Proot Utilities
- `xrun drun <command>` - Run Debian commands from Termux without entering proot shell
- `xrun dgpu <command>` - Run Debian apps with hardware acceleration enabled
- `xrun dfps <command>` - Run Debian with hardware acceleration and FPS overlay

### System Tools
- `xrun kill_termux_x11` - Stop all Termux-X11 sessions
- `app-installer` - GUI tool for installing apps beyond standard repositories
- `~/xfce_gpu.log` - View GPU acceleration status logs for both environments

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
