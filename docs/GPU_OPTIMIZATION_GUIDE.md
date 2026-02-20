# GPU Optimization Guide

A comprehensive guide to custom GPU configurations for Termux XFCE environments.

## Table of Contents
- [Understanding Custom Mode](#understanding-custom-mode)
- [Mesa Environment Variables](#mesa-environment-variables)
- [Native XFCE Configurations](#native-xfce-configurations)
- [Debian Proot Configurations](#debian-proot-configurations)
- [Performance Testing](#performance-testing)
- [Troubleshooting](#troubleshooting)

## Understanding Custom Mode

**Custom Mode** allows you to enter your own environment variables for advanced GPU configuration and experimentation.

### When to Use
- Testing different OpenGL versions
- Debugging rendering issues
- Maximizing performance for specific apps
- Comparing different driver configurations
- Troubleshooting compatibility problems

### How to Access
- **Native XFCE**: `xrun xfce` → Select **Custom** mode
- **Debian Proot**: `xrun debian_xfce` → Select **Custom** mode in the 2nd prompt

## Mesa Environment Variables

### MESA_GL_VERSION_OVERRIDE
Tells applications what OpenGL version you support (even if you don't)

**Values**: `3.3` | `4.0` | `4.3` | `4.6`

**When to use**: App refuses to run or crashes with version mismatch

**Example**:
MESA_GL_VERSION_OVERRIDE=4.0

### GALLIUM_HUD
Display real-time performance overlay on screen

**Values**: `fps` | `cpu` | `GPU-load` | `frametime` | `fps,cpu,GPU-load`

**When to use**: Verify GPU acceleration, compare performance, monitor resources

**Example**:
GALLIUM_HUD=fps
GALLIUM_HUD=fps,cpu,GPU-load

### mesa_glthread
Enable/disable multi-threaded OpenGL command processing

**Values**: `true` (faster, may cause issues) | `false` (stable, slower)

**When to use**: Enable for better FPS, disable if crashes occur

**Example**:
mesa_glthread=true

### MESA_NO_ERROR
Skip OpenGL error checking for better performance

**Values**: `1` (faster) | `0` (safer)

**When to use**: Enable for max performance, disable when debugging

**Example**:
MESA_NO_ERROR=1

### vblank_mode
Control vertical sync (vsync)

**Values**: `0` (max FPS, may tear) | `1` (smooth, capped FPS)

**When to use**: Disable for benchmarking, enable for smooth visuals

**Example**:
vblank_mode=0

### LIBGL_DRI3_DISABLE
Force DRI2 mode instead of DRI3

**Values**: `1` (use DRI2) | `0` (use DRI3)

**When to use**: Black screen, flickering, or Termux-X11 compatibility issues

**Example**:
LIBGL_DRI3_DISABLE=1

### GALLIUM_DRIVER
Select which Gallium driver to use

**Values**: `virpipe` | `zink` | `llvmpipe`

**When to use**: Match server type or force specific rendering path

**Example**:
GALLIUM_DRIVER=virpipe

### LIBGL_ALWAYS_SOFTWARE
Force software rendering, ignore all GPU drivers

**Values**: `1` (force software) | `0` (use GPU)

**When to use**: GPU causing crashes or for performance comparison

**Example**:
LIBGL_ALWAYS_SOFTWARE=1

### VK_ICD_FILENAMES
Control Vulkan driver detection

**Values**: `/dev/null` (disable Vulkan) | (empty for auto-detect)

**When to use**: Prevent Turnip/Vulkan interference

**Example**:
VK_ICD_FILENAMES=/dev/null

### MESA_LOADER_DRIVER_OVERRIDE
Override Mesa driver selection (for Turnip)

**Values**: `zink`

**When to use**: Enabling Turnip on Adreno GPUs

**Example**:
MESA_LOADER_DRIVER_OVERRIDE=zink

### TU_DEBUG
Turnip driver debug flags (Adreno only)

**Values**: `noconform` | `noconform,sysmem`

**When to use**: Always use `noconform` with Turnip, add `sysmem` for experimental boost

**Example**:
TU_DEBUG=noconform
TU_DEBUG=noconform,sysmem

### ZINK_DESCRIPTORS
Control ZINK descriptor management

**Values**: `lazy`

**When to use**: With ZINK driver for reduced overhead

**Example**:
ZINK_DESCRIPTORS=lazy

## Native XFCE Configurations

Use these in **Native Termux XFCE** Custom Mode.

### 1. Turnip Basic (Adreno 6XX/7XX)
Direct Vulkan access with minimal configuration

GALLIUM_DRIVER=zink MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform MESA_GL_VERSION_OVERRIDE=4.0

**When to use**: Safe baseline for Adreno GPUs

### 2. Turnip Optimized
Better performance with threading and optimizations

GALLIUM_DRIVER=zink MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform ZINK_DESCRIPTORS=lazy mesa_glthread=true MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.0

**When to use**: Balanced performance and stability

### 3. Turnip Aggressive (Maximum Performance)
Experimental maximum performance mode

GALLIUM_DRIVER=zink MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform,sysmem ZINK_DESCRIPTORS=lazy mesa_glthread=true MESA_NO_ERROR=1 vblank_mode=0 MESA_GL_VERSION_OVERRIDE=4.0

**When to use**: Gaming, benchmarks, maximum FPS (may cause tearing)

### 4. Turnip with FPS Overlay
Monitor performance while using Turnip

GALLIUM_DRIVER=zink MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform GALLIUM_HUD=fps MESA_GL_VERSION_OVERRIDE=4.0

**When to use**: Testing and comparing performance

### 5. Turnip with Full Monitoring
Detailed performance metrics

GALLIUM_DRIVER=zink MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform GALLIUM_HUD=fps,cpu,GPU-load MESA_GL_VERSION_OVERRIDE=4.0

**When to use**: Debugging performance issues

### 6. Compatibility Mode (Older Apps)
Maximum compatibility for older applications

GALLIUM_DRIVER=zink MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform LIBGL_DRI3_DISABLE=1 MESA_GL_VERSION_OVERRIDE=3.3

**When to use**: Black screen, crashes, or rendering glitches

### 7. VIRGL Native (Universal)
VIRGL rendering in native Termux (works on all GPUs)

GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0 GALLIUM_HUD=fps

**When to use**: Non-Adreno GPUs, testing VIRGL performance

### 8. Software Rendering Test
Pure CPU rendering for comparison

LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_HUD=fps

**When to use**: Comparing GPU vs CPU performance

## Debian Proot Configurations

Use these in **Debian Proot** Custom Mode.

### 1. VIRGL Basic
Connect to VIRGL server with basic settings

GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0

**When to use**: Safe default when VIRGL server is running

### 2. VIRGL Optimized
Enhanced VIRGL performance

GALLIUM_DRIVER=virpipe mesa_glthread=true MESA_NO_ERROR=1 vblank_mode=0 MESA_GL_VERSION_OVERRIDE=4.0

**When to use**: Better performance with VIRGL server

### 3. VIRGL with FPS Overlay
Monitor VIRGL performance

GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0 GALLIUM_HUD=fps

**When to use**: Testing VIRGL acceleration

### 4. VIRGL with Full Monitoring
Detailed VIRGL metrics

GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0 GALLIUM_HUD=fps,cpu,GPU-load mesa_glthread=true

**When to use**: Debugging VIRGL performance

### 5. ZINK Basic (Proot)
Connect to ZINK server

GALLIUM_DRIVER=zink MESA_GL_VERSION_OVERRIDE=4.0

**When to use**: When ZINK server is running

### 6. ZINK Optimized (Proot)
Enhanced ZINK performance

GALLIUM_DRIVER=zink mesa_glthread=true MESA_NO_ERROR=1 vblank_mode=0 MESA_GL_VERSION_OVERRIDE=4.0

**When to use**: Better performance with ZINK server

### 7. Test Different GL Versions
Find optimal OpenGL version for your app

GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=3.3 GALLIUM_HUD=fps
GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0 GALLIUM_HUD=fps
GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.6 GALLIUM_HUD=fps

**When to use**: App compatibility issues

### 8. Threading Comparison
Test threading impact

GALLIUM_DRIVER=virpipe mesa_glthread=true GALLIUM_HUD=fps
GALLIUM_DRIVER=virpipe mesa_glthread=false GALLIUM_HUD=fps

**When to use**: Stability vs performance testing

### 9. Compatibility Mode (Proot)
Maximum compatibility in proot

GALLIUM_DRIVER=virpipe LIBGL_DRI3_DISABLE=1 MESA_GL_VERSION_OVERRIDE=3.3

**When to use**: Rendering issues in proot

### 10. Native Turnip Test (No Server)
Test if Turnip works directly in proot

MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform GALLIUM_DRIVER=zink MESA_GL_VERSION_OVERRIDE=4.0

**When to use**: Adreno GPU, testing direct Vulkan access in proot

### 11. Force Software Rendering
Pure CPU rendering in proot

LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_HUD=fps

**When to use**: GPU causing crashes, performance comparison

### 12. Disable Vulkan + Software
Block Vulkan detection, force software

VK_ICD_FILENAMES=/dev/null LIBGL_ALWAYS_SOFTWARE=1

**When to use**: Turnip interfering with software rendering

## Performance Testing

### Benchmark Template
Use this template to compare configurations:

GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0 GALLIUM_HUD=fps,frametime
GALLIUM_DRIVER=virpipe mesa_glthread=true MESA_NO_ERROR=1 GALLIUM_HUD=fps,frametime

### What to Monitor
- **FPS**: Higher is better (frames per second)
- **CPU**: Lower is better (CPU usage %)
- **GPU-load**: Higher means GPU is being utilized
- **frametime**: Lower and consistent is better

### Testing Methodology
1. Run the same app/benchmark with each configuration
2. Note FPS and stability
3. Check for visual artifacts or crashes
4. Choose the best balance of performance and stability

## Troubleshooting

### Black Screen or No Display
LIBGL_DRI3_DISABLE=1 MESA_GL_VERSION_OVERRIDE=3.3

### App Crashes on Startup
mesa_glthread=false MESA_GL_VERSION_OVERRIDE=3.3

### Rendering Artifacts or Glitches
MESA_NO_ERROR=0 mesa_glthread=false

### Low FPS Despite GPU Acceleration
mesa_glthread=true MESA_NO_ERROR=1 vblank_mode=0

### App Says "OpenGL Version Too Old"
MESA_GL_VERSION_OVERRIDE=4.6

### Screen Tearing
vblank_mode=1

### Verify GPU is Working
GALLIUM_HUD=fps,GPU-load

If GPU-load shows 0%, GPU acceleration is not working.

## Quick Reference

### Native XFCE (Adreno)
GALLIUM_DRIVER=zink MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform MESA_GL_VERSION_OVERRIDE=4.0
GALLIUM_DRIVER=zink MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform,sysmem mesa_glthread=true MESA_NO_ERROR=1 vblank_mode=0 MESA_GL_VERSION_OVERRIDE=4.0

### Debian Proot (VIRGL)
GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0
GALLIUM_DRIVER=virpipe mesa_glthread=true MESA_NO_ERROR=1 vblank_mode=0 MESA_GL_VERSION_OVERRIDE=4.0

### Debug/Monitor
GALLIUM_HUD=fps
GALLIUM_HUD=fps,cpu,GPU-load,frametime

## Notes

- **Experiment safely**: Misconfigurations won't break your system, just restart
- **Match server types**: VIRGL server → `GALLIUM_DRIVER=virpipe`, ZINK server → `GALLIUM_DRIVER=zink`
- **Start simple**: Begin with basic configs, add optimizations gradually
- **Monitor performance**: Always use `GALLIUM_HUD=fps` when testing
- **Document results**: Keep notes on what works best for your device

## Contributing

Found a configuration that works great on your device? Share it with the community!

- Device model
- GPU type
- Configuration used
- Performance results

Happy optimizing! 🚀
