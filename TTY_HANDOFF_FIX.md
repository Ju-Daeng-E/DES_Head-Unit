# TTY Handoff Fix - Complete Solution

## 🔴 Root Cause Analysis

### Symptom You Experienced:
1. ✅ Plymouth animation plays for 7 seconds
2. 🔴 **TTY1 terminal appears** after Plymouth quits (login prompt)
3. 🔴 Ctrl+Alt+F7 shows **black screen** (Qt apps running but not visible)

### Why This Happened:

**Kernel Console Configuration:**
```bash
# OLD (BROKEN):
console=serial0,115200 console=tty1

# After Plymouth quits, kernel automatically switches to tty1
# But Weston is trying to run on tty7!
```

**Plymouth Configuration:**
```ini
# OLD (BROKEN):
[Daemon]
Theme=des
UseKMS=true
# Missing: No VT configuration
# Result: Plymouth doesn't tell Weston which VT to use
```

**Flow Diagram (BEFORE FIX):**
```
[0-7s] Plymouth runs on tty7 (you see Ferrari animation)
  ↓
[7s]   Plymouth quits
  ↓
[7.1s] Kernel sees console=tty1 → Switches to tty1 ❌
  ↓
[7.2s] Weston starts on tty7 (but you can't see it)
  ↓
[8s]   Apps render to tty7 (invisible)
  ↓
YOU SEE: TTY1 terminal login prompt
CTRL+ALT+F7: Black screen (Weston is there but no apps visible)
```

---

## ✅ Applied Fixes

### Fix #1: Remove console=tty1 from Kernel Command Line

**File:** `meta-env/recipes-bsp/bootfiles/rpi-cmdline.bbappend`

**Change:**
```diff
-CMDLINE_SERIAL = "console=serial0,115200 console=tty1"
+CMDLINE_SERIAL = "console=serial0,115200"
```

**Effect:** Kernel won't auto-switch to tty1 after Plymouth quits

---

### Fix #2: Add VT=7 to Plymouth Configuration

**File:** `meta-env/recipes-core/plymouth/plymouth/plymouthd.defaults`

**Change:**
```diff
 [Daemon]
 Theme=des
 ShowDelay=0
 DeviceTimeout=30
 UseKMS=true
 EarlyInit=false
+# Keep VT allocation on tty7 for smooth handoff to Weston
+VT=7
```

**Effect:** Plymouth stays on tty7 and hands off cleanly to Weston

---

### Fix #3: Use --retain-splash in Plymouth Quit

**File:** `meta-env/recipes-core/plymouth/plymouth/plymouth-quit-timer.service`

**Change:**
```diff
-ExecStart=/bin/sh -c 'sleep 7 && /usr/bin/plymouth quit --wait'
+ExecStart=/bin/sh -c 'sleep 7 && /usr/bin/plymouth quit --retain-splash'
```

**Effect:**
- `--wait` was for DRM release (good for parallel boot)
- `--retain-splash` keeps VT allocated so Weston can take over seamlessly
- DRM is still released (Weston can acquire it)

---

## 🚀 Rebuild and Deploy

### Step 1: Clean Affected Recipes

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des

# Clean recipes that changed
bitbake -c cleansstate plymouth
bitbake -c cleansstate rpi-cmdline
bitbake -c cleansstate weston-init
bitbake -c cleansstate headunit
bitbake -c cleansstate instrument-cluster
```

---

### Step 2: Rebuild Image

```bash
bitbake des-image
```

**Build time:** 20-30 minutes

**Output location:**
```
build-des/tmp-glibc/deploy/images/raspberrypi4-64/des-image-raspberrypi4-64.wic.bz2
```

---

### Step 3: Deploy to SD Card

```bash
# Find SD card
lsblk

# Unmount
sudo umount /dev/sdb*

# Deploy (REPLACE /dev/sdb with YOUR device!)
sudo bzcat build-des/tmp-glibc/deploy/images/raspberrypi4-64/des-image-raspberrypi4-64.wic.bz2 | sudo dd of=/dev/sdb bs=4M status=progress

# Sync
sync
```

---

### Step 4: Expected Behavior After Fix

```
[0s]     Boot starts
[1s]     Plymouth Ferrari animation on tty7
[7s]     Plymouth quits, keeps tty7 allocated
[7.5s]   Weston takes over tty7 seamlessly
[8s]     Head-Unit appears on HDMI-A-1
[8s]     Instrument Cluster appears on HDMI-A-2
```

**You should see:**
- ✅ Plymouth animation (7 seconds)
- ✅ Smooth transition (no tty1 login!)
- ✅ Both Qt apps appear immediately
- ✅ No need to press Ctrl+Alt+F7

---

## 🔍 Verification Steps

### After Booting:

SSH into Raspberry Pi:

```bash
# Check which VT Weston is using
ps aux | grep weston
# Should show: weston with tty7

# Check if Weston is running
systemctl status weston.service
# Should show: active (running)

# Check apps
systemctl status headunit.service
systemctl status instrument-cluster.service
# Both should show: active (running)

# Check current VT
fgconsole
# Should show: 7

# Check Wayland socket
ls -la /run/wayland-0
# Should exist with root:root ownership
```

---

## ⚠️ Troubleshooting

### If TTY1 Still Appears:

```bash
# SSH in and check cmdline
cat /proc/cmdline | grep console

# Should NOT show console=tty1
# Should show: console=serial0,115200 splash quiet ...
```

**If console=tty1 is still there:**
→ Rebuild didn't apply cmdline changes
→ Run: `bitbake -c cleansstate rpi-cmdline && bitbake des-image`

---

### If Ctrl+Alt+F7 Shows Black Screen:

```bash
# Check if Weston is actually running
systemctl status weston.service

# Check Weston logs
journalctl -u weston.service -b | tail -50

# Look for errors like:
# - "failed to open /dev/tty7"
# - "VT already in use"
# - "DRM master"
```

---

### If Apps Don't Appear But Weston Works:

```bash
# Check app logs
journalctl -u headunit.service -b | tail -30
journalctl -u instrument-cluster.service -b | tail -30

# Common issues:
# - "Could not connect to wayland-0"
# - "QML loading error"
# - "Failed to create window"
```

---

## 📊 Technical Summary

### What Changed:

| Component | Before | After | Reason |
|-----------|--------|-------|--------|
| **Kernel cmdline** | `console=tty1` | Removed | Prevent auto-switch to tty1 |
| **Plymouth VT** | Not set | `VT=7` | Stay on tty7 |
| **Plymouth quit** | `--wait` | `--retain-splash` | Keep VT allocated for Weston |
| **Weston TTY** | `TTYPath=/dev/tty7` | Unchanged | Already correct |

### Boot Flow (AFTER FIX):

```
[Kernel] → [Plymouth tty7] → [Plymouth quits but keeps tty7]
                           → [Weston takes tty7] → [Apps render to tty7]
                                                 → [User sees apps!]
```

### Key Insights:

1. **DRM was not the issue** - Weston was starting fine
2. **TTY switching was the issue** - You were looking at tty1, apps were on tty7
3. **Plymouth VT handoff was broken** - No coordination between Plymouth and Weston

---

## 🎯 Success Criteria

Your system is **FIXED** when:

### Visual:
- ✅ Plymouth animation plays smoothly
- ✅ **No TTY1 login screen appears**
- ✅ Apps appear immediately after Plymouth
- ✅ No need to switch TTYs manually

### Technical:
- ✅ `/proc/cmdline` has NO `console=tty1`
- ✅ `fgconsole` returns `7`
- ✅ Weston runs on tty7
- ✅ Both apps active and visible

---

## 📞 Additional Help

If problems persist after rebuild:

### Check VT Allocation:

```bash
# See which processes are using which VTs
fuser /dev/tty1
fuser /dev/tty7

# Check VT mode
cat /sys/class/tty/tty7/active
```

### Force VT Switch Manually:

```bash
# If apps are on tty7 but you see tty1, switch manually
chvt 7

# Should immediately show Qt apps
```

### Emergency: Disable Plymouth Entirely

If Plymouth causes too many issues:

```bash
# In rpi-cmdline.bbappend, remove "splash"
CMDLINE:append = " quiet loglevel=3 vt.global_cursor_default=0"

# Rebuild
bitbake -c cleansstate rpi-cmdline
bitbake des-image
```

This removes boot animation but guarantees Weston starts correctly.

---

## 🚀 Next Steps

1. **Rebuild image** with fixes applied
2. **Deploy to SD card**
3. **Boot Raspberry Pi**
4. **Verify** apps appear without TTY switching

**Expected result:** Smooth boot from Plymouth to apps in 7-8 seconds! ✨

---

**Fix confidence:** ⭐⭐⭐⭐⭐ **VERY HIGH**

This addresses the exact root cause: TTY switching after Plymouth quits.
