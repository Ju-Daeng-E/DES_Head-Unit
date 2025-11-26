# A2DP Sink 테스트 가이드

## 🎯 목표
라즈베리파이가 블루투스 스피커(A2DP Sink)로 동작하여, 스마트폰에서 자동으로 페어링되고 오디오를 재생할 수 있는지 확인합니다.

## 📋 수정 사항 요약

### 1. BlueZ 설정 변경
**파일:** `meta-custom/meta-env/recipes-connectivity/bluez5/files/main.conf`
- **Bluetooth Class:** `0x240408` → `0x240414` (Loudspeaker/Car Audio)
- **프로필 제한:** `Disable=Source` 추가 (오디오 전송 차단, 수신만 허용)

### 2. PulseAudio 최적화
**파일:** `meta-custom/meta-env/recipes-multimedia/pulseaudio/pulseaudio/system.pa.append`
- **자동 프로필 전환:** `module-bluetooth-policy auto_switch=2`
- **모듈 로딩 순서:** bluez5-discover → bluetooth-policy 순서 보장

## 🔨 빌드 방법

### 옵션 1: 빠른 빌드 스크립트 (권장)
```bash
cd /home/seame/DES_Head-Unit
./scripts/rebuild-bluetooth.sh
```

### 옵션 2: 수동 빌드
```bash
cd yocto-workspace
source poky/oe-init-build-env build-des

# BlueZ와 PulseAudio 설정 적용
bitbake -c cleansstate bluez5 pulseaudio

# 전체 이미지 재빌드
bitbake des-image
```

## 💾 SD 카드에 플래시

```bash
# 이미지 위치 확인
cd yocto-workspace/build-des/tmp-glibc/deploy/images/raspberrypi4-64/

# SD 카드 장치명 확인 (예: /dev/sdb)
lsblk

# SD 카드에 쓰기 (주의: 올바른 장치 확인!)
sudo dd if=des-image-raspberrypi4-64.rootfs.wic \
        of=/dev/sdX \
        bs=4M \
        status=progress && sync
```

## 🧪 테스트 절차

### 1단계: 시스템 부팅 및 서비스 확인

라즈베리파이에 SSH 접속 후:

```bash
# PulseAudio 서비스 상태 확인
systemctl status pulseaudio.service

# BlueZ 서비스 상태 확인
systemctl status bluetooth.service

# HeadUnit 앱 상태 확인
systemctl status headunit.service

# 모든 서비스가 active (running) 상태여야 함
```

### 2단계: Bluetooth 설정 확인

```bash
# Bluetooth 어댑터 상태
bluetoothctl show

# 출력에서 확인할 항목:
# - Powered: yes
# - Discoverable: yes
# - Class: 0x240414  ← 중요! Loudspeaker로 인식되는지 확인
# - Pairable: yes
```

### 3단계: PulseAudio 모듈 확인

```bash
# PulseAudio 모듈 로딩 상태
pactl list modules short | grep -E "bluez|bluetooth"

# 다음 모듈들이 로드되어 있어야 함:
# - module-bluez5-discover
# - module-bluetooth-policy
# - module-bluetooth-discover

# PulseAudio Sink 확인
pactl list sinks short

# 출력 예시:
# 0  bt_sink  module-null-sink.c  ...  ← 기본 폴백 싱크
```

### 4단계: 스마트폰에서 페어링

#### 스마트폰 작업:
1. **블루투스 설정** 열기
2. **"SEAME2025"** 장치 검색 (또는 BlueZ main.conf의 Name)
3. 장치 타입이 **"스피커"** 또는 **"오디오 장치"**로 표시되는지 확인
4. **탭하여 페어링** (6자리 숫자 확인 없이 자동 연결되어야 함)
5. 페어링 성공 후, 장치 정보에서 **"미디어 오디오"** 프로필이 활성화되었는지 확인

#### 라즈베리파이에서 로그 모니터링:
```bash
# Terminal 1: BlueZ 로그
journalctl -u bluetooth.service -f

# Terminal 2: PulseAudio 로그
journalctl -u pulseaudio.service -f

# Terminal 3: HeadUnit 앱 로그
journalctl -u headunit.service -f
```

**성공 로그 예시:**
```
# bluetoothd 로그:
Endpoint registered: sender=:1.xx path=/MediaEndpoint/A2DPSink
[CHG] Device XX:XX:XX:XX:XX:XX Connected: yes
[CHG] Device XX:XX:XX:XX:XX:XX ServicesResolved: yes

# HeadUnitApp 로그:
[BluetoothAgent] *** PAIRING REQUEST ***
[BluetoothAgent] ✅ AUTO-ACCEPTING pairing
[BluetoothAgent] ✅ Pairing automatically accepted

# PulseAudio 로그:
Card bluez_card.XX_XX_XX_XX_XX_XX added
Setting profile to a2dp_sink
```

### 5단계: 오디오 재생 테스트

1. 스마트폰에서 **음악 앱**(YouTube, Spotify 등) 실행
2. 오디오 출력 장치 선택
   - Android: 볼륨 버튼 → "SEAME2025" 선택
   - iOS: 제어 센터 → AirPlay → "SEAME2025" 선택
3. 음악 재생 시작

#### 확인 사항:
```bash
# PulseAudio에서 Bluetooth 스트림 확인
pactl list sink-inputs

# 출력에 bluez_sink가 표시되어야 함:
# Sink Input #X
#   application.name = "bluez_sink.XX_XX_XX_XX_XX_XX"
#   media.name = "Bluetooth Stream"
```

**오디오가 들리지 않는 경우:**
```bash
# 1. Sink 볼륨 확인 및 조정
pactl set-sink-volume bt_sink 100%

# 2. Mute 해제
pactl set-sink-mute bt_sink 0

# 3. A2DP Sink 프로필 강제 설정
bluetoothctl
> select XX:XX:XX:XX:XX:XX
> info
# UUID: Audio Sink 항목 확인

# PulseAudio에서 프로필 수동 설정
pactl set-card-profile bluez_card.XX_XX_XX_XX_XX_XX a2dp_sink
```

## ✅ 성공 기준

- [ ] 스마트폰에서 라즈베리파이가 "스피커" 타입으로 표시됨
- [ ] 6자리 숫자 확인 없이 자동 페어링됨
- [ ] 페어링 후 "미디어 오디오" 프로필이 자동 활성화됨
- [ ] 스마트폰 음악 앱에서 라즈베리파이를 오디오 출력 장치로 선택 가능
- [ ] 음악 재생 시 오디오가 라즈베리파이에서 출력됨 (스피커/HDMI)

## 🐛 문제 해결

### 문제 1: 스마트폰에서 여전히 스피커로 인식 안 됨

**원인:** Bluetooth Class가 업데이트되지 않음

**해결:**
```bash
# BlueZ 설정 확인
cat /etc/bluetooth/main.conf | grep Class

# 출력: Class = 0x240414 여야 함
# 다른 값이면 이미지 빌드가 제대로 안 된 것

# BlueZ 재시작으로 설정 재로드
systemctl restart bluetooth.service
```

### 문제 2: 페어링은 되지만 오디오 프로필이 활성화 안 됨

**원인:** PulseAudio 모듈이 제대로 로드되지 않음

**해결:**
```bash
# PulseAudio 설정 확인
cat /etc/pulse/system.pa | grep -A2 bluez

# module-bluez5-discover와 module-bluetooth-policy가 있어야 함

# PulseAudio 재시작
systemctl restart pulseaudio.service

# 모듈 수동 로드 (임시 테스트)
pactl load-module module-bluez5-discover
pactl load-module module-bluetooth-policy auto_switch=2
```

### 문제 3: "Authentication Failure" 오류

**원인:** HeadUnit 앱의 BluetoothAgent가 등록되지 않음

**해결:**
```bash
# HeadUnit 앱 로그 확인
journalctl -u headunit.service | grep BluetoothAgent

# 출력에 "[BluetoothAgent] Agent created" 메시지가 있어야 함

# 없으면 HeadUnit 앱 재시작
systemctl restart headunit.service
```

### 문제 4: PulseAudio가 죽음 (inactive/dead)

**원인:** systemd 서비스가 enable 안 됨

**해결:**
```bash
# PulseAudio 서비스 활성화
systemctl enable pulseaudio.service
systemctl start pulseaudio.service

# 부팅 시 자동 시작 확인
systemctl is-enabled pulseaudio.service
# 출력: enabled
```

## 📊 디버깅 명령어 모음

```bash
# === Bluetooth 상태 ===
bluetoothctl show
bluetoothctl devices
bluetoothctl paired-devices

# === PulseAudio 상태 ===
pactl list modules short
pactl list sinks short
pactl list cards short
pactl info

# === 실시간 로그 모니터링 ===
# 모든 관련 서비스 로그를 한 번에
journalctl -u bluetooth.service -u pulseaudio.service -u headunit.service -f

# === D-Bus 트래픽 모니터링 ===
dbus-monitor --system "interface='org.bluez.Agent1'"
dbus-monitor --system "interface='org.bluez.MediaEndpoint1'"

# === BlueZ 상세 디버깅 모드 ===
# /etc/systemd/system/bluetooth.service.d/override.conf 생성:
# [Service]
# ExecStart=
# ExecStart=/usr/libexec/bluetooth/bluetoothd -d -n
systemctl daemon-reload
systemctl restart bluetooth.service
```

## 📝 참고 자료

- **Bluetooth Class 코드:** https://www.bluetooth.com/specifications/assigned-numbers/
  - 0x240414 = Audio + Rendering / Audio-Video / Loudspeaker
- **BlueZ Agent API:** https://git.kernel.org/pub/scm/bluetooth/bluez.git/tree/doc/agent-api.txt
- **PulseAudio Bluetooth:** https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/Modules/#bluetooth

## 🎉 기대 결과

이미지를 새로 빌드하고 플래시한 후, 스마트폰에서 라즈베리파이를 다음과 같이 인식해야 합니다:

```
장치명: SEAME2025
타입: 🔊 스피커 / 오디오 장치
프로필:
  ✅ 미디어 오디오 (A2DP Sink)
  ❌ 전화 오디오 (비활성화)
상태: 연결됨
```

스마트폰의 모든 오디오(음악, 비디오, 게임 등)가 자동으로 라즈베리파이로 전송되어야 합니다!
