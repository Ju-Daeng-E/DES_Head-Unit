# 커널 패닉 수정 - Bluetooth 설정 파일 충돌

## 문제 원인

**증상**: Bluetooth 기능 추가 후 이미지를 빌드하여 라즈베리파이에 부팅하면 커널 패닉 발생

**근본 원인**: `/etc/bluetooth/main.conf` 파일을 잘못된 레시피(headunit.bb)에서 설치하려다 **파일 충돌** 또는 **패키지 의존성 문제** 발생

### 왜 문제가 되었나?

1. **잘못된 파일 소유권**
   - `/etc/bluetooth/main.conf`는 BlueZ (bluetooth 패키지)가 관리해야 하는 설정 파일
   - headunit 레시피에서 설치하면 두 패키지가 같은 파일을 소유 → 충돌

2. **BitBake 패키지 충돌**
   ```
   ERROR: Multiple .bb files are due to be built which each provide /etc/bluetooth/main.conf
   ERROR: This usually means one provides something the other doesn't and should.
   ```

3. **systemd 의존성 문제**
   - bluetooth.service가 잘못된 설정 파일 때문에 시작 실패
   - headunit.service가 bluetooth.service에 의존
   - 부팅 시 서비스 데드락 → 커널 패닉

## 해결 방법

### Yocto Best Practice: .bbappend 사용

BlueZ 패키지 설정을 커스터마이징할 때는 **bluez5.bbappend**를 사용해야 합니다.

### 수정된 파일 구조

```
yocto-workspace/meta-custom/meta-env/recipes-connectivity/bluez5/
├── bluez5_%.bbappend           # ← 새로 생성
└── files/
    └── main.conf               # ← headunit/files/에서 이동
```

### 변경 사항

#### 1. headunit.bb 수정 (제거)

**파일**: `yocto-workspace/meta-custom/meta-app/recipes-des/headunit/headunit.bb`

**변경 전**:
```bitbake
SRC_URI = "file://headunit.service \
           file://rfkill-unblock.service \
           file://headunit-bluetooth.conf \
           file://bluetooth-main.conf \    # ← 제거
"

do_install:append() {
    ...
    install -d ${D}${sysconfdir}/bluetooth                                        # ← 제거
    install -m 0644 ${WORKDIR}/bluetooth-main.conf ${D}${sysconfdir}/bluetooth/main.conf  # ← 제거
}

FILES:${PN} += "\
    ...
    ${sysconfdir}/bluetooth/main.conf \    # ← 제거
"
```

**변경 후**:
```bitbake
SRC_URI = "file://headunit.service \
           file://rfkill-unblock.service \
           file://headunit-bluetooth.conf \
"

do_install:append() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/headunit.service ${D}${systemd_system_unitdir}/headunit.service
    install -m 0644 ${WORKDIR}/rfkill-unblock.service ${D}${systemd_system_unitdir}/rfkill-unblock.service
    install -d ${D}${sysconfdir}/dbus-1/system.d/
    install -m 0644 ${WORKDIR}/headunit-bluetooth.conf ${D}${sysconfdir}/dbus-1/system.d/headunit-bluetooth.conf
}

FILES:${PN} += "\
    ${bindir}/HeadUnitApp \
    ${datadir}/headunit \
    ${systemd_system_unitdir}/headunit.service \
    ${systemd_system_unitdir}/rfkill-unblock.service \
    ${sysconfdir}/dbus-1/system.d/headunit-bluetooth.conf \
"
```

#### 2. bluez5.bbappend 생성 (새로 추가)

**파일**: `yocto-workspace/meta-custom/meta-env/recipes-connectivity/bluez5/bluez5_%.bbappend`

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://main.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/bluetooth
    install -m 0644 ${WORKDIR}/main.conf ${D}${sysconfdir}/bluetooth/main.conf
}

FILES:${PN} += "${sysconfdir}/bluetooth/main.conf"
```

**설명**:
- `FILESEXTRAPATHS:prepend`: 이 디렉토리의 files/ 폴더를 검색 경로에 추가
- `SRC_URI += "file://main.conf"`: BlueZ 패키지 빌드 시 main.conf 포함
- `do_install:append()`: BlueZ 설치 후 main.conf를 /etc/bluetooth/로 설치
- `FILES:${PN}`: bluez5 패키지에 main.conf 파일 소유권 추가

#### 3. main.conf 파일 이동

**이전 위치**:
```
meta-custom/meta-app/recipes-des/headunit/files/bluetooth-main.conf
```

**새 위치**:
```
meta-custom/meta-env/recipes-connectivity/bluez5/files/main.conf
```

**파일 내용** (변경 없음):
```ini
[General]
Name = SEAME2025
Class = 0x240408
DiscoverableTimeout = 0
PairableTimeout = 0

[Policy]
AutoEnable=true

[GATT]
Cache = yes
KeySize = 16

[AVDTP]
SessionMode = basic

[LE]
MinConnectionInterval = 8
MaxConnectionInterval = 12
```

## 빌드 및 배포

### 1. 클린 빌드 (필수)

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des

# 영향받은 패키지 클린
bitbake -c cleanall headunit bluez5

# 전체 이미지 재빌드
bitbake des-image
```

### 2. 이미지 플래싱

```bash
cd build-des/tmp-glibc/deploy/images/raspberrypi4-64

# SD 카드 확인
lsblk

# 플래싱
sudo bzcat des-image-raspberrypi4-64.rootfs.wic.bz2 | sudo dd of=/dev/sdb bs=4M status=progress conv=fsync
sync
```

### 3. 부팅 확인

```bash
# 라즈베리파이 부팅 후 SSH 접속
ssh root@raspberrypi4-64

# Bluetooth 설정 확인
cat /etc/bluetooth/main.conf

# Bluetooth 서비스 상태
systemctl status bluetooth

# BlueZ Class 확인
hciconfig hci0 class
# 출력: Class: 0x240408
```

## 검증

### 성공 기준

1. ✅ **커널 패닉 없이 정상 부팅**
2. ✅ **bluetooth.service 정상 실행**
   ```bash
   systemctl status bluetooth
   # Active: active (running)
   ```
3. ✅ **main.conf 파일이 올바른 패키지에 속함**
   ```bash
   rpm -qf /etc/bluetooth/main.conf  # 또는 dpkg -S
   # 출력: bluez5-5.72-...
   ```
4. ✅ **Bluetooth Class 설정 적용**
   ```bash
   hciconfig hci0 class
   # 출력: Class: 0x240408
   ```
5. ✅ **headunit.service 정상 실행**
   ```bash
   systemctl status headunit
   # Active: active (running)
   ```

### 실패 시 디버깅

#### A. BitBake 빌드 에러

```bash
# 로그 확인
bitbake -c compile headunit 2>&1 | tee headunit-build.log
bitbake -c compile bluez5 2>&1 | tee bluez5-build.log

# 파일 충돌 확인
bitbake -e des-image | grep "main.conf"
```

#### B. 런타임 에러

```bash
# Bluetooth 서비스 로그
journalctl -u bluetooth -n 50

# BlueZ 설정 검증
bluetoothd -n -d  # 포그라운드 디버그 모드

# D-Bus 권한 확인
ls -la /etc/dbus-1/system.d/headunit-bluetooth.conf
```

## Yocto Best Practices

### 패키지 커스터마이징 규칙

1. **원본 패키지 설정 수정**: `.bbappend` 사용
   - 예: bluez5 설정 → `bluez5_%.bbappend`
   - 예: weston 설정 → `weston_%.bbappend`

2. **애플리케이션별 설정**: 애플리케이션 레시피에 포함
   - 예: headunit D-Bus 권한 → `headunit.bb`에서 설치
   - 예: systemd 서비스 파일 → 해당 앱 레시피에서 설치

3. **시스템 전역 설정**: 이미지 레시피 또는 meta-env 레이어
   - 예: 부트 설정 → `rpi-config_%.bbappend`
   - 예: 커널 파라미터 → `rpi-cmdline.bbappend`

### 파일 소유권 규칙

| 파일 | 올바른 레시피 | 잘못된 레시피 |
|------|--------------|--------------|
| `/etc/bluetooth/main.conf` | bluez5.bbappend | headunit.bb ❌ |
| `/etc/dbus-1/system.d/headunit-bluetooth.conf` | headunit.bb | bluez5.bbappend ❌ |
| `/lib/systemd/system/headunit.service` | headunit.bb | des-image.bb ❌ |
| `/usr/bin/HeadUnitApp` | headunit.bb | - |

## 요약

**문제**: headunit.bb에서 `/etc/bluetooth/main.conf` 설치 → 패키지 충돌 → 커널 패닉

**해결**: bluez5.bbappend 생성하여 BlueZ 패키지가 main.conf 소유

**핵심**: Yocto에서는 각 파일이 정확히 하나의 패키지에만 속해야 함

**결과**:
- ✅ 파일 충돌 제거
- ✅ 올바른 패키지 의존성
- ✅ 정상 부팅 및 Bluetooth 동작
