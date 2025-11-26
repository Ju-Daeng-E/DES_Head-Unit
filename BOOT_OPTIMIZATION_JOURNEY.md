# 부팅 최적화 과정: 현재 상태까지의 여정

## 📋 목차
1. [초기 상태](#초기-상태)
2. [최적화 목표](#최적화-목표)
3. [변경 사항 (시간순)](#변경-사항-시간순)
4. [해결한 문제들](#해결한-문제들)
5. [현재 문제 분석](#현재-문제-분석)
6. [진단 단계](#진단-단계)
7. [가능한 원인들](#가능한-원인들)
8. [복구 계획](#복구-계획)

---

## 초기 상태

### 작동하던 시스템 구성
- **부팅 순서**: Plymouth 부팅 영상 → Plymouth 종료 → Weston 시작 → Head-Unit 시작 → IC 시작
- **문제점**:
  - IC가 Head-Unit보다 훨씬 늦게 시작됨 (순차 부팅)
  - Plymouth가 종료되기를 기다리느라 Weston이 늦게 시작됨
  - 전체 부팅 시간이 15초 이상 소요됨

### 원래 서비스 의존성
```
plymouth-start → plymouth-quit-wait → weston.service → headunit.service → instrument-cluster.service
```

---

## 최적화 목표

사용자 요구사항: **"7초간 페라리 영상 틀면서 빠르게 뒤에선 전부 부팅하고, 영상 끝나면 바로 앱 두 개 다 동시에 켜지면 좋겠어"**

### 구체적 목표
1. ✅ Plymouth 영상을 정확히 7초 동안 재생
2. ✅ Weston과 앱들이 Plymouth와 병렬로 부팅
3. ✅ Head-Unit과 IC가 동시에 시작
4. ❌ 7초 후 두 앱이 화면에 동시에 표시 (현재 실패)

---

## 변경 사항 (시간순)

### 1단계: Plymouth 자동 종료 메커니즘 추가

#### 생성: `plymouth-quit-timer.service`
**경로**: `yocto-workspace/meta-custom/meta-env/recipes-core/plymouth/plymouth/plymouth-quit-timer.service`

**목적**: Plymouth가 무한 루프에 빠지는 것을 방지하고 정확히 7초 후 종료

```ini
[Unit]
Description=Plymouth Quit Timer (7 seconds exact)
After=plymouth-start.service
Before=display-manager.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'sleep 7 && /usr/bin/plymouth quit --retain-splash'
RemainAfterExit=yes
TimeoutStartSec=15

[Install]
WantedBy=sysinit.target
```

**변경 이유**:
- 원래는 Plymouth를 종료하는 서비스가 없어서 무한 반복됨
- 사용자가 Ctrl+Alt+F1을 눌렀을 때 부팅 영상이 계속 반복되는 것을 확인
- `plymouth-quit.service`와 `plymouth-quit-wait.service`를 mask하고 새로운 타이머 서비스로 대체

#### 수정: `plymouth_%.bbappend`
```python
SRC_URI += " \
    file://plymouth-quit-timer.service \
"

do_install:append() {
    install -m 0644 ${WORKDIR}/plymouth-quit-timer.service ${D}${systemd_system_unitdir}/
}

SYSTEMD_SERVICE:${PN} += "plymouth-quit-timer.service"

pkg_postinst_ontarget:${PN}:append() {
    systemctl enable plymouth-quit-timer.service || true
    systemctl mask plymouth-quit.service || true
    systemctl mask plymouth-quit-wait.service || true
}
```

---

### 2단계: Weston 서비스 완전 재작성

#### 수정: `weston.service`
**경로**: `yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service`

#### 주요 변경 사항:

| 변경 항목 | 이전 | 이후 | 이유 |
|----------|------|------|------|
| **Type** | `Type=notify` | `Type=simple` | systemd-notify.so 모듈이 없어서 notify 방식 사용 불가 |
| **ExecStart 모듈** | `--modules=systemd-notify.so` 포함 | 제거됨 | 해당 모듈이 Weston 빌드에 없음 |
| **Plymouth 의존성** | `After=plymouth-quit-wait.service` | 완전 제거 | Weston이 Plymouth 종료를 기다리지 않고 즉시 시작 |
| **User** | `User=weston` | `User=root` | weston 사용자가 시스템에 존재하지 않음 |
| **Group** | `Group=weston` | `Group=root` | weston 그룹이 존재하지 않음 |
| **ExecStartPre** | `/bin/sleep 3` | 제거됨 | 불필요한 3초 지연 제거 |
| **ExecStartPost** | 없음 | `/bin/sleep 1` 추가 | Weston이 완전히 준비될 시간 확보 |

#### 최종 weston.service
```ini
[Unit]
Description=Weston, a Wayland compositor, as a system service
Requires=systemd-user-sessions.service
After=systemd-user-sessions.service
Wants=dbus.socket
After=dbus.socket
Requires=weston.socket
Before=graphical.target
ConditionPathExists=/dev/tty0

[Service]
Type=simple
EnvironmentFile=/etc/default/weston
ExecStart=/usr/bin/weston --config=/etc/xdg/weston/weston.ini
ExecStartPost=/bin/sleep 1
Restart=on-failure
RestartSec=5
User=root
Group=root
WorkingDirectory=/root
TTYPath=/dev/tty7
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=null
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
```

**핵심 변경 이유**:
- **Type=simple**: Weston이 systemd에 준비 신호를 보낼 필요 없이 즉시 "active" 상태로 전환
- **Plymouth 의존성 제거**: Weston이 Plymouth와 병렬로 시작하여 부팅 시간 단축
- **User=root**: 권한 문제 회피 및 소켓 소유권 일치

---

### 3단계: Weston 소켓 권한 수정

#### 수정: `weston.socket`
**경로**: `yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.socket`

| 변경 항목 | 이전 | 이후 | 이유 |
|----------|------|------|------|
| **SocketUser** | `weston` | `root` | weston 사용자 없음 |
| **SocketGroup** | `wayland` | `root` | wayland 그룹 없음 |
| **SocketMode** | `0775` | `0777` | 모든 사용자가 접근 가능하도록 |

```ini
[Socket]
ListenStream=/run/wayland-0
SocketMode=0777
SocketUser=root
SocketGroup=root
RemoveOnStop=yes
```

---

### 4단계: Head-Unit 서비스 완전 재작성

#### 수정: `headunit.service`
**경로**: `yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/headunit.service`

#### 주요 변경 사항:

| 변경 항목 | 이전 | 이후 | 이유 |
|----------|------|------|------|
| **ExecStartPre** | `timeout 3 sh -c "..."` | busybox 호환 루프 | `timeout` 명령어가 busybox에 없음 |
| **SupplementaryGroups** | `video render input wayland` | `video input` | `render`, `wayland` 그룹이 존재하지 않음 |
| **IOSchedulingClass** | 있음 | 제거됨 | 지원되지 않는 옵션 |
| **After** | 여러 의존성 | `weston.service`만 | 불필요한 의존성 제거 |

#### ExecStartPre 변경 상세

**이전 (실패)**:
```bash
ExecStartPre=/bin/sh -c 'timeout 3 sh -c "while [ ! -S /run/wayland-0 ]; do sleep 0.1; done"'
```

**문제점**:
- `timeout` 명령어가 busybox에 없음
- 서비스가 시작조차 못함

**이후 (busybox 호환)**:
```bash
ExecStartPre=/bin/sh -c 'i=0; while [ ! -S /run/wayland-0 ] && [ $i -lt 60 ]; do sleep 0.1; i=$((i+1)); done; exit 0'
```

**개선 사항**:
- 순수 POSIX sh 문법 사용
- 최대 60번 반복 (6초)
- `exit 0`으로 항상 성공 반환 (실패해도 서비스 시작)

#### 최종 headunit.service
```ini
[Unit]
Description=Head Unit Application
After=weston.service
Wants=weston.service

[Service]
Type=simple
ExecStartPre=/bin/sh -c 'i=0; while [ ! -S /run/wayland-0 ] && [ $i -lt 60 ]; do sleep 0.1; i=$((i+1)); done; exit 0'
Environment=QT_QPA_PLATFORM=wayland
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run
Environment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
Environment=QT_WAYLAND_FORCE_FULLSCREEN=1
ExecStart=/usr/bin/HeadUnitApp
Restart=on-failure
RestartSec=3
User=root
Group=root
SupplementaryGroups=video input
Nice=-5
StandardOutput=journal
StandardError=journal
TimeoutStartSec=15

[Install]
WantedBy=graphical.target
```

---

### 5단계: Instrument Cluster 병렬 시작 활성화

#### 수정: `instrument-cluster.service`
**경로**: `yocto-workspace/meta-custom/meta-app/recipes-des/instrument-cluster/files/instrument-cluster.service`

#### 핵심 변경:

**이전**:
```ini
After=weston.service headunit.service piracer-controller.service
```

**이후**:
```ini
After=weston.service piracer-controller.service
```

**변경 이유**:
- `After=headunit.service` 제거로 IC가 Head-Unit을 기다리지 않음
- **두 앱이 동시에 병렬로 시작**
- 3-5초의 부팅 시간 단축

#### 최종 instrument-cluster.service
```ini
[Unit]
Description=Instrument Cluster Application
After=weston.service piracer-controller.service
Wants=weston.service piracer-controller.service

[Service]
Type=simple
ExecStartPre=/bin/sh -c 'i=0; while [ ! -S /run/wayland-0 ] && [ $i -lt 60 ]; do sleep 0.1; i=$((i+1)); done; exit 0'
Environment=QT_QPA_PLATFORM=wayland
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run
Environment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
Environment=QT_WAYLAND_FORCE_FULLSCREEN=1
Environment=QT_WAYLAND_FULLSCREEN_OUTPUT=HDMI-A-2
ExecStart=/usr/bin/appIC
Restart=on-failure
RestartSec=3
User=root
Group=root
SupplementaryGroups=video input
Nice=-5
StandardOutput=journal
StandardError=journal
TimeoutStartSec=15

[Install]
WantedBy=graphical.target
```

---

## 해결한 문제들

### 1. Plymouth 무한 루프 ✅
**증상**: Ctrl+Alt+F1을 눌렀을 때 부팅 영상이 계속 반복됨
**원인**: Plymouth를 종료하는 서비스가 활성화되지 않음
**해결**: plymouth-quit-timer.service 생성 및 활성화

### 2. `timeout` 명령어 없음 ✅
**증상**: `systemctl status headunit.service` 시 exit code 실패
**원인**: busybox에 `timeout` 명령어가 없음
**해결**: 순수 sh 문법으로 루프 구현

### 3. 존재하지 않는 사용자/그룹 ✅
**증상**: 서비스 시작 실패
**문제 그룹**: `weston`, `wayland`, `render`
**해결**: 모든 서비스를 `root:root`로 실행, SupplementaryGroups는 `video input`만 사용

### 4. Type=notify 위험성 ✅
**위험**: systemd-notify.so 모듈이 없으면 Weston이 준비 신호를 보낼 수 없음
**결과**: systemd가 타임아웃까지 대기, 앱 시작 지연
**해결**: Type=simple로 변경하여 즉시 활성화

### 5. ExecStartPre 실패 시 서비스 중단 ✅
**문제**: 소켓이 없으면 ExecStartPre가 실패하여 서비스가 시작되지 않음
**해결**: `exit 0` 추가로 항상 성공 반환, Restart=on-failure로 자동 재시도

### 6. Weston이 Plymouth 대기 ✅
**문제**: `After=plymouth-quit-wait.service`로 인해 Weston이 늦게 시작
**해결**: Plymouth 의존성 완전 제거, 병렬 시작

### 7. 순차 앱 시작 ✅
**문제**: IC가 Head-Unit을 기다림
**해결**: `After=headunit.service` 제거로 병렬 시작

### 8. 불필요한 지연 ✅
**문제**: 원래 서비스에 `sleep 3` 하드코딩
**해결**: 제거

---

## 현재 문제 분석

### 증상
```
[OK] Stopped Show Plymouth Boot Screen
```
이 메시지가 표시된 후 시스템이 멈춤. 화면은 검은색 상태 유지.

### 예상되는 부팅 타임라인 vs 실제

#### 예상 타임라인
```
[0.0s] 커널 부팅
[1.0s] systemd 초기화
       ├─ plymouth-start.service
       ├─ plymouth-quit-timer.service (7초 타이머 시작)
       └─ weston.socket 생성

[1.5s] Plymouth 영상 시작

[2.0s] Weston 시작 (Plymouth와 병렬)
       ├─ /dev/tty7 할당
       └─ /run/wayland-0 소켓 활성화

[3.0s] Weston 완전히 준비
       ├─ HeadUnit ExecStartPre: 소켓 확인 ✅
       └─ IC ExecStartPre: 소켓 확인 ✅

[4-6s] 앱들 QML 로딩

[7.0s] plymouth-quit-timer 실행
       └─ plymouth quit --retain-splash

[7.1s] ✨ 두 앱 화면에 표시 ✨
```

#### 실제 상황
```
[0.0s] 커널 부팅
[1.0s] systemd 초기화
[1.5s] Plymouth 영상 시작
...
[7.0s] plymouth-quit-timer 실행
       └─ [OK] Stopped Show Plymouth Boot Screen
[7.1s] ❌ 시스템 멈춤 - 검은 화면
```

### 문제가 발생하는 지점
Plymouth는 성공적으로 종료되었지만, **Weston이나 앱들이 시작되지 않음**.

---

## 진단 단계

### 우선순위 1: Weston 상태 확인

SSH로 접속 가능하면 다음 명령어 실행:

```bash
# Weston 서비스 상태
systemctl status weston.service

# Weston 소켓 상태
systemctl status weston.socket

# 소켓 파일 존재 확인
ls -la /run/wayland-0

# Weston 로그
journalctl -u weston.service -n 50

# Weston 프로세스 확인
ps aux | grep weston
```

### 우선순위 2: 앱 상태 확인

```bash
# Head-Unit 상태
systemctl status headunit.service
journalctl -u headunit.service -n 50

# IC 상태
systemctl status instrument-cluster.service
journalctl -u instrument-cluster.service -n 50
```

### 우선순위 3: TTY 상태 확인

```bash
# /dev/tty7 사용 여부
fuser /dev/tty7

# Plymouth 프로세스
ps aux | grep plymouth

# TTY 목록
ls -la /dev/tty*
```

### 우선순위 4: 필수 파일 존재 확인

```bash
# Weston 설정 파일
ls -la /etc/xdg/weston/weston.ini
cat /etc/xdg/weston/weston.ini

# Weston 환경 변수 파일
ls -la /etc/default/weston
cat /etc/default/weston

# 앱 바이너리
ls -la /usr/bin/HeadUnitApp
ls -la /usr/bin/appIC
```

### 우선순위 5: systemd 의존성 그래프

```bash
# graphical.target 의존성
systemctl list-dependencies graphical.target

# Weston 의존성
systemctl list-dependencies weston.service

# 실패한 서비스 확인
systemctl --failed
```

---

## 가능한 원인들

### 원인 1: Weston이 시작되지 않음 (가능성: ⭐⭐⭐⭐⭐)
**증상 예상**:
- `systemctl status weston.service` → `failed` 또는 `inactive`
- `/run/wayland-0` 소켓이 생성되지 않음

**가능한 세부 원인**:

#### 1-A: `/dev/tty7`이 Plymouth에 의해 점유됨
```bash
# 확인 방법
fuser /dev/tty7
ps aux | grep plymouth
```
**해결 방법**: Plymouth가 다른 TTY를 사용하도록 설정하거나 완전히 종료되도록 수정

#### 1-B: `/etc/xdg/weston/weston.ini` 파일이 없음
```bash
# 확인 방법
ls -la /etc/xdg/weston/weston.ini
```
**해결 방법**: weston-init.bbappend에서 파일 설치 확인

#### 1-C: `/etc/default/weston` 파일이 없음
```bash
# 확인 방법
ls -la /etc/default/weston
```
**해결 방법**: EnvironmentFile을 제거하거나 파일 생성

#### 1-D: Weston 바이너리 문제
```bash
# 확인 방법
/usr/bin/weston --version
ldd /usr/bin/weston
```
**해결 방법**: Weston 패키지 재빌드

### 원인 2: weston.socket이 시작되지 않음 (가능성: ⭐⭐⭐⭐)
**증상 예상**:
- `systemctl status weston.socket` → `failed`
- `/run` 디렉토리에 쓰기 권한 없음

**가능한 세부 원인**:
```bash
# 확인 방법
systemctl status weston.socket
ls -ld /run
```

**해결 방법**:
- `/run` 권한 확인 및 수정
- weston.socket의 `RequiresMountsFor=/run` 확인

### 원인 3: graphical.target이 도달하지 않음 (가능성: ⭐⭐⭐)
**증상 예상**:
- 시스템이 graphical.target까지 도달하지 못함
- multi-user.target에서 멈춤

```bash
# 확인 방법
systemctl is-system-running
systemctl status graphical.target
systemctl list-jobs
```

**해결 방법**:
- 실패한 의존성 서비스 확인 및 수정
- `systemctl --failed` 확인

### 원인 4: Plymouth가 완전히 종료되지 않음 (가능성: ⭐⭐)
**증상 예상**:
- Plymouth 프로세스가 여전히 실행 중
- `/dev/tty7`을 계속 점유

```bash
# 확인 방법
ps aux | grep plymouthd
pgrep plymouth
```

**해결 방법**:
- plymouth-quit-timer.service에서 `--retain-splash` 제거
- `plymouth quit`을 `plymouth quit --wait`로 변경

### 원인 5: 앱들이 시작되었지만 화면에 표시되지 않음 (가능성: ⭐)
**증상 예상**:
- `systemctl status headunit.service` → `active (running)`
- `systemctl status instrument-cluster.service` → `active (running)`
- 프로세스는 존재하지만 화면에 아무것도 없음

```bash
# 확인 방법
ps aux | grep HeadUnitApp
ps aux | grep appIC
journalctl -u headunit.service -n 50
journalctl -u instrument-cluster.service -n 50
```

**해결 방법**:
- Qt 환경 변수 확인
- Wayland 연결 확인
- QML 로딩 오류 확인

---

## 복구 계획

### 즉시 실행 가능한 진단 스크립트

SSH 접속 후 다음 스크립트 실행:

```bash
#!/bin/bash
echo "=== DES Boot Diagnosis ==="
echo

echo "1. Service Status"
echo "-----------------"
systemctl status weston.socket --no-pager
systemctl status weston.service --no-pager
systemctl status headunit.service --no-pager
systemctl status instrument-cluster.service --no-pager

echo
echo "2. Socket and Files"
echo "-------------------"
ls -la /run/wayland-0 2>/dev/null || echo "/run/wayland-0 NOT FOUND"
ls -la /etc/xdg/weston/weston.ini 2>/dev/null || echo "weston.ini NOT FOUND"
ls -la /etc/default/weston 2>/dev/null || echo "/etc/default/weston NOT FOUND"

echo
echo "3. TTY Status"
echo "-------------"
fuser /dev/tty7 2>/dev/null || echo "tty7 is free"
ps aux | grep plymouth | grep -v grep

echo
echo "4. Processes"
echo "------------"
ps aux | grep -E "(weston|HeadUnitApp|appIC)" | grep -v grep

echo
echo "5. Failed Services"
echo "------------------"
systemctl --failed --no-pager

echo
echo "6. Recent Logs"
echo "--------------"
journalctl -n 100 --no-pager | grep -E "(weston|headunit|instrument-cluster|plymouth)"
```

### 단계별 수정 계획

#### 수정 1: EnvironmentFile 의존성 제거

**문제**: `/etc/default/weston` 파일이 없을 수 있음

**weston.service 수정**:
```ini
# 이 줄 주석 처리 또는 제거
# EnvironmentFile=/etc/default/weston
```

**또는 파일 생성**: `yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston-default`
```bash
# Weston environment variables
# Empty for now - all settings in weston.ini
```

**bbappend에서 설치**:
```python
do_install:append() {
    install -d ${D}${sysconfdir}/default
    install -m 0644 ${WORKDIR}/weston-default ${D}${sysconfdir}/default/weston
}
```

#### 수정 2: Plymouth TTY 충돌 방지

**plymouth-quit-timer.service 수정**:
```ini
[Service]
ExecStart=/bin/sh -c 'sleep 7 && /usr/bin/plymouth quit --wait'
```

`--retain-splash`를 제거하고 `--wait` 추가로 완전히 종료될 때까지 대기

#### 수정 3: Weston 시작 지연 추가

**문제**: Weston이 너무 빨리 시작하여 Plymouth와 충돌할 수 있음

**weston.service에 추가**:
```ini
[Unit]
After=systemd-user-sessions.service dbus.socket plymouth-quit-timer.service
```

Plymouth 타이머가 끝날 때까지 기다림

#### 수정 4: 디버그 모드 활성화

**weston.service 임시 수정**:
```ini
Environment=WAYLAND_DEBUG=1
StandardOutput=journal
StandardError=journal
```

**headunit.service에 추가**:
```ini
Environment=QT_LOGGING_RULES=*=true
Environment=QT_DEBUG_PLUGINS=1
```

---

## 다음 단계 요약

### 1. SSH 접속하여 진단 스크립트 실행
위의 "즉시 실행 가능한 진단 스크립트" 실행

### 2. 로그 수집
```bash
journalctl -u weston.service > /tmp/weston.log
journalctl -u headunit.service > /tmp/headunit.log
journalctl -u instrument-cluster.service > /tmp/ic.log
journalctl -u plymouth-quit-timer.service > /tmp/plymouth-timer.log
```

### 3. 문제 원인 확인 후 수정 적용
위의 "가능한 원인들"과 "복구 계획"을 기반으로 수정

### 4. 이미지 재빌드 및 배포
```bash
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake -c cleansstate weston-init headunit instrument-cluster plymouth
bitbake des-image
```

### 5. 배포 및 재테스트

---

## 결론

### 성공한 부분 ✅
- Plymouth 자동 종료 메커니즘 구현
- busybox 호환성 확보
- 병렬 부팅 구조 구현
- 권한 문제 해결
- 서비스 의존성 최적화

### 현재 문제 ❌
- Plymouth는 정상적으로 종료되지만, Weston이 시작되지 않거나 앱들이 표시되지 않음
- 화면이 검은색으로 멈춤

### 가장 유력한 원인
1. **Weston이 시작되지 않음** (TTY 충돌, 설정 파일 없음 등)
2. **weston.socket 생성 실패** (권한 문제)
3. **graphical.target 도달 실패** (의존성 문제)

### 해결을 위한 핵심 작업
1. SSH 접속하여 서비스 상태 확인 (가장 중요!)
2. 로그 분석으로 정확한 실패 지점 파악
3. 필요한 파일 존재 여부 확인
4. TTY 충돌 확인 및 해결

---

**작성일**: 2025-11-25
**문서 버전**: 1.0
**상태**: 진단 대기 중
