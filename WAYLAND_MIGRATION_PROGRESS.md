# Wayland 마이그레이션 진행 상황

**날짜**: 2025-11-12
**목표**: Qt EGLFS → Wayland/Weston으로 마이그레이션하여 듀얼 디스플레이 문제 해결

---

## 초기 문제 상황

### 증상
- 첫 번째 모니터: HeadUnit 정상 표시 (폰트 문제 있음)
- 두 번째 모니터: Instrument Cluster 미실행, 터미널 화면만 표시
- 원인: Qt EGLFS는 여러 프로세스가 각각 다른 DRM 출력을 클레임할 수 없음

### 환경
- Raspberry Pi 4 (64-bit)
- Dual HDMI Display (1024x600 각각)
- Qt 6.9+ 애플리케이션 2개 (HeadUnit, Instrument Cluster)
- 이전 설정: Qt EGLFS (Direct DRM/KMS)

---

## 아키텍처 변경 결정

### EGLFS 방식의 근본적 문제
```
문제: Qt EGLFS는 단일 프로세스만 DRM 소유 가능
HeadUnit (PID 401) → /dev/dri/card0 점유, HDMI-A-1 + HDMI-A-2 초기화
IC (PID 460) → DRM 접근 불가, "Permission denied" 에러 무한 반복
```

### 선택한 해결책: Wayland/Weston
```
새 아키텍처:
Weston (compositor) → /dev/dri/card0 소유, 양쪽 HDMI 제어
├─ HeadUnit (Wayland client) → HDMI-A-1 (app-ids 매칭)
└─ IC (Wayland client) → HDMI-A-2 (app-ids 매칭)
```

---

## 변경 파일 목록

### 1. Qt 빌드 설정

**파일**: `/home/seame/DES_Head-Unit/yocto-workspace/build-des/conf/local.conf`

```bash
# 변경 전 (EGLFS)
PACKAGECONFIG:append:pn-qtbase = " eglfs kms gbm gles2"
DISTRO_FEATURES:remove = " x11"

# 변경 후 (Wayland)
PACKAGECONFIG:append:pn-qtbase = " wayland gles2 kms gbm"
DISTRO_FEATURES:append = " wayland"
DISTRO_FEATURES:remove = " x11"
```

**목적**: Qt를 Wayland 지원으로 빌드, EGLFS 제거

---

### 2. 이미지 패키지 설정

**파일**: `/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-env/recipes-core/images/des-image.bb`

**변경 내용**:
```python
IMAGE_INSTALL:append = " \
    qtbase qtbase-plugins qtdeclarative qtmultimedia qtwayland \
    wayland weston weston-init weston-examples \
    ...
"
```

**추가된 패키지**: `qtwayland`, `wayland`, `weston`, `weston-init`

---

### 3. Weston Compositor 설정

#### A. weston.ini

**파일**: `/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston.ini`

```ini
[core]
require-input=false
idle-time=0
backend=drm-backend.so
shell=kiosk-shell.so

# HDMI-A-1: First HDMI output (Head-Unit)
[output]
name=HDMI-A-1
mode=1024x600@60
transform=normal
scale=1
app-ids=HeadUnitApp

# HDMI-A-2: Second HDMI output (Instrument Cluster)
[output]
name=HDMI-A-2
mode=1024x600@60
transform=normal
scale=1
app-ids=appIC

[shell]
panel-position=none
background-color=0xff000000
locking=false
cursor-theme=default
cursor-size=1

[kiosk-shell]
```

**핵심**: `app-ids` 설정으로 각 앱을 특정 출력에 할당

#### B. weston.service (커스텀)

**파일**: `/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service`

```ini
[Unit]
Description=Weston Wayland Compositor (Root Mode)
After=multi-user.target dbus.socket

[Service]
Type=simple
Environment=XDG_RUNTIME_DIR=/run
Environment=WAYLAND_DISPLAY=wayland-0
ExecStart=/usr/bin/weston --backend=drm-backend.so --config=/etc/xdg/weston/weston.ini
Restart=on-failure
RestartSec=5
User=root
Group=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
```

**중요 변경점**:
- `User=root` (원본은 User=weston)
- `XDG_RUNTIME_DIR=/run` (모든 서비스에서 동일하게 설정)
- `Type=simple` (원본은 Type=notify)
- TTY 관련 설정 제거

**이유**: D-Bus policy가 root만 com.des.vehicle 서비스 소유 허용, XDG_RUNTIME_DIR 일치 필요

#### C. weston-init.bbappend

**파일**: `/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init.bbappend`

```python
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://weston.ini \
            file://systemd/weston.service \
"

do_install:append() {
    install -D -m 0644 ${WORKDIR}/weston.ini ${D}${sysconfdir}/xdg/weston/weston.ini
    install -D -m 0644 ${WORKDIR}/systemd/weston.service ${D}${systemd_system_unitdir}/weston.service
}
```

**목적**: 커스텀 weston.ini와 weston.service 설치

---

### 4. HeadUnit 애플리케이션

#### A. 소스 코드 수정

**파일**: `/home/seame/DES_Head-Unit/Head-Unit/src/main.cpp`

```cpp
// 변경 전
qputenv("QT_QPA_PLATFORM", "xcb"); // Force X11 backend instead of Wayland

// 변경 후
// Platform backend (xcb/wayland/eglfs) is controlled by systemd Environment= settings
```

**이유**: 하드코딩된 xcb가 systemd 환경변수(QT_QPA_PLATFORM=wayland) 무시

#### B. Yocto 레시피

**파일**: `/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-app/recipes-des/headunit/headunit.bb`

**변경 내용**:
```python
# DEPENDS 추가
DEPENDS = "\
    qtbase \
    qtdeclarative \
    qtdeclarative-native \
    qtmultimedia \
    qtwayland \          # 추가
    qtwayland-native \   # 추가
    qtshadertools-native \
    qtconnectivity \
    qt5compat \
    bluez5 \
    pulseaudio \
    wayland \            # 추가
"

# RDEPENDS 추가
RDEPENDS:${PN} = "\
    qtbase \
    qtwayland \          # 추가
    qtdeclarative-plugins \
    qtdeclarative-qmlplugins \
    qtmultimedia \
    qtconnectivity \
    qt5compat \
    bluez5 \
    pulseaudio \
    weston \             # 추가
"

# SRC_URI에서 KMS 설정 제거
SRC_URI = "file://headunit.service \
"
# file://kms-config/headunit-kms.json 제거됨

# do_install:append()에서 KMS 설치 제거
# FILES:${PN}에서 cluster-kms.json 제거
```

#### C. systemd 서비스

**파일**: `/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/headunit.service`

```ini
[Unit]
Description=Head Unit (Qt Quick) - Wayland Client
After=multi-user.target weston.service
Requires=weston.service

[Service]
Type=simple
ExecStartPre=/bin/sleep 2
Environment=QT_QPA_PLATFORM=wayland
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run
Environment=QT_QPA_FONTDIR=/usr/share/fonts
Environment=QT_LOGGING_RULES=qt.qpa.*=true;qt.waylandclient.*=true
Environment=LANG=C.UTF-8
Environment=LC_ALL=C.UTF-8
ExecStart=/usr/bin/HeadUnitApp
Restart=on-failure
RestartSec=5
User=root
Group=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
```

**주요 변경**:
- `QT_QPA_PLATFORM=eglfs` → `wayland`
- `QT_QPA_EGLFS_*` 환경변수 모두 제거
- `XDG_RUNTIME_DIR=/run/user/0` → `/run`
- `After=weston.service`, `Requires=weston.service` 추가
- `ExecStartPre=/bin/sleep 2` 추가 (Weston 초기화 대기)

---

### 5. Instrument Cluster 애플리케이션

#### A. Yocto 레시피

**파일**: `/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-app/recipes-des/instrument-cluster/instrument-cluster.bb`

**변경 내용**: HeadUnit과 동일한 패턴
- DEPENDS에 `qtwayland`, `qtwayland-native`, `wayland` 추가
- RDEPENDS에 `qtwayland`, `weston` 추가
- SRC_URI에서 KMS 설정 제거
- do_install:append()에서 KMS 설치 제거
- FILES:${PN}에서 cluster-kms.json 제거

#### B. systemd 서비스

**파일**: `/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-app/recipes-des/instrument-cluster/files/instrument-cluster.service`

```ini
[Unit]
Description=Instrument Cluster Application - Wayland Client
After=multi-user.target weston.service headunit.service
Requires=weston.service

[Service]
Type=simple
ExecStartPre=/bin/sleep 3
Environment=QT_QPA_PLATFORM=wayland
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run
Environment=QT_QPA_FONTDIR=/usr/share/fonts
Environment=QT_LOGGING_RULES=qt.qpa.*=true;qt.waylandclient.*=true
Environment=LANG=C.UTF-8
Environment=LC_ALL=C.UTF-8
ExecStart=/usr/bin/appIC
Restart=on-failure
RestartSec=5
User=root
Group=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
```

**차이점**:
- `After=... headunit.service` 추가 (순서 보장)
- `ExecStartPre=/bin/sleep 3` (HeadUnit보다 1초 더 대기)

---

## 빌드 과정

### 첫 번째 빌드 (커널 패닉)

**명령어**:
```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des
bitbake des-image
```

**결과**: 커널 패닉 발생

**원인 분석**:
- HeadUnit의 main.cpp에서 xcb 강제 사용
- local.conf가 EGLFS 설정 유지
- Wayland 패키지는 추가했지만 Qt는 여전히 EGLFS용으로 빌드됨
- systemd 서비스와 Qt 빌드 설정 불일치

### 두 번째 빌드 (수정 후)

**수정 사항**:
1. local.conf를 Wayland로 변경
2. HeadUnit main.cpp에서 xcb 코드 제거
3. weston.service를 root 사용자로 변경
4. 모든 XDG_RUNTIME_DIR을 /run으로 통일

**빌드 명령어**:
```bash
bitbake -c cleansstate qtbase weston-init headunit instrument-cluster
bitbake des-image
```

**결과**: 부팅 후 검은 화면, 터미널 접근 불가 (CTRL+ALT+F1~F8 응답 없음)

---

## 현재 문제 상황 (2025-11-12)

### 증상
- 부팅 화면 종료 후 양쪽 모니터 모두 검은 화면만 표시
- CTRL+ALT+F1~F8 눌러도 터미널 전환 안 됨
- SSH 연결 불가 (네트워크 미확인)

### 가능한 원인 추측

#### 1. Weston 서비스 실패
- Weston이 시작하지 못함
- DRM backend 초기화 실패
- 권한 문제 (root로 실행하지만 다른 이슈)

#### 2. TTY 할당 문제
- 커스텀 weston.service에서 TTY 관련 설정 제거함
- 원본은 `TTYPath=/dev/tty7` 사용
- TTY 없이 실행하면 키보드 입력 불가능?

#### 3. systemd 의존성 문제
- `weston.service` → `weston.socket` 의존성
- 원본 weston.service는 `Requires=weston.socket` 있음
- 커스텀 버전에서 제거함

#### 4. XDG_RUNTIME_DIR 권한 문제
- `/run` 디렉토리 권한
- Wayland 소켓 생성 실패

#### 5. 부팅 타겟 문제
- `graphical.target` 도달 실패
- 다른 서비스에서 블로킹

---

## 디버깅 계획 (다음 세션)

### 1단계: Serial Console 확인

**UART Serial 연결**:
```bash
# rpi-cmdline.bbappend에서 이미 설정함
CMDLINE_SERIAL = "console=serial0,115200 console=tty1"
```

**확인 사항**:
- 부팅 로그 확인
- systemd 서비스 시작 순서
- Weston 에러 메시지
- 커널 패닉 여부

### 2단계: SSH 복구 시도

**가능한 방법**:
- SD 카드를 PC에 마운트
- `/etc/systemd/system/` 에서 weston 관련 서비스 비활성화
- 재부팅 후 SSH 접속
- journalctl로 로그 수집

**명령어**:
```bash
# SD 카드 마운트 후
sudo mkdir -p /mnt/rootfs
sudo mount /dev/sdXp2 /mnt/rootfs  # rootfs 파티션

# Weston 서비스 비활성화
sudo rm /mnt/rootfs/etc/systemd/system/graphical.target.wants/weston.service

# 언마운트 후 재부팅
sudo umount /mnt/rootfs
```

### 3단계: Weston 서비스 수정 시도

**Option A**: 원본 weston.service 복원
- meta-custom의 weston-init.bbappend 제거
- 기본 weston 사용자로 실행
- D-Bus policy 수정 (root 대신 weston 허용)

**Option B**: weston.service에 TTY 추가
```ini
[Service]
TTYPath=/dev/tty7
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty-fail
```

**Option C**: weston.socket 의존성 추가
```ini
[Unit]
Requires=weston.socket
```

### 4단계: 로그 수집 명령어

SSH 접속 성공 시 실행:
```bash
# 전체 부팅 로그
journalctl -xb > /home/root/boot.log

# Weston 로그
journalctl -u weston.service > /home/root/weston.log

# HeadUnit 로그
journalctl -u headunit.service > /home/root/headunit.log

# IC 로그
journalctl -u instrument-cluster.service > /home/root/ic.log

# systemd 상태
systemctl status weston.service > /home/root/weston-status.log
systemctl status headunit.service > /home/root/headunit-status.log
systemctl status instrument-cluster.service > /home/root/ic-status.log

# DRM 정보
dmesg | grep -i drm > /home/root/drm.log
dmesg | grep -i vc4 > /home/root/vc4.log

# 프로세스 확인
ps aux > /home/root/processes.log

# Wayland 소켓 확인
ls -la /run/wayland* > /home/root/wayland-sockets.log
ls -la /run/user/ > /home/root/user-dirs.log
```

---

## 참고 정보

### D-Bus Policy

**파일**: `/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-env/recipes-core/dbus/files/com.des.vehicle.Gear.conf`

```xml
<busconfig>
  <policy user="root">
    <allow own="com.des.vehicle"/>
    <allow own="com.des.vehicle.Gear"/>
    <allow send_destination="com.des.vehicle"/>
    <allow send_destination="com.des.vehicle.Gear"/>
    <allow receive_sender="com.des.vehicle"/>
    <allow receive_sender="com.des.vehicle.Gear"/>
  </policy>

  <policy context="default">
    <allow send_destination="com.des.vehicle"/>
    <allow send_destination="com.des.vehicle.Gear"/>
  </policy>
</busconfig>
```

**제약**: root만 서비스 소유 가능 → Weston도 root로 실행 필요

### Qt Wayland 환경변수

```bash
QT_QPA_PLATFORM=wayland          # Wayland 플랫폼 사용
WAYLAND_DISPLAY=wayland-0        # Wayland 소켓 이름
XDG_RUNTIME_DIR=/run             # Wayland 소켓 디렉토리
QT_LOGGING_RULES=qt.qpa.*=true;qt.waylandclient.*=true  # 디버그 로그
```

### Weston app-ids 매칭 규칙

- Qt 애플리케이션의 app_id는 실행 파일 이름
- HeadUnit → `HeadUnitApp` (CMakeLists.txt:57)
- IC → `appIC` (CMakeLists.txt:8)
- weston.ini의 app-ids와 정확히 일치해야 함

---

## 다음 세션 작업 순서

1. **Serial console 연결** → 부팅 로그 확인
2. **SD 카드 마운트** → Weston 서비스 비활성화
3. **SSH 접속** → 로그 수집
4. **Weston 서비스 수정** → TTY, socket 추가
5. **재빌드 및 테스트**

---

## 변경된 파일 요약

### Yocto 설정
- `build-des/conf/local.conf`
- `meta-custom/meta-env/recipes-core/images/des-image.bb`

### Weston 관련
- `meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston.ini`
- `meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service` (새 파일)
- `meta-custom/meta-env/recipes-graphics/wayland/weston-init.bbappend`

### HeadUnit 관련
- `Head-Unit/src/main.cpp`
- `meta-custom/meta-app/recipes-des/headunit/headunit.bb`
- `meta-custom/meta-app/recipes-des/headunit/files/headunit.service`

### Instrument Cluster 관련
- `meta-custom/meta-app/recipes-des/instrument-cluster/instrument-cluster.bb`
- `meta-custom/meta-app/recipes-des/instrument-cluster/files/instrument-cluster.service`

---

## 세 번째 빌드 (TTY 및 Socket 수정) - 2025-11-13

### 문제 분석 완료

**근본 원인 확인**:
1. ❌ **weston.socket 누락** - Wayland 소켓 `/run/wayland-0` 생성 실패
2. ❌ **TTY 설정 누락** - 키보드 입력 및 콘솔 접근 불가
3. ❌ **systemd-notify.so 모듈 누락** - Type=notify 사용 시 필수
4. ❌ **EnvironmentFile 미사용** - 환경변수 하드코딩으로 관리 어려움

### 적용된 수정 사항

#### 1. weston.service 완전 재작성
**파일**: `meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service`

**추가된 설정**:
```ini
[Unit]
Requires=systemd-user-sessions.service  # 로그인 세션 준비 대기
Requires=weston.socket                  # Wayland 소켓 생성 보장
Before=graphical.target                 # 그래픽 타겟 전 시작
ConditionPathExists=/dev/tty0          # 가상 콘솔 존재 확인

[Service]
Type=notify                            # systemd-notify.so 필요
EnvironmentFile=/etc/default/weston    # 환경변수 외부 파일로 관리
ExecStart=... --modules=systemd-notify.so  # notify 플러그인 추가
TTYPath=/dev/tty7                      # tty7에 할당
TTYReset=yes                           # TTY 초기화
TTYVHangup=yes                         # 종료 시 hangup
TTYVTDisallocate=yes                   # 가상 터미널 해제
StandardInput=tty-fail                 # TTY 제어 실패 시 실패 처리
UtmpIdentifier=tty7                    # utmp 로그 식별자
UtmpMode=user                          # 사용자 모드
```

#### 2. weston.socket 생성 (신규 파일)
**파일**: `meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.socket`

```ini
[Unit]
Description=Weston Wayland Compositor Socket
RequiresMountsFor=/run

[Socket]
ListenStream=/run/wayland-0    # Wayland 소켓 경로
SocketMode=0777                # 모든 프로세스 접근 가능
SocketUser=root                # root 소유
SocketGroup=root
RemoveOnStop=yes               # 서비스 종료 시 소켓 제거

[Install]
WantedBy=sockets.target
```

**역할**: systemd가 `/run/wayland-0` 소켓을 미리 생성하고, Weston이 이를 사용

#### 3. /etc/default/weston 환경 파일 생성
**파일**: `meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston-default`

```bash
XDG_RUNTIME_DIR=/run
WAYLAND_DISPLAY=wayland-0
#WESTON_LOG_LEVEL=debug  # 필요 시 디버그 활성화
```

**목적**: 환경변수를 서비스 파일에서 분리하여 관리 용이

#### 4. weston-init.bbappend 업데이트
**추가 항목**:
- `file://systemd/weston.socket` → SRC_URI
- `file://weston-default` → SRC_URI
- `install weston.socket` → do_install:append()
- `install weston-default` → `/etc/default/weston`

### 파일 변경 목록 (세 번째 빌드)

**신규 생성**:
- `weston-init/systemd/weston.socket`
- `weston-init/weston-default`

**수정**:
- `weston-init/systemd/weston.service` (TTY, socket, notify 모듈 추가)
- `weston-init.bbappend` (socket, default 파일 설치)

**검증 사항 (헤드유닛/IC 서비스)**:
- ✅ `After=weston.service` 설정 확인
- ✅ `Requires=weston.service` 의존성 확인
- ✅ `XDG_RUNTIME_DIR=/run` 일관성 확인
- ✅ `WAYLAND_DISPLAY=wayland-0` 일관성 확인

### 예상 효과

1. **TTY 접근 복원** → CTRL+ALT+F1~F8로 터미널 전환 가능
2. **Wayland 소켓 보장** → `/run/wayland-0` 항상 생성됨
3. **systemd 통합** → Type=notify로 정확한 시작 완료 통지
4. **디버깅 개선** → journalctl에서 명확한 로그 수집 가능

### 빌드 명령어

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des

# Weston 관련 패키지 클린빌드
bitbake -c cleansstate weston-init

# 이미지 재빌드
bitbake des-image
```

### 테스트 계획

부팅 후 확인 사항:
1. **TTY 전환 테스트**: CTRL+ALT+F1 → 로그인 프롬프트 표시되는지
2. **Weston 상태**: `systemctl status weston.service` → active (running)
3. **Wayland 소켓**: `ls -la /run/wayland-0` → 소켓 존재 확인
4. **HeadUnit 상태**: `systemctl status headunit.service` → active (running)
5. **IC 상태**: `systemctl status instrument-cluster.service` → active (running)
6. **화면 출력**: HDMI-A-1에 HeadUnit, HDMI-A-2에 IC 표시되는지

### 빌드 결과 (성공!)

**빌드 명령어**:
```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des
bitbake -c cleansstate weston-init
bitbake des-image
```

**빌드 통계**:
- 전체 태스크: 7894
- 재실행 필요: 36 (weston-init 관련)
- 캐시 사용: 7858 (99.5%)
- 결과: ✅ **전체 성공**

**생성된 이미지**:
- 파일: `des-image-raspberrypi4-64.rootfs-20251113101427.rpi-sdimg`
- 경로: `build-des/tmp-glibc/deploy/images/raspberrypi4-64/`
- 크기: 1.2GB
- 생성 시간: 2025-11-13 11:16

---

## 네 번째 빌드 (Cursor 비활성화) - 2025-11-13

### 배경
세 번째 빌드 이미지를 플래싱하고 테스트한 결과:
- ✅ **듀얼 디스플레이 성공**: 양쪽 모니터에 정상적으로 화면 표시
- ✅ **TTY 접근 복원**: CTRL+ALT+F1~F8 터미널 전환 가능
- ✅ **D-Bus 통신**: HeadUnit ↔ Instrument Cluster 간 Gear 동기화 정상 작동
- ❌ **새 문제 발견**: 마우스를 연결하고 움직이면 화면이 초기화됨

### 문제 분석

**증상**:
- 라즈베리파이에 USB 마우스 연결
- 마우스를 움직이면 화면이 초기화되고 재렌더링됨
- 커서가 화면에 그려지면서 Qt 애플리케이션 표면이 갱신됨

**근본 원인**:
- Weston의 커서 렌더링이 활성화되어 있음
- 마우스 움직임 → 커서 위치 업데이트 → 화면 갱신 트리거
- Kiosk 모드에서는 커서가 필요 없음 (터치스크린 사용 예정)

### 적용된 수정

#### weston.ini 커서 설정 변경
**파일**: `meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston.ini`

**변경 내용**:
```ini
# HDMI-A-1: First HDMI output (Head-Unit)
[output]
name=HDMI-A-1
mode=1024x600@60
transform=normal
scale=1
app-ids=HeadUnitApp
cursor-size=0  # 추가: 커서 완전히 비활성화

# HDMI-A-2: Second HDMI output (Instrument Cluster)
[output]
name=HDMI-A-2
mode=1024x600@60
transform=normal
scale=1
app-ids=appIC
cursor-size=0  # 추가: 커서 완전히 비활성화
```

**변경 전**:
```ini
[shell]
cursor-size=1  # 최소 크기 커서
```

**변경 후**:
```ini
[output]
cursor-size=0  # 각 출력에서 커서 완전히 비활성화
```

**이유**:
- `cursor-size=0`으로 설정하면 Weston이 커서를 렌더링하지 않음
- 마우스 입력은 여전히 감지되지만 화면 갱신은 발생하지 않음
- Automotive kiosk 환경에서는 커서가 불필요함

### 빌드 명령어

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des

# Weston 설정만 변경되었으므로 weston-init만 클린빌드
bitbake -c cleansstate weston-init

# 이미지 재빌드
bitbake des-image
```

### 빌드 결과 (성공!)

**빌드 통계**:
- 전체 태스크: 7894
- 재실행 필요: 36 (weston-init 관련)
- 캐시 사용: 7858 (99.5%)
- 결과: ✅ **전체 성공**

**생성된 이미지**:
- 파일: `des-image-raspberrypi4-64.rootfs-20251113105644.rpi-sdimg`
- 경로: `build-des/tmp-glibc/deploy/images/raspberrypi4-64/`
- 크기: 1.2GB
- 생성 시간: 2025-11-13 11:59

### 예상 효과

1. ✅ **화면 안정성**: 마우스 움직임으로 인한 화면 재초기화 방지
2. ✅ **성능 개선**: 커서 렌더링 오버헤드 제거
3. ✅ **Kiosk 모드 최적화**: 터치스크린 환경에 적합한 설정

### 테스트 계획

부팅 후 확인 사항:
1. **마우스 연결 테스트**: USB 마우스 연결 후 움직임 테스트
2. **화면 안정성**: 마우스 움직여도 화면 유지되는지 확인
3. **터치 입력**: 터치스크린 입력 정상 작동 확인
4. **애플리케이션 동작**: HeadUnit/IC 정상 작동 확인

---

**마지막 업데이트**: 2025-11-13 12:00
**상태**: ✅ 커서 비활성화 빌드 성공! SD 카드 이미지 생성 완료
**다음 작업**: SD 카드에 이미지 플래싱 후 마우스 움직임 테스트
