# 컨트롤러 로깅 개선 제안

`piracer-controller` 서비스의 디버깅을 용이하게 하기 위한 로깅 개선 사항입니다.

## 현재 문제점

현재 `controller.py`는 최소한의 로깅만 제공합니다:
- 게임패드 초기화 성공/실패
- 연결 끊김 감지
- 인라인 상태 출력 (stdout, journalctl에서는 보이지 않음)

이로 인해 다음과 같은 문제 발생:
1. 버튼 입력이 감지되는지 알 수 없음
2. SharedMemory 쓰기 성공/실패를 알 수 없음
3. 서비스 로그만으로 문제 진단이 어려움

## 개선된 controller.py

### 1. 상세한 초기화 로깅

**위치:** `controller.py:129-141`

**변경 전:**
```python
def _initialise_gamepad() -> ShanWanGamepad:
    """Block until /dev/input/js0 is available and return an initialised gamepad."""
    while True:
        try:
            gamepad = ShanWanGamepad()
            print_status("initialized gamepad")
            return gamepad
        except FileNotFoundError:
            print_status("waiting for gamepad (/dev/input/js0)")
            time.sleep(2.0)
        except Exception as exc:  # pragma: no cover - hardware errors
            logging.warning("failed to initialise gamepad: %s", exc)
            time.sleep(2.0)
```

**변경 후:**
```python
def _initialise_gamepad() -> ShanWanGamepad:
    """Block until /dev/input/js0 is available and return an initialised gamepad."""
    attempt = 0
    while True:
        attempt += 1
        try:
            gamepad = ShanWanGamepad()
            logging.info("✅ Gamepad initialized successfully on attempt %d", attempt)
            logging.info("   Device: /dev/input/js0")
            logging.info("   Name: %s", getattr(gamepad, 'js_name', 'Unknown'))
            logging.info("   Axes: %d, Buttons: %d",
                        getattr(gamepad, 'num_axes', 0),
                        getattr(gamepad, 'num_buttons', 0))
            return gamepad
        except FileNotFoundError:
            if attempt % 5 == 1:  # Log every 5 attempts to reduce spam
                logging.warning("⏳ Waiting for gamepad device (attempt %d)", attempt)
                logging.warning("   Expected: /dev/input/js0")
                logging.warning("   Hint: Check USB/Bluetooth connection")
            time.sleep(2.0)
        except Exception as exc:  # pragma: no cover - hardware errors
            logging.error("❌ Failed to initialize gamepad (attempt %d): %s", attempt, exc)
            time.sleep(2.0)
```

### 2. 버튼 입력 로깅

**위치:** `controller.py:170-182`

**변경 전:**
```python
# 2. gear selection (button X: parking, button Y: reverse)
if pad_state.button_x:  # button 2
    drive_mode = "parking"
elif pad_state.button_a:
    drive_mode = "drive"
elif pad_state.button_y:  # button 3
    drive_mode = "reverse"
elif pad_state.button_b:
    drive_mode = "neutral"

sharedDriveMode.write_mode(
    SharedDriveMode.MODE_NAMES.get(drive_mode, SharedDriveMode.NEUTRAL)
)
```

**변경 후:**
```python
# 2. gear selection (button X: parking, button Y: reverse)
old_drive_mode = drive_mode
button_pressed = None

if pad_state.button_x:  # button 2
    drive_mode = "parking"
    button_pressed = "X"
elif pad_state.button_a:
    drive_mode = "drive"
    button_pressed = "A"
elif pad_state.button_y:  # button 3
    drive_mode = "reverse"
    button_pressed = "Y"
elif pad_state.button_b:
    drive_mode = "neutral"
    button_pressed = "B"

# Log only when mode changes
if drive_mode != old_drive_mode and button_pressed:
    mode_code = SharedDriveMode.MODE_NAMES.get(drive_mode, SharedDriveMode.NEUTRAL)
    logging.info("🎮 Button %s pressed → Mode: %s (code: %d)",
                 button_pressed, drive_mode.upper(), mode_code)

sharedDriveMode.write_mode(
    SharedDriveMode.MODE_NAMES.get(drive_mode, SharedDriveMode.NEUTRAL)
)
```

### 3. SharedMemory 검증 로깅

**위치:** `SharedDriveMode` 클래스

**변경 전:**
```python
def write_mode(self, mode):
    """Write drive mode to shared memory
    0 = neutral, 1 = drive, 2 = reverse, 3 = parking
    """
    data = struct.pack('i', mode)
    self.shm.buf[:len(data)] = data
```

**변경 후:**
```python
def write_mode(self, mode, log_write=False):
    """Write drive mode to shared memory
    0 = neutral, 1 = drive, 2 = reverse, 3 = parking
    """
    try:
        # Validate mode
        if mode < 0 or mode > 3:
            logging.error("❌ Invalid mode value: %d (expected 0-3)", mode)
            return False

        data = struct.pack('i', mode)
        self.shm.buf[:len(data)] = data

        # Verify write
        verify = struct.unpack('i', self.shm.buf[:SHARED_MEM_SIZE])[0]
        if verify != mode:
            logging.error("❌ SharedMemory write failed: wrote %d but read %d", mode, verify)
            return False

        if log_write:
            logging.debug("✅ SharedMemory updated: mode=%d", mode)

        return True
    except Exception as e:
        logging.error("❌ SharedMemory write exception: %s", e)
        return False
```

### 4. 주기적인 헬스체크

**위치:** `main()` 함수 내

**추가:**
```python
def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

    # initialize Shared Memory early so the IC app can always read a neutral gear
    sharedDriveMode = SharedDriveMode()
    car = PiRacerStandard()

    drive_mode = "neutral"  # can be 'drive', 'reverse', 'neutral', 'parking'
    gamepad = _initialise_gamepad()

    # Health check variables
    loop_count = 0
    last_health_check = time.time()
    HEALTH_CHECK_INTERVAL = 30  # seconds

    try:
        while True:
            loop_count += 1

            # Periodic health check
            current_time = time.time()
            if current_time - last_health_check >= HEALTH_CHECK_INTERVAL:
                current_mode = sharedDriveMode.read_mode()
                logging.info("💓 Health check: loops=%d, current_mode=%s, shm_mode=%d",
                            loop_count, drive_mode, current_mode)
                last_health_check = current_time

            try:
                pad_state = gamepad.read_data()
            except Exception as exc:  # pragma: no cover - hardware errors
                logging.error("❌ Gamepad read failed: %s", exc)
                logging.info("🔄 Attempting to reconnect...")
                time.sleep(1.0)
                gamepad = _initialise_gamepad()
                continue

            # ... rest of the code ...
```

### 5. 로그 레벨 제어

**위치:** 시작 부분

**추가:**
```python
import os

# Get log level from environment variable (default: INFO)
log_level_str = os.environ.get('CONTROLLER_LOG_LEVEL', 'INFO').upper()
log_level = getattr(logging, log_level_str, logging.INFO)

logging.basicConfig(
    level=log_level,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

logging.info("🚀 PiRacer Controller starting...")
logging.info("   Log level: %s", log_level_str)
logging.info("   PID: %d", os.getpid())
```

## systemd 서비스 파일 수정

**파일:** `yocto-workspace/meta-custom/meta-piracer/recipes-support/piracer-controller/files/piracer-controller.service`

**변경 전:**
```ini
[Service]
Type=simple
WorkingDirectory=/usr/lib/piracer-controller
ExecStart=/usr/bin/python3 controller.py
Restart=on-failure
RestartSec=2

StandardOutput=journal
StandardError=journal
```

**변경 후:**
```ini
[Service]
Type=simple
WorkingDirectory=/usr/lib/piracer-controller

# Environment variables for logging
Environment="CONTROLLER_LOG_LEVEL=INFO"
Environment="PYTHONUNBUFFERED=1"

ExecStart=/usr/bin/python3 controller.py
Restart=on-failure
RestartSec=2

# Log to journal with proper formatting
StandardOutput=journal
StandardError=journal
SyslogIdentifier=piracer-controller

# Optional: Log to file for persistent debugging
# StandardOutput=append:/var/log/piracer-controller.log
# StandardError=append:/var/log/piracer-controller.log
```

## 디버그 모드 활성화

### 임시 활성화 (재부팅 시 초기화)

```bash
# 서비스 환경변수 오버라이드
sudo systemctl edit piracer-controller.service

# 아래 내용 추가:
[Service]
Environment="CONTROLLER_LOG_LEVEL=DEBUG"

# 서비스 재시작
sudo systemctl restart piracer-controller.service

# 디버그 로그 확인
journalctl -u piracer-controller.service -f
```

### 영구 활성화

Yocto 레시피 수정:

**파일:** `yocto-workspace/meta-custom/meta-piracer/recipes-support/piracer-controller/piracer-controller.bb`

```bash
# 서비스 파일에 DEBUG 모드 추가
do_install_append() {
    # Debug 버전 서비스 파일 설치 (선택적)
    if [ "${PIRACER_DEBUG}" = "1" ]; then
        sed -i 's/CONTROLLER_LOG_LEVEL=INFO/CONTROLLER_LOG_LEVEL=DEBUG/' \
            ${D}${systemd_unitdir}/system/piracer-controller.service
    fi
}
```

## 전체 개선된 controller.py

<details>
<summary>펼치기</summary>

```python
import time
import multiprocessing as mp
from multiprocessing import shared_memory
import struct
import signal
import sys
import os
import logging

from gamepads import ShanWanGamepad

try:
    from vehicles import PiRacerStandard  # type: ignore
except ImportError:
    try:
        from piracer.vehicles import PiRacerStandard  # type: ignore
    except Exception:
        class PiRacerStandard:
            """Fallback stub when the hardware vehicles module is unavailable."""
            def __init__(self):
                self._warned = False
                logging.warning("vehicles module not found; PiRacer controls are disabled.")

            def _log_disabled(self, action: str, value: float) -> None:
                if not self._warned:
                    logging.warning("Ignoring %s=%.2f (no vehicles backend).", action, value)
                    self._warned = True

            def set_throttle_percent(self, value: float) -> None:
                self._log_disabled("throttle", value)

            def set_steering_percent(self, value: float) -> None:
                self._log_disabled("steering", value)

# setting control values
THROTTLE_MAX = 0.6
SHARED_MEM_SIZE = 4    # bytes: 1 int for drive mode

class SharedDriveMode:
    """Manages shared memory for drive mode between processes"""

    # Drive mode constants
    NEUTRAL = 0
    DRIVE = 1
    REVERSE = 2
    PARKING = 3

    MODE_NAMES = {
        "neutral": NEUTRAL,
        "drive": DRIVE,
        "reverse": REVERSE,
        "parking": PARKING
    }

    def __init__(self, create=True):
        self.shm_name = 'piracer_drive_mode'

        if create:
            try:
                self.shm = shared_memory.SharedMemory(
                    create=True,
                    size=SHARED_MEM_SIZE,
                    name=self.shm_name
                )
                shm_path = f"/dev/shm/{self.shm_name}"
                try:
                    os.chmod(shm_path, 0o666)
                    logging.info("✅ SharedMemory created: %s (mode: 666)", shm_path)
                except FileNotFoundError:
                    logging.warning("⚠️  Could not set permissions on %s", shm_path)
                self.write_mode(self.NEUTRAL)
            except FileExistsError:
                self.shm = shared_memory.SharedMemory(name=self.shm_name)
                logging.info("✅ SharedMemory connected: /dev/shm/%s (existing)", self.shm_name)
        else:
            self.shm = shared_memory.SharedMemory(name=self.shm_name)
            logging.info("✅ SharedMemory connected: /dev/shm/%s", self.shm_name)

    def write_mode(self, mode, log_write=False):
        """Write drive mode to shared memory"""
        try:
            if mode < 0 or mode > 3:
                logging.error("❌ Invalid mode value: %d (expected 0-3)", mode)
                return False

            data = struct.pack('i', mode)
            self.shm.buf[:len(data)] = data

            # Verify write
            verify = struct.unpack('i', self.shm.buf[:SHARED_MEM_SIZE])[0]
            if verify != mode:
                logging.error("❌ SharedMemory write failed: wrote %d but read %d", mode, verify)
                return False

            if log_write:
                logging.debug("✅ SharedMemory updated: mode=%d", mode)

            return True
        except Exception as e:
            logging.error("❌ SharedMemory write exception: %s", e)
            return False

    def read_mode(self):
        """Read drive mode from shared memory"""
        data = struct.unpack('i', self.shm.buf[:SHARED_MEM_SIZE])
        return data[0]

    def get_mode_name(self, mode=None):
        """Get the name of the current or specified mode"""
        if mode is None:
            mode = self.read_mode()
        for name, code in self.MODE_NAMES.items():
            if code == mode:
                return name
        return "unknown"

    def cleanup(self):
        """Clean up shared memory"""
        try:
            self.shm.close()
            self.shm.unlink()
            logging.info("✅ SharedMemory cleaned up")
        except FileNotFoundError:
            pass

def _initialise_gamepad() -> ShanWanGamepad:
    """Block until /dev/input/js0 is available and return an initialised gamepad."""
    attempt = 0
    while True:
        attempt += 1
        try:
            gamepad = ShanWanGamepad()
            logging.info("✅ Gamepad initialized successfully (attempt %d)", attempt)
            logging.info("   Device: /dev/input/js0")
            logging.info("   Name: %s", getattr(gamepad, 'js_name', 'Unknown'))
            logging.info("   Axes: %d, Buttons: %d",
                        getattr(gamepad, 'num_axes', 0),
                        getattr(gamepad, 'num_buttons', 0))
            return gamepad
        except FileNotFoundError:
            if attempt % 5 == 1:
                logging.warning("⏳ Waiting for gamepad device (attempt %d)", attempt)
                logging.warning("   Expected: /dev/input/js0")
            time.sleep(2.0)
        except Exception as exc:
            logging.error("❌ Failed to initialize gamepad (attempt %d): %s", attempt, exc)
            time.sleep(2.0)

def main():
    # Get log level from environment
    log_level_str = os.environ.get('CONTROLLER_LOG_LEVEL', 'INFO').upper()
    log_level = getattr(logging, log_level_str, logging.INFO)

    logging.basicConfig(
        level=log_level,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    logging.info("🚀 PiRacer Controller starting...")
    logging.info("   Log level: %s", log_level_str)
    logging.info("   PID: %d", os.getpid())

    sharedDriveMode = SharedDriveMode()
    car = PiRacerStandard()
    drive_mode = "neutral"
    gamepad = _initialise_gamepad()

    loop_count = 0
    last_health_check = time.time()
    HEALTH_CHECK_INTERVAL = 30

    try:
        while True:
            loop_count += 1

            # Periodic health check
            current_time = time.time()
            if current_time - last_health_check >= HEALTH_CHECK_INTERVAL:
                current_mode = sharedDriveMode.read_mode()
                logging.info("💓 Health: loops=%d, mode=%s, shm=%d",
                            loop_count, drive_mode, current_mode)
                last_health_check = current_time

            try:
                pad_state = gamepad.read_data()
            except Exception as exc:
                logging.error("❌ Gamepad read failed: %s", exc)
                logging.info("🔄 Reconnecting...")
                time.sleep(1.0)
                gamepad = _initialise_gamepad()
                continue

            # 1. steering control
            steering_input = pad_state.analog_stick_left.x
            if steering_input is not None:
                car.set_steering_percent(steering_input)

            # 2. gear selection with logging
            old_drive_mode = drive_mode
            button_pressed = None

            if pad_state.button_x:
                drive_mode = "parking"
                button_pressed = "X"
            elif pad_state.button_a:
                drive_mode = "drive"
                button_pressed = "A"
            elif pad_state.button_y:
                drive_mode = "reverse"
                button_pressed = "Y"
            elif pad_state.button_b:
                drive_mode = "neutral"
                button_pressed = "B"

            # Log mode changes
            if drive_mode != old_drive_mode and button_pressed:
                mode_code = SharedDriveMode.MODE_NAMES.get(drive_mode, SharedDriveMode.NEUTRAL)
                logging.info("🎮 Button %s → Mode: %s (code: %d)",
                           button_pressed, drive_mode.upper(), mode_code)

            sharedDriveMode.write_mode(
                SharedDriveMode.MODE_NAMES.get(drive_mode, SharedDriveMode.NEUTRAL),
                log_write=(drive_mode != old_drive_mode)
            )

            # 3. throttle control
            throttle_input = pad_state.analog_stick_right.y or 0.0

            if throttle_input < 0.0:
                throttle_intensity = throttle_input * THROTTLE_MAX
                stick_direction = "backward"
            elif throttle_input > 0.0:
                throttle_intensity = throttle_input * THROTTLE_MAX
                stick_direction = "forward"
            else:
                throttle_intensity = 0.0
                stick_direction = "neutral"

            # 4. apply throttle and gear logic
            if drive_mode == "drive":
                if stick_direction == "forward":
                    car.set_throttle_percent(throttle_intensity)
                else:
                    car.set_throttle_percent(0.0)
            elif drive_mode == "reverse":
                if stick_direction == "backward":
                    car.set_throttle_percent(-throttle_intensity)
                else:
                    car.set_throttle_percent(0.0)
            else:
                car.set_throttle_percent(0.0)
                if drive_mode == "parking":
                    car.set_steering_percent(0.0)

            # Debug output
            logging.debug("State: steering=%.2f, throttle=%.2f, mode=%s",
                         steering_input or 0.0, throttle_intensity, drive_mode)

    except KeyboardInterrupt:
        logging.info("🛑 Stopped by user")
    finally:
        logging.info("🧹 Cleaning up...")
        try:
            car.set_throttle_percent(0.0)
            car.set_steering_percent(0.0)
        finally:
            sharedDriveMode.cleanup()

if __name__ == "__main__":
    main()
```

</details>

## 적용 방법

### 개발 환경에서 테스트

```bash
# 로컬에서 개선된 버전 테스트
cd /path/to/DES_Head-Unit
cp yocto-workspace/meta-custom/meta-piracer/recipes-support/piracer-controller/files/controller.py \
   controller_original.py.bak

# 개선된 코드 적용
# (위의 전체 코드를 복사하여 controller.py에 붙여넣기)

# 테스트 실행
CONTROLLER_LOG_LEVEL=DEBUG python3 controller.py
```

### Yocto 이미지에 적용

```bash
# 1. 파일 수정
vim yocto-workspace/meta-custom/meta-piracer/recipes-support/piracer-controller/files/controller.py

# 2. 레시피 클린
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake -c cleansstate piracer-controller

# 3. 재빌드
bitbake piracer-controller
bitbake des-image

# 4. SD 카드에 이미지 쓰기 및 배포
```

## 예상 로그 출력

### 정상 작동 시

```
2025-11-25 10:00:00 [INFO] 🚀 PiRacer Controller starting...
2025-11-25 10:00:00 [INFO]    Log level: INFO
2025-11-25 10:00:00 [INFO]    PID: 1234
2025-11-25 10:00:00 [INFO] ✅ SharedMemory created: /dev/shm/piracer_drive_mode (mode: 666)
2025-11-25 10:00:01 [INFO] ✅ Gamepad initialized successfully (attempt 1)
2025-11-25 10:00:01 [INFO]    Device: /dev/input/js0
2025-11-25 10:00:01 [INFO]    Name: ShanWan PC/PS3/Android
2025-11-25 10:00:01 [INFO]    Axes: 5, Buttons: 15
2025-11-25 10:00:05 [INFO] 🎮 Button A → Mode: DRIVE (code: 1)
2025-11-25 10:00:08 [INFO] 🎮 Button B → Mode: NEUTRAL (code: 0)
2025-11-25 10:00:30 [INFO] 💓 Health: loops=3000, mode=neutral, shm=0
```

### 문제 발생 시

```
2025-11-25 10:00:00 [INFO] 🚀 PiRacer Controller starting...
2025-11-25 10:00:00 [WARNING] ⏳ Waiting for gamepad device (attempt 1)
2025-11-25 10:00:00 [WARNING]    Expected: /dev/input/js0
2025-11-25 10:00:10 [WARNING] ⏳ Waiting for gamepad device (attempt 6)
2025-11-25 10:00:10 [WARNING]    Expected: /dev/input/js0
```

## 성능 영향

- **INFO 레벨**: 거의 없음 (mode 변경 시에만 로그)
- **DEBUG 레벨**: 초당 수십 개 로그 (루프마다), 권장하지 않음
- **권장**: 기본 INFO, 문제 발생 시 DEBUG

## 참고

- Emoji는 journalctl에서 올바르게 표시됩니다
- 로그 레벨은 환경변수로 동적 제어 가능
- 헬스체크는 서비스가 정상 실행 중임을 보장
