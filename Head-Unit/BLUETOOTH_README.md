# Bluetooth Audio 통합 가이드

## 빠른 시작 (Linux PC 테스트)

### 1단계: 시스템 설정 (최초 1회)

```bash
cd ~/Head-Unit
sudo ./scripts/setup_bluetooth_pc.sh
```

설정 완료 후 **로그아웃 후 다시 로그인** (또는 재부팅)

### 2단계: PC를 Bluetooth 디스커버블 모드로 설정

```bash
bluetoothctl
```

bluetoothctl 프롬프트에서:
```
power on
agent on
default-agent
discoverable on
pairable on
```

### 3단계: 스마트폰 페어링

1. 스마트폰의 Bluetooth 설정 열기
2. 사용 가능한 기기에서 PC 이름 찾기
3. 페어링 요청 승인

### 4단계: Head-Unit 앱 실행

```bash
cd ~/Head-Unit
./scripts/test_bluetooth.sh
```

또는 수동 빌드 및 실행:
```bash
cmake -S . -B build/Desktop_Qt_6_9_3-Debug \
  -DCMAKE_PREFIX_PATH=/home/seame/Qt/6.9.3/gcc_64
cmake --build build/Desktop_Qt_6_9_3-Debug

./build/Desktop_Qt_6_9_3-Debug/HeadUnitApp
```

### 5단계: 앱에서 연결

1. **Bluetooth** 버튼 클릭
2. Paired Devices에서 스마트폰 선택
3. **Connect** 버튼 클릭

### 6단계: 오디오 테스트

스마트폰에서 음악 재생 → PC 스피커로 출력 확인

## 아키텍처

### D-Bus 기반 AVRCP 구현

```
┌─────────────────────────────────────────┐
│         Qt UI (QML)                     │
│  - MusicScreen (메타데이터 표시)         │
│  - BluetoothScreen (연결 관리)           │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│    Qt C++ Backend                       │
│  ┌─────────────────┬─────────────────┐  │
│  │BluetoothManager │BluetoothAudio   │  │
│  │(페어링, 연결)    │Player(AVRCP)     │  │
│  └────────┬────────┴────────┬────────┘  │
└───────────┼─────────────────┼───────────┘
            │                 │
┌───────────▼─────────────────▼───────────┐
│      BlueZ D-Bus Interface              │
│  org.bluez.Device1 (연결)               │
│  org.bluez.MediaPlayer1 (AVRCP)         │
└───────────┬─────────────────────────────┘
            │
┌───────────▼─────────────────────────────┐
│         BlueZ Daemon                    │
│  A2DP Sink + AVRCP Target               │
└───────────┬─────────────────────────────┘
            │
┌───────────▼─────────────────────────────┐
│      PulseAudio                         │
│  Bluetooth 오디오 라우팅                 │
└─────────────────────────────────────────┘
```

### 주요 컴포넌트

**BluetoothManager** (`bluetooth_manager.h/cpp`)
- QtBluetooth로 페어링 관리
- BlueZ D-Bus로 연결 수행
- BluetoothAudioPlayer와 통합

**BluetoothAudioPlayer** (`bluetooth_audio_player.h/cpp`)
- BlueZ MediaPlayer1 인터페이스 사용
- AVRCP 명령 전송 (Play, Pause, Next, Previous)
- 메타데이터 수신 (제목, 아티스트, 앨범, 시간)
- 앨범 아트 다운로드

## 코드 포터빌리티 (Linux PC ↔ Yocto)

이 구현은 **코드 변경 없이** Linux PC와 Yocto/Raspberry Pi에서 동일하게 작동합니다.

### 공통 요소
- ✅ D-Bus system bus 사용
- ✅ BlueZ 5.x 인터페이스
- ✅ Qt 6 기반
- ✅ PulseAudio/PipeWire 호환

### Yocto 통합

`meta-custom/recipes-des/headunit/headunit.bb`:
```bitbake
DEPENDS += "bluez5"
RDEPENDS:${PN} += "bluez5 pulseaudio-module-bluetooth"

do_install:append() {
    # BlueZ 설정
    install -d ${D}${sysconfdir}/bluetooth
    install -m 0644 ${WORKDIR}/main.conf ${D}${sysconfdir}/bluetooth/
}
```

## 기능 목록

### 현재 구현 ✅
- [x] BlueZ D-Bus 통합
- [x] A2DP 오디오 스트리밍
- [x] AVRCP 메타데이터 (제목, 아티스트, 앨범, 시간)
- [x] AVRCP 재생 제어 (Play, Pause, Next, Previous)
- [x] 실시간 메타데이터 업데이트
- [x] 앨범 아트 (file:// URL 지원)
- [x] 재생 위치 추적
- [x] 연결 상태 관리
- [x] BlueZ 서비스 재시작 감지
- [x] 자동 재연결 로직

### 향후 확장 가능 🔮
- [ ] 여러 디바이스 동시 관리
- [ ] 볼륨 제어 (AVRCP Volume)
- [ ] 플레이리스트 탐색
- [ ] HTTP 앨범 아트 다운로드
- [ ] Bluetooth 디바이스 스캔

## 디버깅

### D-Bus 명령어

**페어링된 디바이스 확인:**
```bash
bluetoothctl paired-devices
```

**디바이스 연결:**
```bash
bluetoothctl connect AA:BB:CC:DD:EE:FF
```

**MediaPlayer 확인:**
```bash
dbus-send --system --print-reply \
  --dest=org.bluez \
  /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF/player0 \
  org.freedesktop.DBus.Properties.GetAll \
  string:"org.bluez.MediaPlayer1"
```

**D-Bus 메시지 모니터링:**
```bash
dbus-monitor --system "interface='org.bluez.MediaPlayer1'"
```

### 로그 확인

**BlueZ 서비스 로그:**
```bash
sudo journalctl -u bluetooth -f
```

**애플리케이션 디버그 출력:**
```
[BluetoothManager] Bluetooth initialized successfully
[BluetoothAudioPlayer] Initialized with D-Bus AVRCP support
[BluetoothManager] Found paired device: My Phone (AA:BB:CC:DD:EE:FF)
[BluetoothManager] Connection initiated successfully
[BluetoothAudioPlayer] Found MediaPlayer at: /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF/player0
[BluetoothAudioPlayer] Metadata updated: Song Title - Artist Name - Album Name
```

## 문제 해결

### "Failed to access device via D-Bus"
→ 디바이스가 페어링되지 않았거나, BlueZ가 디바이스를 관리하지 않음
```bash
bluetoothctl
trust AA:BB:CC:DD:EE:FF
```

### "No MediaPlayer found for device"
→ 스마트폰 음악 앱이 AVRCP를 지원하지 않거나, 아직 시작되지 않음
→ 스마트폰에서 음악 앱 재시작

### 오디오가 PC로 출력되지 않음
```bash
pactl list sinks short | grep bluez
pacmd set-default-sink bluez_sink.AA_BB_CC_DD_EE_FF.a2dp_sink
```

### 메타데이터가 업데이트되지 않음
→ 일부 음악 앱은 AVRCP 메타데이터를 지연 전송
→ 다음 곡으로 넘어가면 업데이트됨

## 추가 문서

- **상세 테스팅 가이드**: `BLUETOOTH_TESTING_GUIDE.md`
- **BlueZ D-Bus API**: https://git.kernel.org/pub/scm/bluetooth/bluez.git/tree/doc
- **Qt D-Bus**: https://doc.qt.io/qt-6/qtdbus-index.html
