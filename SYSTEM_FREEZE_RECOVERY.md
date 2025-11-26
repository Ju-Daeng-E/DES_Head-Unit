# System Freeze Recovery Guide

## 🚨 EMERGENCY: System Completely Frozen After Boot

### Current Situation
- Plymouth boot animation completes
- **Black screen appears**
- **System completely frozen**
- **Cannot switch TTYs** (Ctrl+Alt+F1-F7 don't work)
- **No logs accessible** - system is dead

### What This Means
This is **NOT** a simple service failure. This is:
- ✅ Likely: Kernel panic or systemd deadlock
- ✅ Likely: Critical service hanging during boot
- ✅ Likely: Circular dependency in systemd
- ❌ **NOT** a Weston-only problem

---

## ⚡ IMMEDIATE ACTION - Emergency Rollback

### Step 1: Rollback to Minimal Safe Configuration

```bash
cd /home/seame/DES_Head-Unit

# Apply emergency rollback
./EMERGENCY_ROLLBACK.sh
```

**This removes ALL recent changes and returns to:**
- ❌ No Plymouth (boot directly to console)
- ✅ Minimal Weston (no fancy options)
- ❌ No WiFi auto-enable
- ❌ Instrument Cluster disabled (for debugging)
- ✅ HeadUnit only (simplified)

---

### Step 2: Clean Rebuild

```bash
cd yocto-workspace
. poky/oe-init-build-env build-des

# Clean ALL modified recipes
bitbake -c cleansstate rpi-cmdline
bitbake -c cleansstate plymouth
bitbake -c cleansstate weston-init
bitbake -c cleansstate headunit
bitbake -c cleansstate instrument-cluster
bitbake -c cleansstate wifi-auto-enable

# Rebuild
bitbake des-image
```

**Expected time:** 30-40 minutes

---

### Step 3: Deploy and Test

```bash
# Deploy to SD card
sudo umount /dev/sdb*
sudo bzcat build-des/tmp-glibc/deploy/images/raspberrypi4-64/des-image-raspberrypi4-64.wic.bz2 | sudo dd of=/dev/sdb bs=4M status=progress
sync
```

**Expected boot behavior:**
```
[Kernel messages appear]
  ↓
[systemd boot messages]
  ↓
[TTY1 login prompt appears] ← System is RESPONSIVE
  ↓
[You can login and check logs]
```

---

## 🔍 If System Still Freezes

### Diagnosis: Serial Console Required

If system still freezes with minimal config, you **MUST** use serial console to see what's happening.

#### Hardware Setup

Connect UART to USB serial cable:

| Raspberry Pi GPIO | Serial Cable |
|-------------------|--------------|
| GPIO 14 (TXD)     | RX (white)   |
| GPIO 15 (RXD)     | TX (green)   |
| GND (Pin 6)       | GND (black)  |

**DO NOT** connect VCC/5V!

#### Access Serial Console

On your laptop:
```bash
# Find device
ls /dev/ttyUSB*

# Connect (baud rate 115200)
sudo screen /dev/ttyUSB0 115200

# Alternative: minicom
sudo minicom -D /dev/ttyUSB0 -b 115200
```

#### Boot and Capture Output

Power on Raspberry Pi. You'll see:
```
[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Linux version 6.1.x ...
...
[   OK   ] Started systemd-journald.service
[ STUCK ] Starting some-service.service
```

**Look for where it gets stuck!**

Common stuck points:
- `Starting weston.service` → Weston hangs
- `Starting plymouth-quit.service` → Plymouth hangs
- `Reached target graphical.target` → Target reached but frozen
- `A start job is running for...` → Service timeout

---

## 🛠️ Root Cause Analysis (Based on Freeze Point)

### If Stuck on: `plymouth-quit-timer.service`

**Problem:** Plymouth timer waiting but never completing

**Fix in emergency rollback:** Plymouth is completely disabled

**If you want Plymouth back later:**
```ini
# Simplest possible plymouth-quit
ExecStart=/usr/bin/plymouth quit
# No --wait, no --retain-splash, just quit
```

---

### If Stuck on: `weston.service`

**Problem:** Weston trying to acquire resource that doesn't exist

**What minimal config does:**
- No `ConditionPathExists` checks
- No `ExecStartPre` waits
- No socket dependency
- Just: `ExecStart=/usr/bin/weston`

**This should fail gracefully if Weston can't start, not freeze**

---

### If Stuck on: `headunit.service` or `instrument-cluster.service`

**Problem:** ExecStartPre waiting forever for Wayland socket

**What minimal config does:**
- Simple 5-second sleep instead of loop
- No socket checking
- If Weston isn't ready, app fails but doesn't hang

---

### If Stuck BEFORE any services

**Problem:** Kernel panic or initramfs issue

**Serial console will show:**
```
Kernel panic - not syncing: ...
```

**Fix:** This is kernel/driver issue, not service configuration

---

## 🎯 Debugging with Minimal Config

Once minimal config boots successfully:

### 1. Login via TTY1

```bash
root  # Usually no password

# Check what's running
systemctl status
systemctl --failed

# Check Weston
systemctl status weston.service

# Check HeadUnit
systemctl status headunit.service

# View logs
journalctl -xe | tail -100
journalctl -u weston.service
journalctl -u headunit.service
```

---

### 2. Manually Start Services

```bash
# Try starting Weston manually
systemctl start weston.service

# Check if it worked
systemctl status weston.service

# If failed, see why:
journalctl -u weston.service -n 50
```

---

### 3. Test Weston Directly

```bash
# Stop service
systemctl stop weston.service

# Run Weston manually
/usr/bin/weston

# Look for errors in output
# Press Ctrl+C to stop
```

---

## 🔄 Gradual Re-Enabling (After Minimal Config Works)

### Step 1: Add Instrument Cluster Back

```ini
[Unit]
Description=Instrument Cluster Application
After=weston.service headunit.service

[Service]
Type=simple
Environment=QT_QPA_PLATFORM=wayland
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/appIC
User=root
Group=root
```

Rebuild, test. If works, continue.

---

### Step 2: Add Plymouth Back (Simple)

```ini
# plymouth-quit-timer.service
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'sleep 5 && /usr/bin/plymouth quit'
```

Rebuild, test. If works, continue.

---

### Step 3: Add WiFi Auto-Enable

Only if you need it. Otherwise leave disabled.

---

## 🆘 If Minimal Config STILL Freezes

This means the problem is deeper than service configuration:

### Possible Root Causes:

1. **Kernel driver issue**
   - DRM driver crash
   - GPU firmware problem
   - HDMI detection hanging

2. **systemd bug**
   - Version incompatibility
   - Init system deadlock

3. **Hardware issue**
   - SD card corruption
   - Power supply insufficient
   - Raspberry Pi hardware fault

### Next Steps:

1. **Try different kernel:**
   ```bash
   # In yocto build
   # Check kernel version
   bitbake -e virtual/kernel | grep "^PV="

   # Try different kernel version in local.conf
   PREFERRED_VERSION_linux-raspberrypi = "6.1.%"
   ```

2. **Try without GPU:**
   ```bash
   # In rpi-cmdline
   CMDLINE:append = " nomodeset"
   ```

3. **Minimal image test:**
   ```bash
   # Build core-image-minimal instead
   bitbake core-image-minimal
   # If this boots, problem is in our custom layers
   ```

---

## 📊 Success Criteria

### Minimal Config Working:
- ✅ Kernel boots
- ✅ TTY1 login appears
- ✅ Can switch TTYs (Ctrl+Alt+F1-F7)
- ✅ Can run commands
- ✅ `systemctl status` works
- ✅ Weston may or may not work (but system doesn't freeze)

### Full Recovery:
- ✅ Weston starts
- ✅ HeadUnit appears
- ✅ Instrument Cluster appears
- ✅ No system freeze

---

## 한국어 요약

### 긴급 상황:
시스템이 완전히 멈췄습니다 (TTY 전환도 안 됨).

### 즉시 조치:
```bash
./EMERGENCY_ROLLBACK.sh  # 최소 안전 설정으로 복구
# 그 다음 재빌드
```

### 최소 설정 특징:
- Plymouth 완전 제거
- Weston 최소 설정
- IC 비활성화 (디버깅 용이)
- 모든 복잡한 기능 제거

### 예상 결과:
- TTY1 로그인 화면
- 시스템 응답함
- 로그 확인 가능

### 여전히 멈추면:
- 시리얼 콘솔 필수 (UART 케이블)
- 커널 로그 확인
- 어디서 멈추는지 파악

---

**지금 바로 EMERGENCY_ROLLBACK.sh 실행하세요!** 🚨
