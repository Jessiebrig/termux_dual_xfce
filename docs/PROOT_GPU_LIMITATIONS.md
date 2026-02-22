# GPU Acceleration in Debian Proot: Adreno/Turnip Research

⚠️ **IMPORTANT**: This research focuses primarily on **Adreno GPUs with Turnip drivers**. VIRGL/ZINK configurations were not extensively tested. Information provided is based on limited testing and may contain inaccuracies.

## Test Environment
- **Device**: Sony Xperia 5 II (XQ-AS42)
- **Chipset**: Qualcomm Snapdragon 865
- **GPU**: Adreno 650
- **Environment**: Debian proot-distro in Termux

---

## What This Document Is About

This document explains why **Turnip GPU drivers don't work in Debian proot** and what alternatives exist. If you're trying to get GPU acceleration working in Debian proot on an Adreno device, this will help you understand the limitations and working solutions.

**Key Terms**:
- **Turnip**: Mesa's Vulkan driver for Qualcomm Adreno GPUs
- **Proot**: A tool that creates an isolated Linux environment without root access
- **Mesa**: Open-source graphics driver library
- **VIRGL/ZINK**: GPU virtualization technologies that work through a server-client model

---

## The Problem

**Turnip GPU drivers cannot work in Debian proot environment**, regardless of driver version (default Mesa or custom 24.1.0).

**Why?** Turnip needs direct access to `/dev/kgsl-3d0` (the Adreno GPU kernel device). Proot creates an isolated filesystem that cannot access this device, causing:
- Severe performance degradation (unusably slow)
- Black screens when custom Turnip is installed
- Apps unable to utilize GPU even when drivers report hardware acceleration

---

## What Works

### 1. Software Rendering (Most Reliable)
**What it is**: CPU-based rendering using LLVMPIPE (no GPU acceleration)

**How to use**:
- Set `LIBGL_ALWAYS_SOFTWARE=1` when launching Debian XFCE
- Or set `VK_ICD_FILENAMES=/dev/null` to disable Vulkan

**Performance**: Acceptable for basic desktop use (~30-60 in glmark2)

**Pros**: Always works, no configuration needed

**Cons**: No GPU acceleration, slower than hardware rendering

### 2. VIRGL/ZINK Server-Client (Not Extensively Tested)
**What it is**: Termux runs a GPU server with direct hardware access, proot connects as a client

**How it works**:
```
Termux (Host)          Proot (Client)
├─ GPU Server    ←──→  ├─ GALLIUM_DRIVER=virpipe
├─ Direct GPU access   └─ No device access needed
└─ virgl_test_server
```

**How to use**:
- Termux: Start GPU server (e.g., `virgl_test_server_android`)
- Proot: Set `GALLIUM_DRIVER=virpipe` or `GALLIUM_DRIVER=zink`

**Performance**: Better than software rendering (~120-180 in glmark2)

**Pros**: GPU acceleration without direct device access

**Cons**: More complex setup, not extensively tested in this research

---

## Test Results

### Default Mesa Behavior

**What happens**: When launching Debian XFCE with no environment variables, Mesa detects the Turnip driver and attempts to initialize by accessing `/dev/kgsl-3d0`. Device access fails in proot, causing severe performance degradation.

**Result**: Desktop launches but is unusably slow. No black screen on fresh install, but performance makes it impractical for actual use.

### Software Rendering Tests

**Test 1**: `LIBGL_ALWAYS_SOFTWARE=1`
- **Result**: ✓ Works perfectly
- **Why**: Forces CPU rendering, completely bypasses GPU drivers

**Test 2**: `VK_ICD_FILENAMES=/dev/null`
- **Result**: ✓ Works perfectly  
- **Why**: Disables Vulkan loader, forces LLVMPIPE software rendering

### Custom Turnip Driver Experiment

**Attempted workaround**:
1. Launch Debian proot with default Mesa (slow but no black screen)
2. Install custom Turnip driver inside running desktop
3. Run `MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform glmark2`

**Results**:
- ✓ glmark2 benchmark shows excellent score (~240)
- ✗ Browsers and apps show **no improvement**
- ✗ Relaunch causes **black screen**
- ✗ Must use software rendering to access desktop again

**Why it fails**: The benchmark runs in a terminal with specific environment variables, but when XFCE tries to initialize on relaunch, Turnip attempts to access `/dev/kgsl-3d0` and fails, causing a black screen.

**Custom Turnip Driver Info**:
- Version: mesa-vulkan-kgsl 24.1.0-devel-20240120
- Source: https://github.com/Jessiebrig/termux_dual_xfce/releases/tag/turnip-driver-v24.1.0
- Optimization: Adreno 6XX/7XX specific
- **Conclusion**: Not beneficial for proot environment

---

## Technical Analysis

### Why Turnip Fails in Proot

#### 1. Device Access Limitation
```
Turnip requires: /dev/kgsl-3d0 (Adreno kernel device)
Proot provides: Isolated filesystem namespace
Result: Device node not accessible or improperly mapped
```

#### 2. Debian XFCE Initialization Process
```
1. Debian XFCE starts in proot
2. Window manager/compositor initializes OpenGL
3. Mesa detects Turnip driver
4. Turnip attempts device initialization
5. Device access fails → hang/crash → black screen
```

**Note**: Native Termux XFCE (launched via `xrun xfce`) does not have this limitation and can utilize Turnip drivers directly.

#### 3. Why glmark2 Worked Once
The one-time success in Test 2.1 was likely due to:
- Specific timing/state of running XFCE session
- Possible GPU context already established
- Not reproducible after logout/relaunch

### Why VIRGL/ZINK Server Works

#### Architecture
```
┌─────────────────┐         ┌──────────────────┐
│  Termux (Host)  │         │  Proot (Client)  │
│                 │         │                  │
│  GPU Server     │◄────────┤  GALLIUM_DRIVER  │
│  (virgl/zink)   │  IPC    │  =virpipe/zink   │
│                 │         │                  │
│  Direct GPU     │         │  No GPU access   │
│  Access ✓       │         │  needed ✓        │
└─────────────────┘         └──────────────────┘
```

**Why it works**:
- Termux has direct GPU device access
- Proot only needs IPC to Termux server
- No device access required in proot

---

## Technical Recommendations

### For Debian Proot XFCE

**VIRGL/ZINK Server-Client Architecture**:
- Termux runs GPU server with direct hardware access
- Proot connects as client via IPC (no device access needed)
- Consider trying this approach for GPU acceleration in proot
- Parameters: `GALLIUM_DRIVER=virpipe` or `GALLIUM_DRIVER=zink` in proot, with corresponding server in Termux

**Software Rendering (Most Reliable)**:
- Forces CPU-based LLVMPIPE rendering
- Always works, acceptable performance for basic desktop use
- Parameters: `LIBGL_ALWAYS_SOFTWARE=1` or `VK_ICD_FILENAMES=/dev/null`

**Direct Turnip Usage**:
- Not functional in proot due to `/dev/kgsl-3d0` access limitation
- Shows hardware acceleration in command output but apps cannot utilize it
- `MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform` works once, fails on relaunch

### For Native Termux XFCE

If you want to utilize Adreno GPU with Turnip drivers, use **native Termux XFCE** (launched via `xrun xfce`) instead of Debian proot. Native Termux has direct device access and can fully utilize Turnip drivers.

### For Developers

**Future Research**:
- Investigate if newer proot-distro versions improve device mapping
- Test with different proot configurations
- Explore alternative GPU virtualization methods
- Consider chroot instead of proot (requires root)

---

## Conclusion

**Turnip in Proot**: Fundamentally incompatible due to device access limitations. Not a bug, but an architectural limitation of proot.

**Working Solutions**:
1. **VIRGL/ZINK Server-Client**: GPU acceleration via server-client architecture (not extensively tested)
2. **Software Rendering**: Most reliable, acceptable performance for basic desktop use

**Custom Turnip Driver**: Useful for Termux native XFCE, but offers no benefit for proot environment.

---

## Disclaimer

⚠️ **This information is provided for research and documentation purposes only.** Testing was limited to a single device (Sony Xperia 5 II with Adreno 650) and focused primarily on Turnip driver behavior. Results may vary on different devices, GPU architectures, or software versions. The findings and conclusions presented here may contain inaccuracies or become outdated as software evolves.

---

## File History
- **Created**: 2025-01-XX
- **Last Updated**: 2025-01-XX
- **Contributors**: Testing and research by Jessiebrig
- **Related Issue**: GPU acceleration in proot environment
