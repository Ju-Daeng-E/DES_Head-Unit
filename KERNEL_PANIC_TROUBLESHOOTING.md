# 커널 패닉 트러블슈팅 가이드

## 현재 상황

Bluetooth 기능 추가 후 이미지를 빌드하여 플래싱하면 커널 패닉 발생

## loop4 디바이스에 대해

```
loop4         7:5    0   1,5G  0 loop
├─loop4p1   259:5    0   130M  0 part /media/seame/boot
└─loop4p2   259:6    0   1,4G  0 part /media/seame/root
```

**이것은 문제가 아닙니다!**
- Yocto 빌드 시스템이 생성한 .wic 이미지 파일을 검증하기 위해 loop 디바이스로 마운트한 것
- 실제 SD 카드는 `sda` (119.1G USB 장치)
- loop4는 빌드 아티팩트를 확인용으로 마운트한 것일 뿐

## SD 카드 파티션 이름에 대해

```
sda1        8:1    1   130M  0 part /media/seame/boot1
```

**boot1이라는 이름도 문제가 아닙니다!**
- 볼륨 레이블(label)일 뿐, 파티션 기능에는 영향 없음
- 중요한 것은 파티션 내용, 이름이 아님

## 커널 패닉의 실제 원인

### 1. systemd 서비스 의존성 문제

**증상**: 부팅 중 서비스가 서로를 기다리다 타임아웃

**원인**:
- `bluetooth-class-fix.service`가 `Requires=bluetooth.service` 설정
- bluetooth.service 실패 시 bluetooth-class-fix도 실패
- 다른 서비스가 이들에 의존하면 부팅 중단

**해결**: `Requires` → `Wants`로 변경 (이미 적용됨)

### 2. BitBake 빌드 캐시 문제

**증상**: 레시피 수정했는데 이전 버전이 패키징됨

**원인**:
- Yocto의 shared-state 캐시가 변경을 감지하지 못함
- 특히 .bbappend 파일 추가 시 발생

**해결**: `bitbake -c cleanall <패키지>`

### 3. 파일 충돌

**증상**: 빌드는 성공하지만 부팅 시 파일 시스템 오류

**원인**:
- 두 개 이상의 패키지가 같은 파일 설치 시도
- 예: headunit.bb와 bluez5 둘 다 `/etc/bluetooth/main.conf` 설치

**해결**: 파일 소유권을 하나의 패키지로 명확히 (bluez5.bbappend로 이동)

## 현재 적용된 수정

### ✅ 완료된 작업

1. **headunit.bb에서 bluetooth-main.conf 제거**
   - 파일 충돌 제거
   - bluez5.bbappend로 이동

2. **bluez5.bbappend 생성**
   - `/etc/bluetooth/main.conf` 올바른 패키지에서 설치
   - Class = 0x240408 설정

3. **bluetooth-class-fix.service 임시 비활성화**
   - systemd 의존성 문제 제거
   - 안정성 우선

### 🔄 현재 전략

**Phase 1: 안정화 (현재)**
- bluetooth-class-fix.service 없이 빌드
- bluez5 main.conf만으로 Class 설정 시도
- 부팅 성공 여부 확인

**Phase 2: 기능 테스트**
- 부팅 후 `hciconfig hci0 class` 확인
- Class가 0x200408이면 수동으로 `hciconfig hci0 class 0x240408` 실행
- 음악 제어 가능 여부 확인

**Phase 3: 영구 해결 (필요시)**
- 부팅 + 수동 설정으로 동작 확인되면
- bluetooth-class-fix.service 재활성화
- 또는 다른 방법 (rc.local, udev rule 등)

## 완전 클린 빌드 절차

### 방법 1: 스크립트 사용 (권장)

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
chmod +x clean-build-bluetooth.sh
./clean-build-bluetooth.sh
```

### 방법 2: 수동 빌드

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des

# 1. 완전 클린
bitbake -c cleanall headunit
bitbake -c cleanall bluez5

# 2. (선택) sstate 캐시 삭제
rm -rf tmp-glibc/sstate-control/*headunit*
rm -rf tmp-glibc/sstate-control/*bluez5*

# 3. 빌드
bitbake des-image
```

### 방법 3: 핵폭탄 (최후의 수단)

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des

# tmp 디렉토리 완전 삭제 (모든 빌드 아티팩트)
rm -rf tmp-glibc/

# 처음부터 재빌드 (1-2시간 소요)
bitbake des-image
```

## 빌드 로그 확인

### 빌드 중 오류 확인

```bash
# 실시간 빌드 로그
bitbake des-image 2>&1 | tee build.log

# 특정 패키지 빌드 로그
bitbake -c compile headunit 2>&1 | tee headunit-compile.log
bitbake -c compile bluez5 2>&1 | tee bluez5-compile.log
```

### 빌드 후 로그 확인

```bash
# headunit 빌드 로그
less tmp-glibc/work/cortexa72-poky-linux/headunit/*/temp/log.do_compile

# bluez5 빌드 로그
less tmp-glibc/work/cortexa72-poky-linux/bluez5/*/temp/log.do_compile

# 이미지 빌드 로그
less tmp-glibc/work/raspberrypi4_64-poky-linux/des-image/*/temp/log.do_rootfs
```

### 파일 충돌 확인

```bash
# 패키지가 설치하는 파일 확인
bitbake -e headunit | grep "^FILES:"
bitbake -e bluez5 | grep "^FILES:"

# 특정 파일이 어느 패키지에 속하는지 확인
grep -r "main.conf" tmp-glibc/work/*/headunit/*/package/
grep -r "main.conf" tmp-glibc/work/*/bluez5/*/package/
```

## 플래싱 후 검증

### 1. 부팅 성공 확인

```bash
# Serial console 연결 (USB-TTL 케이블)
screen /dev/ttyUSB0 115200

# 또는 SSH (네트워크 연결 시)
ssh root@raspberrypi4-64
```

### 2. 서비스 상태 확인

```bash
# Bluetooth 서비스
systemctl status bluetooth

# Head-Unit 서비스
systemctl status headunit

# 모든 실패한 서비스 확인
systemctl --failed
```

### 3. Bluetooth 설정 확인

```bash
# main.conf 존재 여부
ls -la /etc/bluetooth/main.conf
cat /etc/bluetooth/main.conf

# Class 확인
hciconfig hci0 class

# BlueZ 버전
bluetoothd --version
```

### 4. 로그 확인

```bash
# 부팅 로그
journalctl -b

# Bluetooth 로그
journalctl -u bluetooth -n 50

# Head-Unit 로그
journalctl -u headunit -n 50

# 커널 로그
dmesg | grep -i bluetooth
```

## 커널 패닉 발생 시 대처

### Serial Console 로그 수집

1. **USB-TTL 케이블 연결**
   - GND → Pin 6 (Ground)
   - TX → Pin 8 (GPIO14 TXD)
   - RX → Pin 10 (GPIO15 RXD)

2. **Serial 모니터링**
   ```bash
   screen /dev/ttyUSB0 115200
   # 또는
   minicom -D /dev/ttyUSB0 -b 115200
   ```

3. **커널 패닉 메시지 캡처**
   - 라즈베리파이 부팅
   - 패닉 발생 시 화면 출력 복사
   - 특히 "Kernel panic" 이후 줄들

### 패닉 로그 분석

**찾아야 할 내용**:
- `Kernel panic - not syncing: ...`
- `CPU: ... PID: ... Comm: ...`
- `Call trace:` 섹션
- `systemd` 관련 에러 메시지

**일반적인 원인**:
- systemd가 critical 서비스를 시작하지 못함
- 파일 시스템 손상
- 필수 라이브러리 누락
- 서비스 의존성 루프

## 현재 빌드 상태

### 활성화된 기능

- ✅ Bluetooth 페어링 (NoInputNoOutput)
- ✅ D-Bus 권한 (headunit-bluetooth.conf)
- ✅ BlueZ Class 설정 (main.conf via bluez5.bbappend)

### 비활성화된 기능 (안정성 우선)

- ❌ bluetooth-class-fix.service (systemd runtime class 설정)

### 예상 동작

1. **부팅**: 정상적으로 부팅되어야 함
2. **Bluetooth**: 페어링 및 연결 가능
3. **Class**: 0x200408 또는 0x240408 (확인 필요)
4. **음악 제어**: Class에 따라 동작 여부 결정

### Class가 0x200408인 경우 대처

```bash
# 수동으로 설정
sudo hciconfig hci0 class 0x240408

# 음악 재생 테스트
# 동작하면 bluetooth-class-fix.service 재활성화 고려
```

## 다음 단계

1. **완전 클린 빌드**
   ```bash
   ./clean-build-bluetooth.sh
   ```

2. **SD 카드 플래싱**
   ```bash
   cd build-des/tmp-glibc/deploy/images/raspberrypi4-64
   sudo bzcat des-image-raspberrypi4-64.rootfs.wic.bz2 | sudo dd of=/dev/sdb bs=4M status=progress conv=fsync
   sync
   ```

3. **부팅 테스트**
   - Serial console 또는 SSH로 접속
   - 서비스 상태 확인
   - Bluetooth Class 확인

4. **기능 테스트**
   - Bluetooth 페어링
   - 음악 재생
   - 미디어 제어

5. **결과에 따라**
   - Class 0x240408 + 음악 제어 성공 → 완료! 🎉
   - Class 0x200408 → bluetooth-class-fix.service 재활성화

## 참고 문서

- `KERNEL_PANIC_FIX.md` - Bluetooth 설정 파일 충돌 해결
- `BLUETOOTH_CLASS_FIX.md` - Class 0x240408 설정 방법
- `BLUETOOTH_DEPLOYMENT.md` - Bluetooth 기능 배포 가이드
- `KERNEL_PANIC_ROOT_CAUSE_ANALYSIS.md` - 이전 커널 패닉 분석
