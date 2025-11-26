# Dual Display Solution for DES Cockpit

## Problem Summary

**Issue**: Weston kiosk-shell displays both Qt applications (HeadUnit and Instrument Cluster) on the same HDMI output, preventing proper dual-display operation.

**Root Cause**: Weston's kiosk-shell is designed for single-output kiosk scenarios and does not support assigning different fullscreen clients to different outputs without custom configuration that is not available in the current Yocto build.

## Solution

Switch from **Wayland/Weston** to **Qt eglfs** (direct DRM/KMS rendering), allowing each Qt application to independently claim a specific HDMI output.

## Architecture Changes

### Before (Wayland)
```
[Weston Compositor] → [Both Apps on HDMI-A-1]
                     → [HDMI-A-2 unused]
```

### After (Direct DRM)
```
[HeadUnit App] → Direct DRM → HDMI-A-1
[Cluster App]  → Direct DRM → HDMI-A-2
```

## Implementation Details

### 1. Qt eglfs Plugins Added
- `qtbase-plugins-platforms-eglfs`
- `qtbase-plugins-platforms-eglfs-kms`

### 2. KMS Configuration Files

**HeadUnit** (`/etc/headunit-kms.json`):
```json
{
  "device": "/dev/dri/card0",
  "outputs": [
    {
      "name": "HDMI-A-1",
      "format": "argb8888"
    }
  ]
}
```

**Instrument Cluster** (`/etc/cluster-kms.json`):
```json
{
  "device": "/dev/dri/card0",
  "outputs": [
    {
      "name": "HDMI-A-2",
      "format": "argb8888"
    }
  ]
}
```

### 3. Service Configuration

Both services now use:
- `QT_QPA_PLATFORM=eglfs` (instead of `wayland`)
- `QT_QPA_EGLFS_KMS_CONFIG=/etc/<app>-kms.json`
- Run as `root` (required for DRM access)

### 4. Power Optimization

Applied to prevent USB over-current issues:
- **GPU Memory**: 256MB → 128MB
- **HDMI Boost**: 7 → 2 (both outputs)

## Build Instructions

### Quick Build
```bash
cd yocto-workspace
./build-des-dual-display.sh
```

### Manual Build
```bash
cd yocto-workspace
. poky/oe-init-build-env build-des

# Clean previous builds
bitbake -c cleansstate headunit instrument-cluster weston-init rpi-config

# Build image
bitbake des-image
```

### Flash to SD Card
```bash
cd build-des/tmp-glibc/deploy/images/raspberrypi4-64/
sudo dd if=des-image-raspberrypi4-64.wic of=/dev/sdX bs=4M status=progress
sync
```

## Expected Behavior After Flashing

1. **Boot Sequence**:
   - Raspberry Pi boots
   - HeadUnit starts → renders to HDMI-A-1 (first monitor)
   - Instrument Cluster starts (3s delay) → renders to HDMI-A-2 (second monitor)

2. **Display Assignment**:
   - HDMI-A-1: HeadUnit interface
   - HDMI-A-2: Instrument Cluster gauges

3. **No Flickering**: Power-optimized settings prevent USB over-current

## Troubleshooting

### Both apps still on same display
```bash
# Check if eglfs plugin loaded
journalctl -u headunit.service | grep eglfs

# Verify KMS config exists
ls -la /etc/headunit-kms.json /etc/cluster-kms.json

# Check DRM device
ls -la /dev/dri/card0
```

### Black screen on one display
```bash
# Check service status
systemctl status headunit.service instrument-cluster.service

# Check for DRM errors
dmesg | grep drm

# Verify HDMI connection
cat /sys/class/drm/card0-HDMI-A-1/status
cat /sys/class/drm/card0-HDMI-A-2/status
```

### USB devices disconnecting
- Increase HDMI boost: `config_hdmi_boost:0=3` (max safe: 4)
- Use external powered USB hub
- Check power supply rating (minimum 5V 3A recommended)

## Files Modified

### Yocto Recipes
- `meta-custom/meta-env/recipes-core/images/des-image.bb`
- `meta-custom/meta-app/recipes-des/headunit/headunit.bb`
- `meta-custom/meta-app/recipes-des/instrument-cluster/instrument-cluster.bb`
- `meta-custom/meta-env/recipes-bsp/bootfiles/rpi-config_%.bbappend`

### Service Files
- `meta-custom/meta-app/recipes-des/headunit/files/headunit.service`
- `meta-custom/meta-app/recipes-des/instrument-cluster/files/instrument-cluster.service`

### New Files
- `meta-custom/meta-app/recipes-des/headunit/files/kms-config/headunit-kms.json`
- `meta-custom/meta-app/recipes-des/instrument-cluster/files/kms-config/cluster-kms.json`

## Alternative Solutions (Not Implemented)

### 1. Cage Compositor
- Lightweight Wayland compositor with better multi-output support
- Requires: `cage` package in Yocto

### 2. Sway Compositor
- Tiling Wayland compositor
- Requires: `sway` and dependencies

### 3. Custom Weston Build
- Modify Weston kiosk-shell source to support per-client output assignment
- Complex, requires upstream patching

## Why eglfs Was Chosen

1. **Native Qt Support**: Built-in Qt platform plugin
2. **Direct Hardware Access**: No compositor overhead
3. **Simple Configuration**: JSON-based output selection
4. **Proven Solution**: Widely used in embedded Qt applications
5. **Performance**: Lower latency than Wayland

## References

- Qt EGLFS Documentation: https://doc.qt.io/qt-6/embedded-linux.html
- Raspberry Pi DRM/KMS: https://www.raspberrypi.com/documentation/computers/configuration.html
- Weston Kiosk Shell Limitations: https://gitlab.freedesktop.org/wayland/weston/-/issues/

## Support

For issues or questions, check:
1. Service logs: `journalctl -u headunit.service -u instrument-cluster.service`
2. Kernel messages: `dmesg | grep -i 'drm\|hdmi'`
3. Display status: `/sys/class/drm/card0-HDMI-A-*/status`
