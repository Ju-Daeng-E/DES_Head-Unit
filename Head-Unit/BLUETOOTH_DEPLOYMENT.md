# Bluetooth 기능 Yocto 배포 가이드

## 변경 사항 요약

### 1. Bluetooth 페어링 개선
- **Agent Capability**: `NoInputNoOutput` 모드로 변경 → 자동 페어링 (6자리 PIN 없이)
- **위치**: `src/backend/bluetooth/bluetooth_manager.cpp:416`

### 2. AVRCP 미디어 제어 활성화
- **BlueZ 설정**: Bluetooth Class를 `0x240408` (Audio/Video Device)로 설정
- **파일**: `yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/bluetooth-main.conf`

### 3. D-Bus 권한 설정
- **파일**: `yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/headunit-bluetooth.conf`
- **용도**: Head-Unit이 BlueZ Agent를 등록하고 Bluetooth 장치와 통신할 수 있도록 허용

### 4. 글로벌 페어링 다이얼로그
- **위치**: `ui/main.qml`
- **기능**: 모든 화면에서 페어링 다이얼로그 표시 (z: 10000)

### 5. 에러 표시 개선
- **위치**: `ui/pages/BluetoothScreen.qml`
- **기능**: 에러 토스트 메시지 및 시스템 상태 패널

## Yocto 빌드 프로세스

### 1. 빌드 환경 준비

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des
```

### 2. 깨끗한 빌드 (권장)

```bash
# Head-Unit 레시피만 클린
bitbake -c cleanall headunit

# 전체 이미지 빌드
bitbake des-image
```

### 3. 증분 빌드 (소스 코드만 변경된 경우)

```bash
# Head-Unit 레시피만 리빌드
bitbake -c compile headunit
bitbake headunit

# 전체 이미지 빌드
bitbake des-image
```

### 4. 빌드 아티팩트 확인

```bash
ls -lh build-des/tmp-glibc/deploy/images/raspberrypi4-64/des-image-raspberrypi4-64.rootfs.wic.bz2
```

## Raspberry Pi 배포

### 방법 1: SD 카드에 직접 플래싱 (권장)

```bash
# SD 카드 디바이스 확인 (예: /dev/sdb)
lsblk

# SD 카드 언마운트
sudo umount /dev/sdb*

# 이미지 플래싱
cd build-des/tmp-glibc/deploy/images/raspberrypi4-64
sudo bzcat des-image-raspberrypi4-64.rootfs.wic.bz2 | sudo dd of=/dev/sdb bs=4M status=progress conv=fsync

# 동기화
sync
```

### 방법 2: 기존 시스템에서 업데이트

라즈베리파이가 네트워크에 연결되어 있는 경우:

```bash
# HeadUnitApp 바이너리만 복사
scp build-des/tmp-glibc/work/cortexa72-poky-linux/headunit/0.1.0-r0/image/usr/bin/HeadUnitApp root@raspberrypi4-64:/usr/bin/

# Bluetooth 설정 복사
scp yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/bluetooth-main.conf root@raspberrypi4-64:/etc/bluetooth/main.conf

# D-Bus 권한 복사
scp yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/headunit-bluetooth.conf root@raspberrypi4-64:/etc/dbus-1/system.d/

# 서비스 재시작
ssh root@raspberrypi4-64 "systemctl restart bluetooth && systemctl restart headunit"
```

## 배포 후 검증

### 1. 라즈베리파이 부팅 후 확인

```bash
# SSH 접속
ssh root@raspberrypi4-64

# Bluetooth 서비스 상태 확인
systemctl status bluetooth

# Head-Unit 서비스 상태 확인
systemctl status headunit

# Bluetooth 설정 확인
grep "Class" /etc/bluetooth/main.conf
# 출력: Class = 0x240408

# D-Bus 권한 확인
ls -l /etc/dbus-1/system.d/headunit-bluetooth.conf
```

### 2. Bluetooth 페어링 테스트

1. Head-Unit 앱에서 Bluetooth 설정으로 이동
2. "Start Broadcasting" 버튼 클릭
3. iPhone/Android에서 "SEAME2025" 검색
4. 장치 이름 탭 → **자동으로 페어링됨 (6자리 PIN 없이)**
5. 페어링 완료 후 "Connect" 버튼으로 연결

### 3. 미디어 제어 테스트

1. iPhone/Android에서 음악 앱 실행
2. 아무 노래나 재생
3. Head-Unit의 Music 화면으로 이동
4. **자동으로 Bluetooth 모드로 전환됨**
5. Play/Pause, Next, Previous 버튼 테스트
6. 트랙 정보 (제목, 아티스트, 앨범) 표시 확인

### 4. 로그 확인

```bash
# Head-Unit 로그 확인
journalctl -u headunit -f

# Bluetooth 로그 확인
journalctl -u bluetooth -f

# D-Bus 메시지 모니터링
dbus-monitor --system "interface='org.bluez.MediaPlayer1'"
```

## 문제 해결

### Bluetooth 페어링 실패

```bash
# Bluetooth 서비스 재시작
systemctl restart bluetooth

# 기존 페어링 삭제
bluetoothctl remove <DEVICE_MAC_ADDRESS>

# Bluetooth 어댑터 확인
bluetoothctl show
```

### MediaPlayer 인터페이스 없음

```bash
# BlueZ 설정 확인
grep "Class" /etc/bluetooth/main.conf

# 설정이 잘못된 경우
echo "Class = 0x240408" | sudo tee -a /etc/bluetooth/main.conf
systemctl restart bluetooth
```

### D-Bus 권한 문제

```bash
# D-Bus 권한 파일 확인
cat /etc/dbus-1/system.d/headunit-bluetooth.conf

# D-Bus 재로드
systemctl reload dbus
systemctl restart headunit
```

### 앱이 시작하지 않음

```bash
# 로그 확인
journalctl -u headunit -n 100

# 수동 실행 테스트
/usr/bin/HeadUnitApp

# Qt 라이브러리 확인
ldd /usr/bin/HeadUnitApp | grep "not found"
```

## 주요 파일 위치

### 소스 코드
- `Head-Unit/src/backend/bluetooth/bluetooth_manager.cpp` - Bluetooth 관리 및 Agent 등록
- `Head-Unit/src/backend/bluetooth/bluetooth_agent.cpp` - BlueZ Agent 구현
- `Head-Unit/src/backend/bluetooth/bluetooth_audio_player.cpp` - AVRCP 미디어 제어
- `Head-Unit/ui/main.qml` - 글로벌 페어링 다이얼로그
- `Head-Unit/ui/pages/BluetoothScreen.qml` - Bluetooth 설정 UI

### Yocto 레시피
- `yocto-workspace/meta-custom/meta-app/recipes-des/headunit/headunit.bb` - 메인 레시피
- `yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/bluetooth-main.conf` - BlueZ 설정
- `yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/headunit-bluetooth.conf` - D-Bus 권한
- `yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/headunit.service` - systemd 서비스

### 라즈베리파이 (배포 후)
- `/usr/bin/HeadUnitApp` - 앱 바이너리
- `/etc/bluetooth/main.conf` - BlueZ 설정
- `/etc/dbus-1/system.d/headunit-bluetooth.conf` - D-Bus 권한
- `/lib/systemd/system/headunit.service` - systemd 서비스

## 참고사항

### NoInputNoOutput 모드
- 6자리 PIN 확인 없이 자동으로 페어링
- 보안 수준은 낮지만 사용자 편의성 향상
- 자동차 환경에서 일반적으로 사용되는 방식

### Bluetooth Class 0x240408
- **0x24**: Audio/Video (메이저 클래스)
- **0x04**: Audio (마이너 클래스)
- **0x08**: Rendering (서비스 클래스)
- 이 설정으로 MediaPlayer1 인터페이스가 자동 생성됨

### AVRCP (Audio/Video Remote Control Profile)
- Bluetooth로 미디어 제어를 가능하게 하는 프로토콜
- MediaControl1: 연결 관리
- MediaPlayer1: 재생 제어 및 메타데이터
