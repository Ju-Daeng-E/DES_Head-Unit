# DES Cockpit Wayland Testing Guide

**Date**: 2025-11-13
**Image**: `des-image-raspberrypi4-64.rootfs-20251113101427.rpi-sdimg`

---

## What Was Fixed

### Problem Summary
The previous build resulted in a black screen on both monitors with no TTY access. This was caused by:

1. ❌ Missing `weston.socket` - Wayland socket `/run/wayland-0` was not being created
2. ❌ Missing TTY configuration - No keyboard/console access (CTRL+ALT+F1-F8 didn't work)
3. ❌ Missing `systemd-notify.so` module - Required for `Type=notify` service
4. ❌ Hardcoded environment variables - Difficult to manage and debug

### Applied Fixes

#### 1. Complete weston.service Rewrite
**File**: `meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service`

**Key additions**:
- `Requires=weston.socket` - Ensures Wayland socket is created first
- `TTYPath=/dev/tty7` - Allocates virtual terminal for keyboard access
- `Type=notify` - Proper systemd integration with status notifications
- `EnvironmentFile=/etc/default/weston` - Externalized configuration
- Full TTY management (TTYReset, TTYVHangup, TTYVTDisallocate)

#### 2. New weston.socket
**File**: `meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.socket`

Creates `/run/wayland-0` socket before Weston starts, with mode 0777 for root access.

#### 3. New Environment File
**File**: `meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston-default`

Centralized environment configuration:
```bash
XDG_RUNTIME_DIR=/run
WAYLAND_DISPLAY=wayland-0
```

---

## SD Card Flashing

### Requirements
- SD card (minimum 8GB recommended)
- SD card reader
- Built image: `des-image-raspberrypi4-64.rootfs-20251113101427.rpi-sdimg`

### Flashing Commands

**Linux/macOS**:
```bash
# Identify SD card device
lsblk  # or diskutil list on macOS

# Flash image (CAUTION: Double-check device name!)
sudo dd if=build-des/tmp-glibc/deploy/images/raspberrypi4-64/des-image-raspberrypi4-64.rootfs.rpi-sdimg \
    of=/dev/sdX \
    bs=4M \
    status=progress \
    conv=fsync

# Where /dev/sdX is your SD card (e.g., /dev/sdb or /dev/mmcblk0)
# On macOS: /dev/diskX (e.g., /dev/disk2)

# Sync and eject
sync
sudo eject /dev/sdX
```

**Windows**:
Use [balenaEtcher](https://www.balena.io/etcher/) or [Raspberry Pi Imager](https://www.raspberrypi.com/software/)

---

## Testing Procedure

### 1. Boot Test

**Insert SD card and power on Raspberry Pi 4**

Expected behavior:
- Boot splash screen appears
- System boots to graphical.target
- Both HDMI displays should show content

### 2. TTY Access Test

**Press CTRL+ALT+F1**

Expected: Console login prompt appears

**Login**:
```
Username: root
Password: (no password if not set, or configured password)
```

**Verify systemd services**:
```bash
# Check Weston status
systemctl status weston.service

# Expected: active (running)
# Should show: "Running on wayland-0"
```

**Return to GUI**: Press `CTRL+ALT+F7`

### 3. Weston Service Verification

```bash
# Check if Weston is running
systemctl status weston.service

# Expected output:
# ● weston.service - Weston Wayland Compositor (Root Mode)
#    Loaded: loaded (/usr/lib/systemd/system/weston.service; enabled)
#    Active: active (running) since ...
#    Main PID: <pid>
#    Status: "Running on wayland-0"

# Check Wayland socket
ls -la /run/wayland-0

# Expected: srwxrwxrwx 1 root root 0 ... /run/wayland-0

# Check Weston process
ps aux | grep weston

# Expected: root ... /usr/bin/weston --backend=drm-backend.so ...
```

### 4. HeadUnit Service Verification

```bash
systemctl status headunit.service

# Expected output:
# ● headunit.service - Head Unit (Qt Quick) - Wayland Client
#    Active: active (running) since ...
#    Main PID: <pid>

# Check if HeadUnit is connected to Wayland
ps aux | grep HeadUnitApp

# Expected: root ... /usr/bin/HeadUnitApp
```

### 5. Instrument Cluster Service Verification

```bash
systemctl status instrument-cluster.service

# Expected output:
# ● instrument-cluster.service - Instrument Cluster Application - Wayland Client
#    Active: active (running) since ...
#    Main PID: <pid>

# Check if IC is connected to Wayland
ps aux | grep appIC

# Expected: root ... /usr/bin/appIC
```

### 6. D-Bus Communication Test

```bash
# List D-Bus services
busctl --system list | grep com.des.vehicle

# Expected: com.des.vehicle ... root

# Check Gear service interface
busctl --system introspect com.des.vehicle /com/des/vehicle/Gear

# Expected: Shows interface methods and signals

# Monitor gear changes
busctl --system monitor com.des.vehicle.Gear

# Change gear in Instrument Cluster UI and verify signal appears in monitor
```

### 7. Display Output Verification

**HDMI-A-1 (First HDMI port)**:
- Should display: **HeadUnit** application
- Check: Home screen with weather, music controls

**HDMI-A-2 (Second HDMI port)**:
- Should display: **Instrument Cluster** application
- Check: Speedometer, gear indicator, battery gauge

**Test interaction**:
1. Change gear in Instrument Cluster (using PiRacer controller or UI buttons)
2. Verify HeadUnit's gear display updates in real-time via D-Bus

### 8. Logging and Debugging

**Collect all logs**:
```bash
# Save to files
journalctl -xb > /home/root/boot-full.log
journalctl -u weston.service > /home/root/weston.log
journalctl -u headunit.service > /home/root/headunit.log
journalctl -u instrument-cluster.service > /home/root/ic.log

# Check for errors
journalctl -p err -xb

# Real-time monitoring
journalctl -f
```

**DRM/Graphics logs**:
```bash
dmesg | grep -i drm
dmesg | grep -i vc4
dmesg | grep -i hdmi
```

---

## Expected Results Summary

| Test | Expected Result | Pass/Fail |
|------|----------------|-----------|
| Boot to GUI | Both monitors show content | ⬜ |
| TTY access (CTRL+ALT+F1) | Console login prompt | ⬜ |
| Weston running | `systemctl status weston` → active | ⬜ |
| Wayland socket | `/run/wayland-0` exists | ⬜ |
| HeadUnit running | `systemctl status headunit` → active | ⬜ |
| IC running | `systemctl status instrument-cluster` → active | ⬜ |
| HDMI-A-1 output | HeadUnit UI visible | ⬜ |
| HDMI-A-2 output | Instrument Cluster UI visible | ⬜ |
| D-Bus communication | Gear changes sync between apps | ⬜ |
| Font rendering | Text readable (no boxes/artifacts) | ⬜ |

---

## Troubleshooting

### If Black Screen Persists

1. **Check serial console** (if available):
   - UART GPIO pins 14/15 on Raspberry Pi
   - 115200 baud rate
   - Check boot messages

2. **Access via SSH** (if network is configured):
   ```bash
   ssh root@<raspberry-pi-ip>
   ```

3. **Check systemd failed services**:
   ```bash
   systemctl --failed
   systemctl list-units --state=failed
   ```

### If Weston Fails to Start

```bash
# Check Weston logs
journalctl -u weston.service -n 100

# Common issues:
# - "DRM device busy" → Another process owns /dev/dri/card0
# - "Failed to open tty" → TTY permission issue
# - "Socket bind failed" → weston.socket not created

# Manual Weston test
systemctl stop weston.service
weston --backend=drm-backend.so --config=/etc/xdg/weston/weston.ini
```

### If Apps Don't Appear

```bash
# Check if apps are trying to start
journalctl -u headunit.service -n 50
journalctl -u instrument-cluster.service -n 50

# Common issues:
# - "Wayland connection failed" → Check XDG_RUNTIME_DIR and WAYLAND_DISPLAY
# - "Qt platform plugin not found" → Check qtwayland plugin installation
# - "App-id mismatch" → Verify weston.ini app-ids match executable names
```

---

## Rollback Procedure

If the new image doesn't work and you need to revert:

1. Keep the old SD card image as backup
2. Alternatively, rebuild previous configuration:
   ```bash
   cd yocto-workspace
   git checkout <previous-commit>
   . poky/oe-init-build-env build-des
   bitbake des-image
   ```

---

## Success Criteria

✅ **Minimum Success**:
- Both monitors show GUI (even if not assigned correctly)
- TTY access works (CTRL+ALT+F1)
- All systemd services are active (running)
- No kernel panics or crashes

✅ **Full Success**:
- HDMI-A-1 shows HeadUnit, HDMI-A-2 shows Instrument Cluster
- Gear changes in IC update HeadUnit display via D-Bus
- Font rendering is correct
- System stable for >5 minutes of operation

---

## Next Steps After Testing

**If tests pass**:
1. Test PiRacer hardware integration (CAN bus, motors)
2. Test music playback functionality
3. Verify weather service API calls
4. Long-term stability testing (24+ hours)

**If tests fail**:
1. Collect all logs as described in section 8
2. Review logs for error patterns
3. Check hardware connections (HDMI cables, power supply)
4. Consider serial console debugging for deeper analysis

---

**Good luck with testing!** 🚀

If you encounter issues, refer to `WAYLAND_MIGRATION_PROGRESS.md` for detailed configuration history.
