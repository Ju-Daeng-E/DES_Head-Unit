# SystemD Service Conflict - Solution Plan

## Root Cause
**DRM/KMS Resource Conflict**: Plymouth and Weston both need exclusive DRM access. Weston tries to start while Plymouth is still holding DRM, causing Weston startup failure → no `/run/wayland-0` socket → apps cannot start → black screen.

---

## Solution Options

### ✅ SOLUTION A: Quick Fix - Add Weston Dependency on Plymouth (RECOMMENDED)
**Complexity**: Low
**Risk**: Low
**Boot Time Impact**: Minimal (same 7 seconds, but reliable)
**Status**: Ready to implement

#### Changes Required:
1. **Fix weston.service** - Add dependency on Plymouth quit timer
2. **Fix plymouth-quit-timer.service** - Remove `--retain-splash` flag

#### Implementation:

**File 1:** `yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service`

```diff
 [Unit]
 Description=Weston Wayland Compositor
 Documentation=man:weston(1) man:weston.ini(5)

 # Dependencies
 Requires=systemd-user-sessions.service
 After=systemd-user-sessions.service
 Wants=dbus.socket
 After=dbus.socket
+# CRITICAL: Wait for Plymouth to fully quit and release DRM
+After=plymouth-quit-timer.service

 # Socket requirement
 Requires=weston.socket
```

**File 2:** `yocto-workspace/meta-custom/meta-env/recipes-core/plymouth/plymouth/plymouth-quit-timer.service`

```diff
 [Unit]
 Description=Plymouth Quit Timer (7 seconds exact)
 After=plymouth-start.service
 Before=display-manager.service
 DefaultDependencies=no

 [Service]
 Type=oneshot
-# Wait exactly 7 seconds then quit Plymouth
-ExecStart=/bin/sh -c 'sleep 7 && /usr/bin/plymouth quit --retain-splash'
+# Wait exactly 7 seconds then quit Plymouth completely
+ExecStart=/bin/sh -c 'sleep 7 && /usr/bin/plymouth quit --wait'
 RemainAfterExit=yes
 TimeoutStartSec=15
```

**Explanation:**
- `After=plymouth-quit-timer.service` ensures Weston waits for Plymouth to quit
- `plymouth quit --wait` (instead of `--retain-splash`) ensures Plymouth fully releases DRM
- Boot timeline: Plymouth (7s) → Plymouth quits and releases DRM → Weston starts → Apps start

---

### ✅ SOLUTION B: Optimal - Plymouth and Weston Parallel Start
**Complexity**: Medium
**Risk**: Medium
**Boot Time Impact**: Best (apps ready when Plymouth quits)
**Status**: Requires testing

#### Strategy:
Start Weston **in parallel** with Plymouth, but make Weston **wait to acquire DRM** until Plymouth quits.

#### Changes Required:
1. Remove `--retain-splash` from plymouth-quit-timer
2. Add retry logic to Weston startup
3. Keep app services as-is (they already have socket wait logic)

**File 1:** `yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service`

```ini
[Unit]
Description=Weston Wayland Compositor
Documentation=man:weston(1) man:weston.ini(5)

# Dependencies (no Plymouth dependency - will start in parallel)
Requires=systemd-user-sessions.service
After=systemd-user-sessions.service
Wants=dbus.socket
After=dbus.socket

# Socket requirement
Requires=weston.socket

# Start before graphical target
Before=graphical.target

# Require tty0
ConditionPathExists=/dev/tty0

[Service]
Type=simple

# Environment
EnvironmentFile=-/etc/default/weston

# Wait for DRM to be available (Plymouth might be holding it)
# Retry for up to 10 seconds
ExecStartPre=/bin/sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do if [ -e /dev/dri/card0 ] && ! fuser /dev/dri/card0 2>/dev/null | grep -q plymouth; then exit 0; fi; sleep 1; done; exit 0'

# Start Weston with dual-display config
ExecStart=/usr/bin/weston --config=/etc/xdg/weston/weston.ini

# Give Weston time to initialize
ExecStartPost=/bin/sleep 1

# Restart policy - if Plymouth holds DRM, Weston will retry
Restart=on-failure
RestartSec=2
StartLimitBurst=5

# Run as root for reliability
User=root
Group=root

# Working directory
WorkingDirectory=/root

# Virtual terminal
TTYPath=/dev/tty7
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes

# I/O
StandardInput=null
StandardOutput=journal
StandardError=journal

# Timeouts
TimeoutStartSec=15

# Utmp
UtmpIdentifier=tty7
UtmpMode=user

[Install]
WantedBy=graphical.target
```

**File 2:** Same as Solution A - fix plymouth-quit-timer.service

**Explanation:**
- Weston starts immediately (no `After=plymouth-quit-timer`)
- ExecStartPre checks if Plymouth is using DRM, waits if needed
- If Plymouth holds DRM, Weston retries (Restart=on-failure)
- Timeline: Plymouth starts → Weston starts (waits for DRM) → Plymouth quits at 7s → Weston acquires DRM → Apps start

---

### ✅ SOLUTION C: Emergency Rollback - Disable Fast Boot
**Complexity**: Minimal
**Risk**: None
**Boot Time Impact**: Back to original (~15 seconds)
**Status**: Immediate fallback option

#### Strategy:
Restore sequential boot: Plymouth → Weston → Head-Unit → IC

**Implementation:**

Revert to using default Plymouth quit services:

**File 1:** `yocto-workspace/meta-custom/meta-env/recipes-core/plymouth/plymouth_%.bbappend`

```diff
 pkg_postinst_ontarget:${PN}:append() {
-    # Enable plymouth-quit-timer (this will quit Plymouth after 7 seconds)
-    systemctl enable plymouth-quit-timer.service || true
-
-    # Mask default plymouth-quit services to prevent early termination
-    systemctl mask plymouth-quit.service || true
-    systemctl mask plymouth-quit-wait.service || true
+    # Use default plymouth-quit-wait for reliable sequential boot
+    systemctl unmask plymouth-quit-wait.service || true
+    systemctl enable plymouth-quit-wait.service || true
+    systemctl disable plymouth-quit-timer.service || true

     systemctl daemon-reload || true
 }
```

**File 2:** `yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service`

```diff
 [Unit]
 Description=Weston Wayland Compositor
 Documentation=man:weston(1) man:weston.ini(5)

 # Dependencies
 Requires=systemd-user-sessions.service
 After=systemd-user-sessions.service
 Wants=dbus.socket
 After=dbus.socket
+# Wait for Plymouth to quit (default behavior)
+After=plymouth-quit-wait.service
```

**File 3:** Keep IC sequential start:

`yocto-workspace/meta-custom/meta-app/recipes-des/instrument-cluster/files/instrument-cluster.service`

```diff
 [Unit]
 Description=Instrument Cluster Application
-After=weston.service piracer-controller.service
+After=weston.service headunit.service piracer-controller.service
 Wants=weston.service piracer-controller.service
```

---

## Comparison Matrix

| Solution | Boot Time | Reliability | Complexity | Apps Start Time |
|----------|-----------|-------------|------------|-----------------|
| **A: Sequential (Recommended)** | ~7-8s | ⭐⭐⭐⭐⭐ High | Low | After 7s |
| **B: Parallel Start** | ~7-8s | ⭐⭐⭐⭐ Good | Medium | At exactly 7s |
| **C: Rollback** | ~12-15s | ⭐⭐⭐⭐⭐ High | Minimal | After 12s+ |

---

## Recommended Implementation Order

### Phase 1: Immediate Fix (Solution A)
1. Apply weston.service changes
2. Apply plymouth-quit-timer.service changes
3. Rebuild and test
4. **Expected result:** Reliable boot, apps appear after 7 seconds

### Phase 2: Optimization (Solution B) - Optional
1. Apply Solution B changes
2. Test multiple boot cycles
3. Validate DRM handoff timing
4. **Expected result:** Apps ready exactly when Plymouth quits

### Phase 3: Fallback (Solution C) - If needed
1. Apply rollback changes
2. Accept longer boot time for stability
3. **Expected result:** Guaranteed working system

---

## Testing Checklist

After applying Solution A:
- [ ] Image builds successfully
- [ ] Plymouth animation plays for 7 seconds
- [ ] Plymouth quits cleanly
- [ ] Weston starts and creates `/run/wayland-0`
- [ ] Head-Unit appears on HDMI-A-1
- [ ] Instrument Cluster appears on HDMI-A-2
- [ ] No kernel panics or service failures
- [ ] System logs show clean service startup

---

## Build & Deploy Commands

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des

# Clean affected recipes
bitbake -c cleansstate plymouth weston-init headunit instrument-cluster

# Rebuild image
bitbake des-image

# Deploy (copy to SD card)
# Image location: build-des/tmp-glibc/deploy/images/raspberrypi4-64/des-image-raspberrypi4-64.wic.bz2
```

---

## Diagnostic Commands (Post-Deploy)

SSH into Raspberry Pi and run:

```bash
# Check service status
systemctl status plymouth-quit-timer.service
systemctl status weston.service
systemctl status headunit.service
systemctl status instrument-cluster.service

# Check Wayland socket
ls -la /run/wayland-0

# Check logs
journalctl -u plymouth-quit-timer.service -b
journalctl -u weston.service -b
journalctl -u headunit.service -b
journalctl -u instrument-cluster.service -b

# Check DRM
ls -la /dev/dri/
dmesg | grep -i drm

# Boot timeline
systemd-analyze critical-chain graphical.target
```
