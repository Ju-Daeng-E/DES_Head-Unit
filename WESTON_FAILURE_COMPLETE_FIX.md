# Weston Service Failure - Complete Fix

## 🔴 Critical Issues

### Issue 1: Weston Service Fails to Start
**Symptom:** `systemctl status weston.service` shows **failed** or **activating**
**Impact:** No graphical output, apps can't start, black screen or TTY1 console

### Issue 2: wlan0 Stays DOWN
**Symptom:** WiFi enabled in ConnMan but `ip link show wlan0` shows **DOWN**
**Impact:** Can't SSH to debug, must use serial console

---

## ✅ Applied Fixes

I've created **improved service files** that address all likely failure causes:

### 1. **weston.service.fixed** - Comprehensive Weston Fix

**New features:**
- ✅ **Explicit XDG_RUNTIME_DIR=/run** - Prevents "cannot connect" errors
- ✅ **Wait for DRM device** - Checks `/dev/dri/card0` exists and is writable
- ✅ **Clean stale sockets** - Removes `/run/wayland-0` before start
- ✅ **Create /run directory** - Ensures runtime directory exists
- ✅ **Logging to file** - Weston output saved to `/var/log/weston.log`
- ✅ **Proper groups** - Added `video input render` supplementary groups
- ✅ **Wait for multi-user.target** - Don't start too early
- ✅ **Condition on DRM** - Service won't start if no DRM device
- ✅ **Better timeouts** - 30s start timeout, 5 retry attempts
- ✅ **Plymouth coordination** - Wait for plymouth-quit-timer

### 2. **wifi-auto-enable.service.fixed** - WiFi Fix

**New features:**
- ✅ **Dynamic interface detection** - Finds any `wlan*` interface
- ✅ **Multiple unblock attempts** - Both `rfkill` and `connmanctl`
- ✅ **Non-blocking** - Won't hang boot if WiFi fails
- ✅ **Timeout protection** - 30s timeout prevents infinite wait
- ✅ **Proper dependencies** - Waits for ConnMan service

---

## 🚀 How to Apply

### Method A: Automatic (Recommended)

```bash
cd /home/seame/DES_Head-Unit

# Apply all fixes
./APPLY_WESTON_WIFI_FIX.sh

# Rebuild
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake -c cleansstate weston-init wifi-auto-enable
bitbake des-image

# Deploy to SD card
sudo umount /dev/sdb*
sudo bzcat build-des/tmp-glibc/deploy/images/raspberrypi4-64/des-image-raspberrypi4-64.wic.bz2 | sudo dd of=/dev/sdb bs=4M status=progress
sync
```

### Method B: Manual Application

```bash
# Backup
cp yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service{,.backup}
cp yocto-workspace/meta-custom/meta-env/recipes-connectivity/wifi-auto-enable/files/wifi-auto-enable.service{,.backup}

# Apply fixes
cp yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service.fixed \
   yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service

cp yocto-workspace/meta-custom/meta-env/recipes-connectivity/wifi-auto-enable/files/wifi-auto-enable.service.fixed \
   yocto-workspace/meta-custom/meta-env/recipes-connectivity/wifi-auto-enable/files/wifi-auto-enable.service
```

---

## 🔍 Debugging After Deploy

### If Weston Still Fails:

#### 1. Serial Console Access (Best Option)

Connect UART serial cable to Raspberry Pi:
- TX (GPIO 14)
- RX (GPIO 15)
- GND

On laptop:
```bash
sudo screen /dev/ttyUSB0 115200
```

When Pi boots and shows TTY1 login:
```bash
# Login as root (usually no password)
root

# Get Weston status
systemctl status weston.service -l

# Check logs
journalctl -u weston.service -b --no-pager | tail -100

# Check Weston output
cat /var/log/weston.log

# Check DRM
ls -la /dev/dri/
dmesg | grep drm

# Check TTY
fgconsole
fuser /dev/tty7

# Manual start test
systemctl stop weston.service
/usr/bin/weston --config=/etc/xdg/weston/weston.ini --log=/tmp/weston-manual.log
# Press Ctrl+C after 5 seconds
cat /tmp/weston-manual.log
```

#### 2. SD Card Analysis (If No Serial)

Remove SD card, mount on laptop:

```bash
# Find partitions
lsblk

# Mount root partition (usually partition 2)
sudo mkdir -p /mnt/pi-root
sudo mount /dev/sdb2 /mnt/pi-root

# Check if files are installed
ls -la /mnt/pi-root/lib/systemd/system/weston.service
ls -la /mnt/pi-root/etc/xdg/weston/weston.ini
ls -la /mnt/pi-root/usr/bin/weston

# Check journal logs
sudo journalctl --file=/mnt/pi-root/var/log/journal/*/system.journal -u weston.service | tail -100

# Unmount
sudo umount /mnt/pi-root
```

---

## 🐛 Common Weston Failure Causes & Solutions

### Error: "failed to create display"

**Cause:** DRM device not accessible or already in use

**Check:**
```bash
ls -la /dev/dri/card0
# Should show: crw-rw---- 1 root video ...

# Check if something else is using it
fuser /dev/dri/card0
```

**Fix:** Ensure Weston runs as root or is in `video` group

---

### Error: "cannot create socket"

**Cause:** `/run` directory doesn't exist or not writable

**Check:**
```bash
ls -ld /run
# Should show: drwxr-xr-x ... root root ... /run

ls -la /run/wayland-0
```

**Fix:** The new weston.service creates `/run` automatically

---

### Error: "failed to open /dev/tty7"

**Cause:** Plymouth still holding TTY7, or systemd VT allocation issue

**Check:**
```bash
fuser /dev/tty7
ps aux | grep plymouth
```

**Fix:** Check Plymouth config has `VT=7` and uses `--retain-splash`

---

### Error: "DRM master already held"

**Cause:** Plymouth or another program has DRM master lock

**Check:**
```bash
fuser /dev/dri/card0
dmesg | grep -i drm | tail -20
```

**Fix:** Ensure Plymouth quits fully before Weston starts

---

## 📡 WiFi Debugging

### If wlan0 Stays DOWN:

```bash
# Check interface exists
ip link show

# Check rfkill blocks
rfkill list
# Should NOT show "Soft blocked: yes" for wlan

# Unblock manually
rfkill unblock wifi
rfkill unblock wlan

# Bring up interface
ip link set wlan0 up

# Check driver loaded
lsmod | grep brcm
dmesg | grep -i wifi

# Check firmware
ls -la /lib/firmware/brcm/

# ConnMan status
connmanctl services
connmanctl technologies
```

### If Firmware Missing:

The Raspberry Pi 4 WiFi needs `brcmfmac43455-sdio.bin` and `.txt` files.

**Check in Yocto:**
```bash
# In your build, ensure linux-firmware-bcm43455 is installed
# Should be in IMAGE_INSTALL in des-image.bb
```

---

## ✅ Success Criteria

After applying fixes and rebooting:

### Visual:
- ✅ Plymouth animation plays
- ✅ Apps appear (no TTY1 login)
- ✅ Both displays working

### Serial Console:
```bash
systemctl status weston.service
# Should show: active (running)

systemctl status headunit.service
# Should show: active (running)

systemctl status instrument-cluster.service
# Should show: active (running)

ls -la /run/wayland-0
# Should show: srwxrwxrwx ... wayland-0

ip link show wlan0
# Should show: state UP

connmanctl services
# Should show available WiFi networks
```

---

## 🆘 Emergency Fallback: Minimal Weston Config

If dual-display config causes issues, use minimal config:

```bash
# Use weston.ini.minimal instead
cp yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston.ini.minimal \
   yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston.ini

# Rebuild
bitbake -c cleansstate weston-init
bitbake des-image
```

This uses simplest possible Weston config - just DRM backend, no fancy features.

---

## 📞 Next Steps

1. **Apply the fix:**
   ```bash
   ./APPLY_WESTON_WIFI_FIX.sh
   ```

2. **Rebuild and deploy**

3. **Boot and check via serial console:**
   - Use `/tmp/weston_debug_serial.sh` on the Pi
   - Send me the output

4. **If still failing:**
   - Get full `journalctl -u weston.service -b` output
   - Get `/var/log/weston.log` contents
   - Get `dmesg | grep drm` output

---

## 🎯 한국어 요약

### 수정된 내용:

1. **Weston 서비스 강화:**
   - DRM 장치 대기 로직 추가
   - 오래된 소켓 자동 정리
   - 로그 파일 생성 (/var/log/weston.log)
   - 타임아웃 증가 및 재시도 로직
   - 필수 그룹(video, input, render) 추가

2. **WiFi 서비스 수정:**
   - wlan* 인터페이스 자동 감지
   - rfkill + connmanctl 다중 시도
   - 부팅 차단 방지 (non-blocking)
   - 타임아웃 추가

### 적용 방법:

```bash
./APPLY_WESTON_WIFI_FIX.sh  # 수정사항 적용
# 그 다음 재빌드 및 배포
```

### 디버깅:

- 시리얼 콘솔로 접속 (UART 케이블)
- `/tmp/weston_debug_serial.sh` 실행
- 로그 확인: `journalctl -u weston.service -b`

---

**Fix ready to apply! 🚀**
