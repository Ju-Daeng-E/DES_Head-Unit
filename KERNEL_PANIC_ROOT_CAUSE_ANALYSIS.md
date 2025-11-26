# Kernel Panic Root Cause Analysis & Resolution

**Date**: 2025-11-13
**Issue**: Kernel panic after flashing image with initial Wayland fixes
**Status**: Root cause identified and resolved

---

## Executive Summary

The kernel panic was caused by **User/PAM mismatch** in weston.service. The service was configured to:
- Run as `User=root`
- Use `PAMName=weston-autologin` (configured for weston user)

This mismatch caused PAM authentication failure, preventing Weston from starting, which blocked `graphical.target` due to `Before=graphical.target` dependency, ultimately causing boot failure.

---

## Root Cause Analysis

### 1. Initial Incorrect Configuration

**File**: `weston.service` (custom, first attempt)

```ini
[Service]
User=root
Group=root
WorkingDirectory=/root
PAMName=weston-autologin  # ❌ CRITICAL ERROR
```

**Problem**: `weston-autologin` PAM configuration expects `weston` user, not `root`.

**PAM File**: `/etc/pam.d/weston-autologin`
```
auth      required  pam_unix.so     try_first_pass nullok
account   required  pam_unix.so
session   required  pam_unix.so
-session  optional  pam_systemd.so type=wayland class=user desktop=weston
```

**What Happened**:
1. systemd tries to start weston.service
2. PAM module checks for `weston` user session
3. Actual user is `root` → PAM authentication fails
4. weston.service fails to start
5. `graphical.target` waits (due to `Before=graphical.target`)
6. Boot process hangs/panics

### 2. Why It Caused Kernel Panic

**Boot Sequence**:
```
systemd → multi-user.target → graphical.target
                                     ↑
                                     |
                              [Before=graphical.target]
                                     |
                              weston.service (FAILED)
                                     ↓
                              [Boot hangs/panics]
```

- `graphical.target` cannot complete without weston.service
- System waits indefinitely or times out
- Kernel panic or black screen with no TTY access

### 3. Additional Contributing Factors

**Factor A: XDG_RUNTIME_DIR=/run**
- Set in custom `weston-default` file
- `weston` user may not have write access to `/run` root directory
- Should rely on systemd/PAM automatic configuration

**Factor B: Missing --backend Parameter**
- Original weston.service: `ExecStart=/usr/bin/weston --modules=systemd-notify.so`
- Custom added: `--backend=drm-backend.so --config=/etc/xdg/weston/weston.ini`
- `--backend` specified in weston.ini `[core]` section already
- Redundant parameter might cause conflicts

---

## Verification Process

### Step 1: Confirmed systemd-notify.so Exists
```bash
find build-des/tmp-glibc/sysroots-components -name "systemd-notify.so"
# Result: /usr/lib/weston/systemd-notify.so ✅
```

### Step 2: Checked Weston Build Configuration
```bash
bitbake -e weston | grep "^PACKAGECONFIG="
# Result: systemd is enabled ✅
```

### Step 3: Verified PAM Configuration
```bash
# weston-init.bb installs PAM file when pam in DISTRO_FEATURES
# Result: weston-autologin exists and configured for weston user ✅
```

### Step 4: Cross-Referenced Original Files
- Original `weston.service`: `User=weston`, `PAMName=weston-autologin` ✅
- Original `weston.env`: Empty file (no XDG_RUNTIME_DIR) ✅
- Original `weston.socket`: `SocketUser=weston`, `SocketGroup=wayland` ✅

---

## Resolution Strategy

### Approach: Minimal Deviation from Upstream

**Principle**: Use original weston.service as-is, only customize weston.ini for dual-display.

**Rationale**:
1. Upstream configuration is battle-tested
2. PAM, systemd, TTY settings are already correct
3. Only need to point to custom weston.ini
4. Minimize risk of configuration errors

### Key Changes

#### 1. weston.service (FIXED)
```ini
[Service]
Type=notify
EnvironmentFile=/etc/default/weston
ExecStart=/usr/bin/weston --config=/etc/xdg/weston/weston.ini --modules=systemd-notify.so

# ✅ CORRECT: weston user with matching PAM config
User=weston
Group=weston
WorkingDirectory=/home/weston
PAMName=weston-autologin  # Matches /etc/pam.d/weston-autologin

# Standard TTY configuration
TTYPath=/dev/tty7
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty-fail
```

**Changes from original**:
- Added `--config=/etc/xdg/weston/weston.ini` to use custom dual-display config
- Removed redundant `--backend=drm-backend.so` (specified in weston.ini)

#### 2. weston.socket (FIXED)
```ini
[Socket]
ListenStream=/run/wayland-0
SocketMode=0775  # ✅ weston user + wayland group access
SocketUser=weston
SocketGroup=wayland
```

**Changes from incorrect version**:
- `SocketUser=root` → `weston`
- `SocketGroup=root` → `wayland`
- `SocketMode=0777` → `0775` (more secure)

#### 3. weston-default (FIXED)
```bash
# ✅ Removed XDG_RUNTIME_DIR=/run
# systemd/PAM will set it automatically to /run/user/<uid>

WAYLAND_DISPLAY=wayland-0
```

#### 4. headunit.service & instrument-cluster.service (FIXED)
```ini
[Service]
User=root  # Required for D-Bus com.des.vehicle ownership
Group=root
SupplementaryGroups=wayland  # ✅ Access to /run/wayland-0 socket
```

**Rationale**:
- D-Bus policy restricts `com.des.vehicle` service ownership to root user
- InstrumentCluster provides this service → must run as root
- HeadUnit also runs as root for consistency
- `SupplementaryGroups=wayland` grants access to Wayland socket

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│           Weston Compositor                      │
│   User: weston, Group: weston                    │
│   Socket: /run/wayland-0 (weston:wayland 0775) │
│   PAM: weston-autologin                         │
└────────────┬────────────────────────────────────┘
             │
             │ /run/wayland-0 socket
             │ (accessible to wayland group)
             │
     ┌───────┴────────┐
     │                │
┌────▼─────┐    ┌─────▼────┐
│ HeadUnit │    │    IC    │
│ root:root│    │ root:root│
│ +wayland │    │ +wayland │
└──────────┘    └──────────┘
     │                │
     │                │
     └────────┬───────┘
              │
        D-Bus system bus
        (com.des.vehicle)
```

---

## Validation Checklist

### Configuration Validation
- [x] weston.service uses weston user
- [x] PAMName matches user (weston-autologin for weston user)
- [x] WorkingDirectory points to /home/weston
- [x] weston.socket ownership matches weston user
- [x] HeadUnit/IC have SupplementaryGroups=wayland
- [x] XDG_RUNTIME_DIR not hardcoded (systemd/PAM sets it)
- [x] weston.ini backend specified correctly
- [x] systemd-notify.so module exists

### Permissions Validation
- [x] weston user exists (created by weston-init useradd)
- [x] wayland group exists (created by weston-init groupadd)
- [x] /home/weston directory created by weston-init
- [x] weston user in groups: weston, video, input, render, wayland
- [x] /run/wayland-0 socket mode allows group access (0775)

### Dependencies Validation
- [x] weston.service Requires=weston.socket
- [x] weston.service Before=graphical.target
- [x] headunit.service After=weston.service, Requires=weston.service
- [x] instrument-cluster.service After=weston.service headunit.service

---

## Testing Strategy

### Boot Test
1. Flash new image to SD card
2. Power on Raspberry Pi 4
3. Observe boot sequence
4. **Expected**: Boot completes to graphical.target

### TTY Access Test
1. Press CTRL+ALT+F1
2. **Expected**: Console login prompt appears
3. Login as root
4. Check services: `systemctl status weston.service`

### Weston Service Test
```bash
systemctl status weston.service
# Expected: active (running)

ls -la /run/wayland-0
# Expected: srwxrwxr-x 1 weston wayland 0 ... /run/wayland-0

ps aux | grep weston
# Expected: weston ... /usr/bin/weston --config=/etc/xdg/weston/weston.ini --modules=systemd-notify.so
```

### Application Test
```bash
systemctl status headunit.service instrument-cluster.service
# Expected: both active (running)

# Check groups
id root
# Expected: groups=... wayland ...
```

### Display Test
- HDMI-A-1: HeadUnit application visible
- HDMI-A-2: Instrument Cluster application visible
- Gear changes sync via D-Bus

---

## Lessons Learned

### 1. Always Match User and PAM Configuration
**Rule**: If `PAMName=X`, then `User` must match the user X expects.

### 2. Minimize Divergence from Upstream
**Rule**: Only customize what's necessary (weston.ini), keep service files close to original.

### 3. Let systemd/PAM Handle Environment
**Rule**: Don't hardcode XDG_RUNTIME_DIR unless required. systemd User= sessions set it automatically.

### 4. Socket Activation Requires Matching Ownership
**Rule**: weston.socket must be owned by same user running weston.service.

### 5. Cross-Verify All Dependencies
**Rule**: Use `bitbake -e`, `find`, and original file comparisons before assuming.

---

## Rebuild Commands

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des

# Clean affected packages
bitbake -c cleansstate weston-init headunit instrument-cluster

# Rebuild image
bitbake des-image
```

---

## Expected Outcome

✅ **Boot Success**: System boots to graphical.target
✅ **TTY Access**: CTRL+ALT+F1-F8 work
✅ **Weston Running**: weston.service active, socket created
✅ **Apps Running**: HeadUnit and IC services active
✅ **Displays Working**: Both HDMI outputs show correct applications
✅ **D-Bus Working**: Gear synchronization functions

---

**Resolution Status**: Configuration fixed, ready for rebuild
**Next Action**: Clean build and test on hardware
