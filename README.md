# Termux XFCE Desktop Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A lightweight script to set up native XFCE desktop environment and Debian proot with XFCE in Termux. Optimized for speed and efficiency with a streamlined installation process.

## Key Features
- **Dual Desktop Environment**: Native Termux XFCE + Debian proot XFCE
- **Fast Installation**: Streamlined setup process with essential packages only
- **Hardware Acceleration**: GPU support for both environments
- **User-Friendly**: Simple username setup and automated configuration

## Installation

```bash
curl -sL https://raw.githubusercontent.com/Jessiebrig/termux_dual_xfce/refs/heads/main/termux-xfce-dual-setup.sh -o termux-xfce-dual-setup.sh && bash termux-xfce-dual-setup.sh
```

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
- `app-installer` - GUI tool for installing apps beyond standard repositories

## Credits

This project builds upon the Termux desktop community's work:
- **[Termux](https://github.com/termux)** - The powerful terminal emulator for Android
- **[droidmaster](https://www.youtube.com/watch?v=fgGOizUDQpY)** - Hardware acceleration setup and configuration
- **[phoenixbyrd](https://github.com/phoenixbyrd/Termux_XFCE)** - Automation and setup script inspiration

Designed for users who want a quick, efficient dual desktop setup on Android.
