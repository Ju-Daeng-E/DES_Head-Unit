# bluealsa Migration Plan - A2DP Sink Implementation

## Executive Summary

**Goal**: Migrate from PulseAudio to bluealsa (bluez-alsa) for A2DP Sink functionality to enable iPhone audio streaming to Raspberry Pi headunit.

**Reason**: PulseAudio MediaEndpoint registration is working, but A2DP profile activation is failing. bluealsa is more reliable for embedded A2DP Sink implementations.

**Estimated Time**: 3-4 hours (including build time)

**Success Criteria**: iPhone recognizes Raspberry Pi as audio output device in Control Center

---

## Current State Analysis

### What's Working ✅
- BlueZ 5.72 with experimental features enabled
- Bluetooth Class of Device: 0x6c0414 (Audio/Video, Loudspeaker)
- D-Bus policies configured for bluetooth communication
- HeadUnitApp BluetoothAgent auto-accepts pairing
- Auto-pairing successful (no PIN/passkey required)

### What's NOT Working ❌
- **PulseAudio MediaEndpoint registered BUT A2DP profile not activating**
- iPhone connects via BLE only, not Classic Bluetooth A2DP
- No Bluetooth audio card appears in PulseAudio
- iPhone does not show Raspberry Pi as audio output device

### Root Cause
PulseAudio's module-bluez5-discover/device implementation is not properly handling A2DP Sink profile negotiation with iOS devices. This is a known issue in embedded systems.

---

## bluealsa Overview

### What is bluealsa?
- BlueZ Audio ALSA Backend
- Direct ALSA PCM plugin for Bluetooth audio
- Bypasses PulseAudio complexity
- Widely used in automotive/embedded Linux

### Key Features
- **A2DP Sink & Source** support out-of-the-box
- **HFP/HSP** (Hands-Free Profile) support
- **AVRCP** (media control) support
- Low latency, minimal resource usage
- ALSA integration (works with Qt Multimedia)

### Architecture
```
iPhone (A2DP Source)
    ↓ Bluetooth Classic
BlueZ (org.bluez.MediaEndpoint1)
    ↓ D-Bus
bluealsa-aplay (captures A2DP stream)
    ↓ ALSA PCM
ALSA audio output (speakers/HDMI)
```

---

## Migration Plan

### Phase 1: Yocto Recipe Setup (30 min)

#### 1.1 Add bluez-alsa Recipe
- **File**: `meta-custom/meta-env/recipes-multimedia/bluez-alsa/bluez-alsa_%.bbappend`
- **Base Recipe**: `meta-openembedded/meta-oe/recipes-multimedia/bluez-alsa/`
- **Dependencies**: `bluez5`, `alsa-lib`, `sbc`, `dbus`

#### 1.2 Configure Build Options
```bitbake
PACKAGECONFIG = "a2dp aac hfp-hf hfp-ag cli"
# a2dp: A2DP Sink/Source
# aac: AAC codec support (better quality)
# hfp-hf: Hands-Free Profile (optional)
# cli: bluealsa-aplay tool
```

#### 1.3 Modify PulseAudio Recipe
- **File**: `meta-custom/meta-env/recipes-multimedia/pulseaudio/pulseaudio_%.bbappend`
- **Action**: REMOVE bluetooth module dependencies
```diff
- RDEPENDS:pulseaudio-server += "pulseaudio-module-bluetooth-discover pulseaudio-module-bluetooth-policy pulseaudio-module-bluez5-device pulseaudio-module-bluez5-discover"
+ # Bluetooth handled by bluealsa instead
```

### Phase 2: System Configuration (20 min)

#### 2.1 Create bluealsa systemd Service
- **File**: `meta-custom/meta-env/recipes-multimedia/bluez-alsa/files/bluealsa.service`
```ini
[Unit]
Description=BlueALSA Bluetooth Audio Service
Requires=bluetooth.service
After=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/bin/bluealsa -p a2dp-sink -p a2dp-source
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

#### 2.2 Create bluealsa-aplay systemd Service
- **File**: `meta-custom/meta-env/recipes-multimedia/bluez-alsa/files/bluealsa-aplay.service`
```ini
[Unit]
Description=BlueALSA A2DP Audio Player
Requires=bluealsa.service
After=bluealsa.service

[Service]
Type=simple
ExecStart=/usr/bin/bluealsa-aplay --pcm=default 00:00:00:00:00:00
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

#### 2.3 Update D-Bus Policy
- **File**: `meta-custom/meta-app/recipes-des/headunit/files/headunit-bluetooth.conf`
- **Add**: bluealsa D-Bus permissions
```xml
<policy user="bluealsa">
  <allow send_destination="org.bluez"/>
  <allow receive_sender="org.bluez"/>
</policy>
```

#### 2.4 Update BlueZ main.conf (NO CHANGES NEEDED)
- Keep current configuration:
```ini
Class = 0x6c0414
Experimental = true
```

### Phase 3: Image Recipe Update (10 min)

#### 3.1 Add bluealsa to Image
- **File**: `meta-custom/meta-env/recipes-core/images/des-image.bb`
```diff
IMAGE_INSTALL:append = " \
    ...
+   bluez-alsa \
"
```

#### 3.2 Optional: Remove PulseAudio Bluetooth (if conflicts occur)
```diff
- IMAGE_INSTALL:append = " pulseaudio-server pulseaudio-module-bluetooth-* "
+ IMAGE_INSTALL:append = " pulseaudio-server "
```

### Phase 4: HeadUnitApp Integration (30 min)

#### 4.1 Verify Qt Multimedia ALSA Backend
- Qt Multimedia should automatically use ALSA
- No code changes needed for MusicPlayer
- Test local audio playback after migration

#### 4.2 Bluetooth Audio Stream Handling
- **Option A**: Let bluealsa-aplay handle everything automatically
- **Option B**: Monitor D-Bus for A2DP connections and trigger playback

**Recommended: Option A** - bluealsa-aplay auto-plays when iPhone connects

#### 4.3 Update BluetoothAgent (Optional Enhancement)
- Add service authorization logging
- Monitor A2DP connection status

### Phase 5: Build & Deploy (60-90 min)

#### 5.1 Clean Build
```bash
cd yocto-workspace
. poky/oe-init-build-env build-des

# Clean affected recipes
bitbake -c cleanall bluez-alsa pulseaudio headunit

# Rebuild image
bitbake des-image
```

#### 5.2 Deploy to SD Card
```bash
cd build-des/tmp-glibc/deploy/images/raspberrypi4-64/
sudo dd if=des-image-raspberrypi4-64.wic.bz2 of=/dev/sdX bs=4M status=progress conv=fsync
```

### Phase 6: Testing & Validation (30 min)

#### 6.1 System Boot Checks
```bash
ssh root@192.168.86.22

# Verify services
systemctl status bluealsa.service
systemctl status bluealsa-aplay.service
systemctl status bluetooth.service

# Check bluealsa devices
bluealsa-aplay -L
```

#### 6.2 A2DP Connection Test
1. **iPhone**: Settings → Bluetooth → Pair with "SEAME2025"
2. **Auto-pairing**: Should work via HeadUnitApp agent
3. **iPhone**: Open Music app, start playback
4. **iPhone**: Control Center → Audio Output
5. **Verify**: "SEAME2025" appears as audio output device
6. **Select**: Tap "SEAME2025"
7. **Result**: Audio should play through Raspberry Pi

#### 6.3 Log Verification
```bash
journalctl -u bluealsa.service -f
journalctl -u bluealsa-aplay.service -f
journalctl -u bluetooth.service -f
```

---

## Expected Issues & Solutions

### Issue 1: bluealsa-aplay not auto-starting
**Symptom**: Service fails with "No device found"
**Solution**: Use device wildcard `00:00:00:00:00:00` to wait for any device

### Issue 2: Audio device conflict
**Symptom**: Multiple ALSA devices, wrong one selected
**Solution**: Configure ALSA default device in `/etc/asound.conf`

### Issue 3: AAC codec not working
**Symptom**: Only SBC audio (lower quality)
**Solution**: Ensure `PACKAGECONFIG` includes `aac`, rebuild bluez-alsa with libfdk-aac

### Issue 4: HeadUnitApp MusicPlayer interference
**Symptom**: Local music and Bluetooth audio conflict
**Solution**: Implement exclusive audio mode - pause local player when Bluetooth connects

### Issue 5: PulseAudio still interfering
**Symptom**: bluealsa fails to register endpoints
**Solution**:
```bash
systemctl stop pulseaudio.service
systemctl disable pulseaudio.service
```

---

## Rollback Plan

If bluealsa migration fails, restore PulseAudio:

### Quick Rollback (10 min)
1. Flash previous SD card image backup
2. Boot Raspberry Pi
3. Continue PulseAudio debugging

### Full Rollback (90 min)
1. Revert Yocto recipe changes:
```bash
git checkout meta-custom/meta-env/recipes-multimedia/pulseaudio/
git checkout meta-custom/meta-env/recipes-core/images/des-image.bb
```
2. Rebuild image with PulseAudio
3. Deploy

---

## Success Metrics

### Must-Have ✅
- [ ] bluealsa.service running without errors
- [ ] iPhone pairs automatically (existing agent works)
- [ ] iPhone shows "SEAME2025" in audio output list
- [ ] Audio plays through Raspberry Pi when selected
- [ ] HeadUnitApp local music playback still works

### Nice-to-Have 🎯
- [ ] AAC codec working (better quality than SBC)
- [ ] Low latency (<200ms)
- [ ] Automatic audio switching (pause local when BT connects)
- [ ] AVRCP metadata (track title, artist) displayed in HeadUnitApp
- [ ] Volume control synchronized

---

## Timeline Estimate

| Phase | Task | Time | Running Total |
|-------|------|------|---------------|
| 1 | Yocto recipe setup | 30 min | 30 min |
| 2 | System configuration | 20 min | 50 min |
| 3 | Image recipe update | 10 min | 60 min |
| 4 | HeadUnitApp integration | 30 min | 90 min |
| 5 | Build & deploy | 90 min | 180 min (3h) |
| 6 | Testing & validation | 30 min | 210 min (3.5h) |
| - | **Buffer for issues** | 30 min | **240 min (4h)** |

---

## Pre-Migration Checklist

Before starting migration:

- [ ] **Backup current SD card image**
```bash
sudo dd if=/dev/sdX of=~/backup-pulseaudio-$(date +%Y%m%d).img bs=4M status=progress
```

- [ ] **Commit all current Yocto changes**
```bash
cd yocto-workspace/meta-custom
git add -A
git commit -m "Pre-bluealsa migration snapshot"
```

- [ ] **Document current PulseAudio state**
```bash
ssh root@192.168.86.22 "pactl list > /tmp/pulseaudio-state.txt"
scp root@192.168.86.22:/tmp/pulseaudio-state.txt ~/
```

- [ ] **Verify Yocto build environment**
```bash
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake-layers show-layers
```

- [ ] **Ensure enough disk space** (>30GB free)
```bash
df -h /home/seame/DES_Head-Unit/yocto-workspace
```

---

## Next Steps

1. ✅ Review this plan
2. ⏳ Execute Pre-Migration Checklist
3. ⏳ Start Phase 1: Yocto Recipe Setup
4. ⏳ Proceed through phases sequentially
5. ⏳ Document any deviations or issues

---

## References

- [bluez-alsa GitHub](https://github.com/Arkq/bluez-alsa)
- [bluez-alsa Documentation](https://github.com/Arkq/bluez-alsa/wiki)
- [BlueZ A2DP Profile](https://git.kernel.org/pub/scm/bluetooth/bluez.git/tree/doc/media-api.txt)
- [Yocto meta-openembedded bluez-alsa recipe](https://layers.openembedded.org/layerindex/recipe/102030/)

---

**Created**: 2025-11-20
**Author**: Claude Code
**Status**: Ready for Execution
