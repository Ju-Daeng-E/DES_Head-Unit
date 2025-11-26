# Bluetooth Audio 테스팅 가이드 (Linux PC)

이 가이드는 Linux PC에서 Bluetooth 오디오 기능을 테스트하는 방법을 설명합니다.
나중에 Yocto/Raspberry Pi로 이식할 때 코드 변경 없이 그대로 사용할 수 있습니다.

## 시스템 요구사항

### 필수 패키지

```bash
# BlueZ (Bluetooth 스택)
sudo apt-get update
sudo apt-get install -y \
    bluez \
    bluez-tools \
    pulseaudio-module-bluetooth \
    pavucontrol

# D-Bus 개발 도구 (디버깅용)
sudo apt-get install -y \
    d-feet \
    dbus-x11
```

### Bluetooth 서비스 확인

```bash
# BlueZ 데몬이 실행 중인지 확인
systemctl status bluetooth

# 실행 중이 아니면 시작
sudo systemctl start bluetooth
sudo systemctl enable bluetooth

# BlueZ 버전 확인 (5.50 이상 권장)
bluetoothctl --version
```

## PC를 Bluetooth Sink로 설정

### 1. PulseAudio Bluetooth 모듈 활성화

PulseAudio 설정 편집:
```bash
nano ~/.config/pulse/default.pa
```

다음 내용 추가 (파일이 없으면 새로 생성):
```
.include /etc/pulse/default.pa

# Bluetooth auto-switching
load-module module-switch-on-connect
```

PulseAudio 재시작:
```bash
pulseaudio -k
pulseaudio --start
```

### 2. BlueZ A2DP Sink 설정

BlueZ 설정 파일 편집:
```bash
sudo nano /etc/bluetooth/main.conf
```

다음 내용으로 수정:
```ini
[General]
# 클래스: Audio/Video (Computer) - 스마트폰이 PC를 오디오 기기로 인식
Class = 0x200420

# 디스커버블 & 페어러블 타임아웃 (0 = 무제한)
DiscoverableTimeout = 0
PairableTimeout = 0

# 자동 활성화
AutoEnable = true

[Policy]
# 이전에 페어링된 디바이스에 자동 재연결
AutoEnable = true
```

BlueZ 재시작:
```bash
sudo systemctl restart bluetooth
```

## 빌드 및 실행

### 1. 프로젝트 빌드

```bash
cd ~/Head-Unit

# 클린 빌드 (권장)
rm -rf build/

# CMake 설정
cmake -S . -B build/Desktop_Qt_6_9_3-Debug \
  -DCMAKE_PREFIX_PATH=/home/seame/Qt/6.9.3/gcc_64

# 빌드
cmake --build build/Desktop_Qt_6_9_3-Debug

# 빌드 성공 확인
ls -la build/Desktop_Qt_6_9_3-Debug/HeadUnitApp
```

### 2. 애플리케이션 실행

```bash
# 현재 사용자가 bluetooth 그룹에 속해 있는지 확인
groups

# bluetooth 그룹에 속해 있지 않으면 추가
sudo usermod -a -G bluetooth $USER
# 로그아웃 후 다시 로그인 필요

# 애플리케이션 실행 (D-Bus 디버깅 활성화)
QT_LOGGING_RULES="qt.bluetooth*=true" \
build/Desktop_Qt_6_9_3-Debug/HeadUnitApp
```

**출력 예시:**
```
[BluetoothManager] Bluetooth initialized successfully
[BluetoothAudioPlayer] Initialized with D-Bus AVRCP support
[BluetoothManager] Audio player integrated
[BluetoothManager] Paired devices updated via D-Bus. Count: 0
```

## 스마트폰 페어링 및 연결

### 1. PC를 디스커버블 모드로 설정

터미널에서 `bluetoothctl` 실행:
```bash
bluetoothctl
[bluetooth]# power on
[bluetooth]# agent on
[bluetooth]# default-agent
[bluetooth]# discoverable on
[bluetooth]# pairable on
```

출력:
```
Changing power on succeeded
Agent registered
Default agent request successful
Changing discoverable on succeeded
Changing pairable on succeeded
```

### 2. 스마트폰에서 페어링

1. 스마트폰의 Bluetooth 설정 열기
2. 사용 가능한 기기 목록에서 PC 이름 찾기 (예: "user-ThinkPad")
3. 기기 선택하여 페어링
4. 페어링 코드가 나타나면 PC와 스마트폰 모두에서 확인

PC 터미널에서 확인:
```
[CHG] Device AA:BB:CC:DD:EE:FF Connected: yes
[CHG] Device AA:BB:CC:DD:EE:FF Paired: yes
```

### 3. Head-Unit 앱에서 연결

1. **HeadUnitApp**에서 **Bluetooth 버튼** 클릭
2. **Paired Devices** 목록에서 스마트폰 선택
3. **Connect** 버튼 클릭

**디버그 출력 예시:**
```
[BluetoothManager] Attempting to connect to AA:BB:CC:DD:EE:FF
[BluetoothManager] D-Bus device path: /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF
[BluetoothManager] Calling Connect() on device: My Phone
[BluetoothManager] Connection initiated successfully
[BluetoothManager] Notifying audio player of connection
[BluetoothAudioPlayer] Device set: My Phone at /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF
[BluetoothAudioPlayer] Discovering MediaPlayer for device: /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF
[BluetoothAudioPlayer] Found MediaPlayer at: /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF/player0
[BluetoothAudioPlayer] MediaPlayer initialized. Status: stopped
```

## 오디오 재생 테스트

### 1. 스마트폰에서 음악 재생

스마트폰의 음악 앱(Spotify, YouTube Music 등)에서 음악 재생

**PC에서 확인:**
```bash
# 오디오 싱크 목록 확인
pactl list sinks short

# Bluetooth 오디오 스트림 확인
pactl list sink-inputs
```

예상 출력:
```
Sink Input #123
    Sink: bluez_sink.AA_BB_CC_DD_EE_FF.a2dp_sink
    Application Name: Bluetooth Audio
    Media Name: Music
```

### 2. Head-Unit UI에서 메타데이터 확인

**MusicScreen**에서 확인:
- 곡 제목
- 아티스트
- 앨범
- 재생 시간 / 전체 시간
- 앨범 아트 (지원하는 경우)

**디버그 출력 예시:**
```
[BluetoothAudioPlayer] Properties changed: ("Track", "Status")
[BluetoothAudioPlayer] Metadata keys: ("Title", "Artist", "Album", "Duration")
[BluetoothAudioPlayer] Metadata updated: Bohemian Rhapsody - Queen - A Night at the Opera
[BluetoothAudioPlayer] Status changed to: playing
```

### 3. 재생 제어 테스트

Head-Unit UI에서 버튼 테스트:
- **Play/Pause**: 재생/일시정지 토글
- **Next**: 다음 곡
- **Previous**: 이전 곡

각 명령이 스마트폰에 전달되어야 함.

## 문제 해결 (Troubleshooting)

### 1. Bluetooth 어댑터가 인식되지 않음

```bash
# Bluetooth 컨트롤러 확인
hciconfig

# 출력이 없으면
sudo hciconfig hci0 up
```

### 2. 페어링은 되지만 연결이 안 됨

```bash
# BlueZ 로그 확인
sudo journalctl -u bluetooth -f

# 디바이스 상태 확인
bluetoothctl
[bluetooth]# info AA:BB:CC:DD:EE:FF
```

**일반적인 문제:**
- `Trusted: no` → `trust AA:BB:CC:DD:EE:FF` 실행
- `Connected: no` → 수동으로 `connect AA:BB:CC:DD:EE:FF` 실행

### 3. 오디오가 PC 스피커로 나오지 않음

```bash
# Bluetooth 싱크가 기본 출력인지 확인
pacmd list-sinks | grep -E 'name:|index:|bluez'

# Bluetooth 싱크를 기본값으로 설정
pacmd set-default-sink bluez_sink.AA_BB_CC_DD_EE_FF.a2dp_sink
```

### 4. MediaPlayer 인터페이스가 발견되지 않음

```bash
# D-Bus에서 MediaPlayer 확인
dbus-send --system --print-reply \
  --dest=org.bluez \
  / \
  org.freedesktop.DBus.ObjectManager.GetManagedObjects \
  | grep -A 5 MediaPlayer
```

**출력이 없으면:**
- 스마트폰 음악 앱을 완전히 종료 후 재시작
- PC에서 Bluetooth 연결 해제 후 재연결
- BlueZ 재시작: `sudo systemctl restart bluetooth`

### 5. 메타데이터가 업데이트되지 않음

```bash
# D-Bus 메시지 모니터링
dbus-monitor --system "interface='org.bluez.MediaPlayer1'" | grep -A 10 PropertiesChanged
```

**출력이 없으면:**
- 스마트폰 음악 앱이 AVRCP를 지원하는지 확인
- 다른 음악 앱으로 테스트 (Spotify, VLC 등)

## D-Bus 명령어 참고

### BlueZ 디바이스 목록 확인

```bash
dbus-send --system --print-reply \
  --dest=org.bluez \
  / \
  org.freedesktop.DBus.ObjectManager.GetManagedObjects \
  | grep -E 'object path|interface "org.bluez.Device1"'
```

### 디바이스 속성 확인

```bash
dbus-send --system --print-reply \
  --dest=org.bluez \
  /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF \
  org.freedesktop.DBus.Properties.GetAll \
  string:"org.bluez.Device1"
```

### MediaPlayer 속성 확인

```bash
dbus-send --system --print-reply \
  --dest=org.bluez \
  /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF/player0 \
  org.freedesktop.DBus.Properties.GetAll \
  string:"org.bluez.MediaPlayer1"
```

### 재생 제어 명령

```bash
# Play
dbus-send --system \
  --dest=org.bluez \
  /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF/player0 \
  org.bluez.MediaPlayer1.Play

# Pause
dbus-send --system \
  --dest=org.bluez \
  /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF/player0 \
  org.bluez.MediaPlayer1.Pause

# Next
dbus-send --system \
  --dest=org.bluez \
  /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF/player0 \
  org.bluez.MediaPlayer1.Next
```

## 성공 기준 체크리스트

완전한 테스트를 위한 체크리스트:

- [ ] **BlueZ 실행 중**: `systemctl status bluetooth` ✅
- [ ] **PC 디스커버블**: 스마트폰에서 PC 검색 가능 ✅
- [ ] **페어링 성공**: `bluetoothctl paired-devices`에 표시 ✅
- [ ] **Head-Unit에 디바이스 표시**: Paired Devices 목록에 나타남 ✅
- [ ] **연결 성공**: `[BluetoothManager] Connection initiated successfully` 로그 ✅
- [ ] **MediaPlayer 발견**: `[BluetoothAudioPlayer] Found MediaPlayer at: ...` 로그 ✅
- [ ] **오디오 재생**: 스마트폰 음악이 PC 스피커로 출력 ✅
- [ ] **메타데이터 표시**: 곡 제목, 아티스트, 앨범 UI에 표시 ✅
- [ ] **재생 제어**: Play, Pause, Next, Previous 버튼 동작 ✅
- [ ] **자동 업데이트**: 곡 변경 시 메타데이터 자동 갱신 ✅

## Yocto로 이식

이 구현은 Linux PC와 Yocto/Raspberry Pi에서 동일하게 작동합니다.

**Yocto에서 필요한 패키지:**
```bitbake
# meta-custom/recipes-des/headunit/headunit.bb
DEPENDS += "bluez5"
RDEPENDS:${PN} += "bluez5 pulseaudio-module-bluetooth"
```

**설정 파일 설치:**
```bitbake
do_install:append() {
    # BlueZ 설정
    install -d ${D}${sysconfdir}/bluetooth
    install -m 0644 ${WORKDIR}/main.conf ${D}${sysconfdir}/bluetooth/
}
```

**코드 변경 없음**: Linux PC에서 테스트한 코드를 그대로 Yocto 이미지에 통합하면 됩니다.

## 추가 리소스

- **BlueZ D-Bus API**: https://git.kernel.org/pub/scm/bluetooth/bluez.git/tree/doc
- **Qt D-Bus 가이드**: https://doc.qt.io/qt-6/qtdbus-index.html
- **AVRCP 스펙**: https://www.bluetooth.com/specifications/specs/avrcp/
