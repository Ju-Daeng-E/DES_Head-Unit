# 무선 컨트롤러 디버깅 가이드

라즈베리 파이에서 무선 컨트롤러 입력이 작동하지 않을 때 단계별 디버깅 방법입니다.

## 시스템 구조

```
무선 컨트롤러 (Bluetooth/USB)
    ↓
/dev/input/js0 (커널 디바이스)
    ↓
piracer-controller.service (controller.py)
    ↓
SharedMemory: piracer_drive_mode
    ↓
Instrument Cluster (ViewModel)
    ↓
UI 업데이트
```

## 버튼 매핑

- **Button A**: Drive 모드
- **Button B**: Neutral 모드
- **Button X**: Parking 모드
- **Button Y**: Reverse 모드

참조: `yocto-workspace/meta-custom/meta-piracer/recipes-support/piracer-controller/files/controller.py:170-178`

## 단계별 디버깅

### 1단계: 하드웨어 연결 확인

컨트롤러가 라즈베리 파이에 연결되었는지 확인합니다.

```bash
# 입력 디바이스 확인
ls -la /dev/input/js*

# 예상 출력:
# crw-rw---- 1 root input 13, 0 Nov 25 10:00 /dev/input/js0
```

**결과 해석:**
- ✅ `/dev/input/js0` 존재: 컨트롤러가 인식됨 → 2단계로
- ❌ 파일 없음: 컨트롤러가 인식 안됨 → 1-A로

#### 1-A: Bluetooth/USB 연결 확인

**USB 컨트롤러:**
```bash
lsusb
# 게임패드/조이스틱 장치가 보이는지 확인
```

**Bluetooth 컨트롤러:**
```bash
# Bluetooth 서비스 상태
systemctl status bluetooth

# 페어링된 장치 확인
bluetoothctl paired-devices

# 연결된 장치 확인
bluetoothctl info [MAC_ADDRESS]
```

**해결책:**
- USB: 케이블 재연결, 다른 USB 포트 시도
- Bluetooth: 컨트롤러 재페어링
  ```bash
  bluetoothctl
  > scan on
  > pair [MAC_ADDRESS]
  > connect [MAC_ADDRESS]
  > trust [MAC_ADDRESS]
  ```

### 2단계: 커널 이벤트 확인

컨트롤러 입력이 커널 레벨에서 감지되는지 테스트합니다.

#### Option A: jstest 사용

```bash
# jstest 설치 (필요시)
sudo apt-get update
sudo apt-get install joystick

# 조이스틱 테스트
jstest /dev/input/js0
```

**예상 출력:**
```
Driver version is 2.1.0.
Joystick (ShanWan Controller) has 5 axes (X, Y, Z, Rz, Hat0X)
and 15 buttons (BtnA, BtnB, BtnX, BtnY, ...).
Testing ... (interrupt to exit)
Axes:  0:     0  1:     0  2:     0  3:     0  4:     0 Buttons:  0:off  1:off  2:off ...
```

**테스트:** 버튼을 눌러보고 숫자가 변하는지 확인

**결과 해석:**
- ✅ 버튼 누르면 값 변함: 커널 레벨 OK → 3단계로
- ❌ 값이 안 변함: 컨트롤러 하드웨어 문제 → 컨트롤러 교체/재페어링

#### Option B: evtest 사용

```bash
# evtest 설치 (필요시)
sudo apt-get install evtest

# 이벤트 테스트
sudo evtest /dev/input/js0
```

버튼을 눌러서 이벤트가 출력되는지 확인합니다.

### 3단계: piracer-controller 서비스 확인

게임패드 입력을 처리하는 서비스가 실행 중인지 확인합니다.

```bash
# 서비스 상태 확인
systemctl status piracer-controller.service

# 예상 출력:
# ● piracer-controller.service - PiRacer gamepad controller
#    Loaded: loaded (/lib/systemd/system/piracer-controller.service; enabled)
#    Active: active (running) since ...
```

**결과 해석:**
- ✅ `Active: active (running)`: 서비스 실행 중 → 4단계로
- ❌ `Active: inactive` 또는 `failed`: 서비스 문제 → 3-A로

#### 3-A: 서비스 로그 확인

```bash
# 최근 로그 확인
journalctl -u piracer-controller.service -n 50 --no-pager

# 실시간 로그 모니터링
journalctl -u piracer-controller.service -f
```

**주요 로그 메시지:**

| 로그 메시지 | 의미 | 해결 방법 |
|------------|------|-----------|
| `initialized gamepad` | ✅ 정상 초기화 | 문제 없음 |
| `waiting for gamepad (/dev/input/js0)` | ⚠️ 컨트롤러 대기 중 | 1단계로 돌아가서 하드웨어 확인 |
| `gamepad disconnected, retrying...` | ❌ 연결 끊김 | 컨트롤러 재연결 필요 |
| `failed to initialise gamepad` | ❌ 초기화 실패 | 권한 문제 또는 디바이스 파일 손상 |
| `ModuleNotFoundError: No module named 'vehicles'` | ❌ 라이브러리 누락 | Yocto 이미지 재빌드 필요 |

#### 3-B: 서비스 재시작

```bash
# 서비스 재시작
sudo systemctl restart piracer-controller.service

# 상태 확인
systemctl status piracer-controller.service

# 로그 확인
journalctl -u piracer-controller.service -n 20 --no-pager
```

#### 3-C: 권한 확인

```bash
# input 그룹 확인
ls -la /dev/input/js0

# 서비스 실행 사용자 확인
ps aux | grep controller.py

# 필요시 권한 추가 (임시)
sudo chmod 666 /dev/input/js0
```

### 4단계: SharedMemory 확인

컨트롤러 입력이 SharedMemory에 올바르게 기록되는지 확인합니다.

```bash
# SharedMemory 존재 확인
ls -la /dev/shm/piracer_drive_mode

# 예상 출력:
# -rw-rw-rw- 1 root root 4 Nov 25 10:00 /dev/shm/piracer_drive_mode
```

#### 4-A: SharedMemory 값 모니터링

Python 스크립트로 실시간 모니터링:

```bash
# 모니터링 스크립트 작성
cat > /tmp/test_shm.py << 'EOF'
#!/usr/bin/env python3
import struct
import time
from multiprocessing import shared_memory

MODE_NAMES = {0: "Neutral", 1: "Drive", 2: "Reverse", 3: "Parking"}

try:
    shm = shared_memory.SharedMemory(name='piracer_drive_mode')
    print("Connected to SharedMemory. Press Ctrl+C to exit.")
    print("Press controller buttons (A=Drive, B=Neutral, X=Parking, Y=Reverse)")
    print("-" * 60)

    last_mode = None
    while True:
        data = struct.unpack('i', shm.buf[:4])
        mode = data[0]

        if mode != last_mode:
            mode_name = MODE_NAMES.get(mode, f"Unknown({mode})")
            print(f"[{time.strftime('%H:%M:%S')}] Mode changed: {mode_name} (code: {mode})")
            last_mode = mode

        time.sleep(0.1)

except KeyboardInterrupt:
    print("\nMonitoring stopped.")
except Exception as e:
    print(f"Error: {e}")
    print("\nPossible causes:")
    print("- piracer-controller service not running")
    print("- SharedMemory not initialized")
finally:
    try:
        shm.close()
    except:
        pass
EOF

# 스크립트 실행
python3 /tmp/test_shm.py
```

**테스트:** 컨트롤러 버튼을 눌러보고 출력이 변하는지 확인

**결과 해석:**
- ✅ 버튼 누르면 값 변함: SharedMemory OK → 5단계로
- ❌ 값이 안 변함: controller.py 문제 → 3단계 로그 재확인

### 5단계: Instrument Cluster 확인

Instrument Cluster가 SharedMemory를 읽고 UI를 업데이트하는지 확인합니다.

```bash
# Instrument Cluster 서비스 상태
systemctl status instrument-cluster.service

# 로그 확인
journalctl -u instrument-cluster.service -n 50 --no-pager

# 실시간 로그 모니터링
journalctl -u instrument-cluster.service -f
```

**주요 로그 확인:**
- `[IC] ViewModel registered as: ViewModel`: ViewModel 초기화 성공
- `[IC] Setting timer for drivemode`: SharedMemory 폴링 타이머 시작
- `[GearManager] Registered D-Bus interface`: D-Bus 서비스 등록 성공

#### 5-A: D-Bus 통신 확인

```bash
# D-Bus 서비스 확인 (session bus)
busctl --user list | grep com.des.vehicle

# D-Bus 서비스 확인 (system bus)
busctl --system list | grep com.des.vehicle

# 현재 gear 값 읽기
busctl --system call com.des.vehicle /com/des/vehicle/Gear com.des.vehicle.Gear GetGear

# D-Bus 신호 모니터링
dbus-monitor --system "interface='com.des.vehicle.Gear'"
```

**테스트:** 컨트롤러 버튼을 누르고 D-Bus 신호가 발생하는지 확인

## 통합 디버깅 스크립트

모든 단계를 한 번에 확인하는 스크립트:

```bash
cat > /tmp/debug_controller.sh << 'EOF'
#!/bin/bash

echo "============================================"
echo "무선 컨트롤러 디버깅 스크립트"
echo "============================================"
echo

echo "1. 하드웨어 확인"
echo "----------------------------------------"
if [ -e /dev/input/js0 ]; then
    echo "✅ /dev/input/js0 존재"
    ls -la /dev/input/js0
else
    echo "❌ /dev/input/js0 없음 - 컨트롤러 연결 확인 필요"
fi
echo

echo "2. piracer-controller 서비스 상태"
echo "----------------------------------------"
systemctl is-active --quiet piracer-controller.service
if [ $? -eq 0 ]; then
    echo "✅ piracer-controller.service 실행 중"
else
    echo "❌ piracer-controller.service 실행 안됨"
fi
systemctl status piracer-controller.service --no-pager -l
echo

echo "3. SharedMemory 확인"
echo "----------------------------------------"
if [ -e /dev/shm/piracer_drive_mode ]; then
    echo "✅ SharedMemory 존재"
    ls -la /dev/shm/piracer_drive_mode
else
    echo "❌ SharedMemory 없음"
fi
echo

echo "4. Instrument Cluster 서비스 상태"
echo "----------------------------------------"
systemctl is-active --quiet instrument-cluster.service
if [ $? -eq 0 ]; then
    echo "✅ instrument-cluster.service 실행 중"
else
    echo "❌ instrument-cluster.service 실행 안됨"
fi
systemctl status instrument-cluster.service --no-pager -l
echo

echo "5. 최근 로그 (piracer-controller)"
echo "----------------------------------------"
journalctl -u piracer-controller.service -n 10 --no-pager
echo

echo "6. 최근 로그 (instrument-cluster)"
echo "----------------------------------------"
journalctl -u instrument-cluster.service -n 10 --no-pager
echo

echo "============================================"
echo "디버깅 완료"
echo "============================================"
EOF

chmod +x /tmp/debug_controller.sh
bash /tmp/debug_controller.sh
```

## 일반적인 문제와 해결책

### 문제 1: "waiting for gamepad (/dev/input/js0)" 무한 반복

**원인:** 컨트롤러가 연결되지 않음

**해결:**
1. USB 케이블 확인 및 재연결
2. Bluetooth 재페어링
3. `lsusb` / `bluetoothctl` 로 장치 인식 확인

### 문제 2: 서비스는 실행 중인데 버튼이 작동 안함

**원인:**
- 잘못된 컨트롤러 매핑
- 다른 프로세스가 /dev/input/js0 사용 중

**해결:**
```bash
# jstest로 버튼 번호 확인
jstest /dev/input/js0

# /dev/input/js0 사용 중인 프로세스 확인
sudo lsof /dev/input/js0

# 필요시 서비스 재시작
sudo systemctl restart piracer-controller.service
```

### 문제 3: SharedMemory 권한 오류

**원인:** /dev/shm/piracer_drive_mode 권한 문제

**해결:**
```bash
# 권한 확인
ls -la /dev/shm/piracer_drive_mode

# 권한 수정 (임시)
sudo chmod 666 /dev/shm/piracer_drive_mode

# 영구 해결: controller.py:74-76에서 chmod 수행
```

### 문제 4: Bluetooth 컨트롤러 자동 재연결 안됨

**원인:** Bluetooth trust 설정 안됨

**해결:**
```bash
bluetoothctl
> trust [MAC_ADDRESS]
> exit

# 또는 자동 연결 설정
sudo systemctl enable bluetooth
```

## 추가 도구

### 실시간 모니터링 대시보드

```bash
# tmux로 여러 로그를 동시에 모니터링
tmux new-session -d -s debug \; \
  split-window -v \; \
  split-window -h \; \
  select-pane -t 0 \; \
  send-keys 'journalctl -u piracer-controller.service -f' C-m \; \
  select-pane -t 1 \; \
  send-keys 'journalctl -u instrument-cluster.service -f' C-m \; \
  select-pane -t 2 \; \
  send-keys 'python3 /tmp/test_shm.py' C-m \; \
  attach-session

# tmux 세션 종료: Ctrl+B, then type ":kill-session"
```

## 참고 파일 위치

- **컨트롤러 처리:** `yocto-workspace/meta-custom/meta-piracer/recipes-support/piracer-controller/files/controller.py`
- **게임패드 라이브러리:** `yocto-workspace/meta-custom/meta-piracer/recipes-support/piracer-controller/files/gamepads.py`
- **서비스 파일:** `yocto-workspace/meta-custom/meta-piracer/recipes-support/piracer-controller/files/piracer-controller.service`
- **Instrument Cluster:** `DES_Instrument-Cluster/Cluster-app/src/ViewModel.cpp:32-35`
- **GearManager:** `DES_Instrument-Cluster/Cluster-app/src/module/GearManager.cpp`

## 문제 해결 플로우차트

```
컨트롤러 버튼 작동 안함
    ↓
/dev/input/js0 존재? → NO → USB/Bluetooth 연결 확인
    ↓ YES
jstest로 입력 확인? → NO → 컨트롤러 하드웨어 문제
    ↓ YES
piracer-controller 실행 중? → NO → 서비스 시작/로그 확인
    ↓ YES
SharedMemory 값 변경됨? → NO → controller.py 로그 확인
    ↓ YES
Instrument Cluster 실행 중? → NO → 서비스 시작
    ↓ YES
UI 업데이트 안됨? → D-Bus/ViewModel 로그 확인
```

## 긴급 복구

모든 방법이 실패하면 서비스 전체 재시작:

```bash
# 모든 관련 서비스 재시작
sudo systemctl restart piracer-controller.service
sudo systemctl restart instrument-cluster.service
sudo systemctl restart headunit.service

# 로그 확인
journalctl -u piracer-controller.service -u instrument-cluster.service -n 50 --no-pager
```
