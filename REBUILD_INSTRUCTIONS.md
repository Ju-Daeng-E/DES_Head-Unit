# Emergency Rebuild Instructions

## Current Situation

### ✅ Fixes Applied (in source code):
1. **weston.service** - Now waits for Plymouth to quit (`After=plymouth-quit-timer.service`)
2. **plymouth-quit-timer.service** - Now fully releases DRM (`--wait` instead of `--retain-splash`)

### ❌ Problem:
**Image NOT rebuilt** - SD card still has old broken configuration

### 🎯 Symptoms You're Seeing:
1. ⚠️ "failed to wifi auto login service" (cosmetic, non-blocking)
2. 🔴 Head-Unit and IC not appearing (DRM conflict, BLOCKING)

---

## 🚀 STEP-BY-STEP REBUILD PROCESS

### Step 1: Clean Build Environment

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace

# Initialize Yocto build environment
. poky/oe-init-build-env build-des

# Clean ONLY the affected recipes (faster than full clean)
bitbake -c cleansstate plymouth
bitbake -c cleansstate weston-init
bitbake -c cleansstate headunit
bitbake -c cleansstate instrument-cluster
```

**Expected output:**
```
NOTE: Executing Tasks
NOTE: Tasks Summary: Attempted X tasks of which X didn't need to be rerun and all succeeded.
```

---

### Step 2: Rebuild Image

```bash
# Still in build-des directory
bitbake des-image
```

**Build time:** 15-30 minutes (only rebuilding changed recipes)

**Expected output:**
```
NOTE: Tasks Summary: Attempted XXXX tasks of which XXXX didn't need to be rerun and all succeeded.
```

**Build artifact location:**
```
build-des/tmp-glibc/deploy/images/raspberrypi4-64/des-image-raspberrypi4-64.wic.bz2
```

---

### Step 3: Deploy to SD Card

```bash
# Exit build environment first
cd /home/seame/DES_Head-Unit

# Find SD card device
lsblk

# Expected output:
# sdb      8:16   1  14.9G  0 disk
# ├─sdb1   8:17   1    40M  0 part /media/seame/boot
# └─sdb2   8:18   1   1.5G  0 part /media/seame/root

# Unmount all partitions
sudo umount /dev/sdb*

# Deploy image (REPLACE /dev/sdb with YOUR SD card device!)
# ⚠️ WARNING: This will ERASE all data on the device!
sudo bzcat yocto-workspace/build-des/tmp-glibc/deploy/images/raspberrypi4-64/des-image-raspberrypi4-64.wic.bz2 | sudo dd of=/dev/sdb bs=4M status=progress

# Sync to ensure all data is written
sync
```

**Deployment time:** 5-10 minutes

---

### Step 4: Boot and Verify

1. Insert SD card into Raspberry Pi
2. Power on
3. **Expected behavior:**
   - [0-7s] Plymouth Ferrari animation plays
   - [7s] Plymouth quits smoothly
   - [~8s] Head-Unit appears on HDMI-A-1 (left)
   - [~8s] Instrument Cluster appears on HDMI-A-2 (right)

4. **You might still see:**
   - ⚠️ "failed to wifi auto login service" (harmless warning)
   - This does NOT affect boot process

---

## 🔧 POST-BOOT VERIFICATION

SSH into Raspberry Pi and verify services:

```bash
# Check all service statuses
systemctl status plymouth-quit-timer.service --no-pager
systemctl status weston.service --no-pager
systemctl status headunit.service --no-pager
systemctl status instrument-cluster.service --no-pager

# Expected: All "active" or "exited" except wifi-auto-enable (may be "failed")

# Check Wayland socket exists
ls -la /run/wayland-0
# Expected: srwxrwxrwx 1 root root 0 ... /run/wayland-0

# Boot timeline
systemd-analyze critical-chain graphical.target

# Expected: Should show Plymouth → Weston → Apps in sequence
```

---

## ⚠️ TROUBLESHOOTING

### If Apps Still Don't Appear:

```bash
# Check Weston logs
journalctl -u weston.service -b --no-pager | tail -50

# Look for errors like:
# - "failed to create display"
# - "DRM master"
# - "cannot open /dev/dri/card0"

# Check app logs
journalctl -u headunit.service -b --no-pager | tail -30
journalctl -u instrument-cluster.service -b --no-pager | tail -30

# Look for errors like:
# - "Could not connect to Wayland"
# - "wayland-0: No such file"
```

### Emergency: Verify Fix is Actually Deployed

```bash
# Check if weston.service has the fix
grep "plymouth-quit-timer" /lib/systemd/system/weston.service

# Expected output:
# After=plymouth-quit-timer.service

# Check if plymouth-quit-timer has the fix
grep "quit --wait" /lib/systemd/system/plymouth-quit-timer.service

# Expected output:
# ExecStart=/bin/sh -c 'sleep 7 && /usr/bin/plymouth quit --wait'
```

**If these commands return nothing**, the fixes are NOT in the deployed image → rebuild failed or wrong image deployed.

---

## 🛠️ OPTIONAL: Fix WiFi Auto-Enable Service

**This is NOT blocking boot**, but if you want to silence the error:

### Option A: Disable WiFi Auto-Enable (Quick)

Add to `yocto-workspace/meta-custom/meta-env/recipes-core/images/des-image.bb`:

```python
SYSTEMD_AUTO_ENABLE_pn-wifi-auto-enable = "disable"
```

Then rebuild:
```bash
bitbake -c cleansstate des-image
bitbake des-image
```

### Option B: Fix WiFi Service (Proper)

Edit `yocto-workspace/meta-custom/meta-env/recipes-connectivity/wifi-auto-enable/files/wifi-auto-enable.service`:

```ini
[Unit]
Description=WiFi Auto-Enable Service
After=network.target
DefaultDependencies=no

[Service]
Type=oneshot
# Add timeout to prevent hanging
TimeoutStartSec=10
# Make failure non-critical
ExecStart=-/usr/sbin/rfkill unblock wifi
ExecStart=-/usr/sbin/rfkill unblock wlan
# Check if wlan0 exists before trying to bring it up
ExecStart=/bin/sh -c 'if [ -e /sys/class/net/wlan0 ]; then /usr/bin/ip link set wlan0 up; fi'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

**Changes:**
- `-` prefix on ExecStart → failure doesn't stop service
- Check if `wlan0` exists before bringing it up
- `TimeoutStartSec=10` → prevent hanging
- `WantedBy=multi-user.target` instead of `sysinit.target` → less critical

Then rebuild:
```bash
bitbake -c cleansstate wifi-auto-enable
bitbake des-image
```

---

## 📊 SUCCESS CRITERIA

Your system is **FIXED** when:

### Must Have (Critical):
- ✅ Plymouth animation plays for 7 seconds
- ✅ Head-Unit appears on left screen (HDMI-A-1)
- ✅ Instrument Cluster appears on right screen (HDMI-A-2)
- ✅ No black screen hang after Plymouth
- ✅ `systemctl status weston.service` → **active (running)**
- ✅ `/run/wayland-0` socket exists

### Nice to Have (Non-Critical):
- ⚠️ WiFi service may still fail (doesn't affect functionality)
- ⚠️ Boot time: 7-9 seconds total

---

## 🆘 EMERGENCY ROLLBACK

If rebuild makes things WORSE:

```bash
cd /home/seame/DES_Head-Unit

# Revert all changes
git checkout yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service
git checkout yocto-workspace/meta-custom/meta-env/recipes-core/plymouth/plymouth/plymouth-quit-timer.service

# Rebuild with original (slower but stable) configuration
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake -c cleansstate plymouth weston-init
bitbake des-image
```

This will restore the sequential boot (slower, but guaranteed to work).

---

## 📞 NEXT STEPS

1. **Now**: Rebuild image using steps above
2. **Deploy**: Flash to SD card
3. **Test**: Boot Raspberry Pi
4. **Verify**: Check services and logs
5. **Optional**: Fix WiFi service warning

**Estimated total time**: 30-45 minutes (mostly automated)

---

**Good luck!** 🚀
