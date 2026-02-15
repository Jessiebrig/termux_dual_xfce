# Termux XFCE Desktop Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-v1.0.0-blue.svg)](https://github.com/Jessiebrig/termux_dual_xfce/releases/tag/v1.0.0)

A lightweight script to set up native XFCE desktop environment and Debian proot with XFCE in Termux. Optimized for speed and efficiency with a streamlined installation process.

## Key Features
- **Dual Desktop Environment**: Native Termux XFCE + Debian proot XFCE
- **Fast Installation**: Streamlined setup process with essential packages only
- **Hardware Acceleration**: GPU support with auto-detection (Adreno/Mali)
- **Modern CLI Tools**: Starship prompt, Fastfetch, eza, bat pre-installed
- **System Monitor**: Conky integration for system stats
- **User-Friendly**: Simple username setup and automated configuration

## Requirements

- **Operating System**: Android (any version)
- **Architecture**: ARM64/aarch64 (32-bit armeabi is not supported - too slow for full desktop experience)
- **Termux**: Must be from [GitHub](https://github.com/termux/termux-app/releases) or F-Droid (NOT Play Store)
- **Termux-X11**: Required from [GitHub releases](https://github.com/termux/termux-x11/releases)
- **Storage**: 8GB+ free space recommended
- **RAM**: 3GB+ recommended

## Installation

```bash
curl -sL https://raw.githubusercontent.com/Jessiebrig/termux_dual_xfce/refs/heads/main/termux-xfce-dual-setup.sh -o termux-xfce-dual-setup.sh && bash termux-xfce-dual-setup.sh
```

During installation, you'll be prompted to:
1. Enter a username for the Debian proot environment
2. Grant storage permissions (if not already granted)

Installation logs are saved to `~/xfce_install.log` for troubleshooting.

## What Gets Installed

### Native Termux Environment
- XFCE4 desktop with goodies and plugins
- Firefox browser
- Starship prompt, Fastfetch, eza, bat, htop
- Papirus icon theme
- Hardware acceleration (virglrenderer, optional Vulkan)

### Debian Proot Environment
- XFCE4 desktop with goodies
- Conky system monitor (auto-starts with desktop)
- Starship prompt, eza, bat, fastfetch, htop
- Hardware acceleration (mesa-vulkan-kgsl)
- Sudo configured for passwordless access

### Special Features
- GPU auto-detection (Adreno vs Mali configuration)
- Shared /tmp between Termux and Debian
- Display pre-configured (DISPLAY=:0) in both environments

## Starting the Desktop

### Quick Launch Menu

For easy access to all commands, use the interactive menu:

```bash
launch
```

This provides a numbered menu to quickly start desktops or run utilities.

### Native Termux XFCE

Launch the native XFCE desktop environment:

```bash
start_xfce
```

This command initiates a Termux-X11 session, starts the XFCE4 desktop, and opens the Termux-X11 app directly into the desktop.

### Debian Proot CLI

Access the Debian proot environment from terminal:

```bash
start_debian
```

Note: The display is pre-configured in the Debian proot environment, allowing you to launch GUI applications directly from the terminal.

### Debian Proot XFCE

Launch Debian XFCE desktop environment:

```bash
start_debian_xfce
```

This starts a full Debian XFCE desktop session within the proot environment.

## Available Commands

### Interactive Menu
- `launch` - Quick access menu with numbered options for all commands below

### Desktop Launchers
- `start_xfce` - Launch native Termux XFCE desktop
- `start_debian_xfce` - Launch Debian proot XFCE desktop
- `start_debian` - Enter Debian proot terminal (display pre-configured for GUI apps)

### Proot Utilities
- `prun <command>` - Run Debian commands from Termux without entering proot shell
- `zrun <command>` - Run Debian apps with hardware acceleration enabled
- `zrunhud <command>` - Run with hardware acceleration and FPS overlay

### System Tools
- `cp2menu` - Import Debian application shortcuts to Termux XFCE menu
- `kill_termux_x11` - Stop all Termux-X11 sessions
- `app-installer` - GUI tool for installing apps beyond standard repositories

## About

Created and maintained by [Jessiebrig](https://github.com/Jessiebrig). This project aims to provide an easy-to-use, automated setup for running full desktop environments on Android devices through Termux.

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
