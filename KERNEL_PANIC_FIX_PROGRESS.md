# Kernel Panic 및 Dual Display 문제 해결 진행 상황

## 날짜: 2025-11-11

---

## 초기 문제 상황

**증상**: 빌드한 이미지를 Raspberry Pi 4에 부팅하면 커널 패닉 발생

**사용자 환경**:
- Raspberry Pi 4 (64-bit)
- Dual HDMI Display (1024x600 각각)
- Qt 6.9+ 애플리케이션 2개 (HeadUnit, Instrument Cluster)
- Yocto Project 기반 커스텀 이미지

---

## 문제 진단 과정

### 1단계: 설정 파일 조사

#### 확인한 파일들:
1. **`des-image.bb`** - 이미지 레시피
   - Weston/Wayland 포함됨
   - Qt wayland 플러그인 포함
   - eglfs 관련 패키지 없음

2. **`local.conf`** - Yocto 빌드 설정
   - Qt PACKAGECONFIG 확인
   - DISTRO_FEATURES 확인

3. **`rpi-config_%.bbappend`** - Raspberry Pi 부트 설정
   - Dual HDMI 설정 (HDMI-0, HDMI-1)
   - GPU 메모리 128MB
   - KMS 활성화

4. **systemd 서비스 파일들**:
   - `headunit.service`: QT_QPA_PLATFORM=eglfs 설정
   - `instrument-cluster.service`: QT_QPA_PLATFORM=eglfs 설정

### 2단계: Qt PACKAGECONFIG 확인

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des
bitbake -e qtbase | grep "^PACKAGECONFIG="
```

**결과**:
```
PACKAGECONFIG="... wayland gl linuxfb xcb ..."
```

**문제 발견**:
- ❌ `eglfs` 없음
- ❌ `kms` 없음
- ❌ `gbm` 없음
- ❌ `gles2` 없음

### 3단계: DISTRO_FEATURES 확인

```bash
bitbake -e des-image | grep "^DISTRO_FEATURES="
```

**결과**:
```
DISTRO_FEATURES="... x11 wayland opengl ..."
```

**문제 발견**:
- ⚠️ `x11`이 포함됨 → Qt가 X11/xcb 플랫폼 우선 선택
- ⚠️ `x11`이 있으면 eglfs 자동 비활성화됨 (meta-qt6/recipes-qt/qt6/qtbase_git.bb:41 참조)

### 4단계: 근본 원인 파악

**Qt 6 아키텍처 이해** (EGLFS_BUILD_FIX_PROGRESS.md 참조):
- Qt 6에서는 eglfs 플러그인이 별도 패키지가 아님
- `qtbase-plugins` 패키지에 통합됨
- PACKAGECONFIG로 빌드 여부 제어
- `DISTRO_FEATURES`에 x11이 있으면 eglfs 대신 xcb 사용

**커널 패닉 원인 체인**:
```
1. Qt가 eglfs 없이 빌드됨
   ↓
2. systemd 서비스가 eglfs 플랫폼 요구
   ↓
3. Qt 앱 실행 실패 (eglfs 플러그인 없음)
   ↓
4. 서비스 재시작 루프 또는 systemd 문제
   ↓
5. 부팅 실패 / 커널 패닉
```

**추가 문제**:
- Weston compositor와 Qt eglfs가 동시에 DRM/KMS 점유 시도 → 충돌
- Serial console 비활성화로 디버깅 불가능 (rpi-cmdline.bbappend)

---

## 적용한 해결 방법

### 수정 1: `/home/seame/DES_Head-Unit/yocto-workspace/build-des/conf/local.conf`

파일 끝에 추가:

```bash
# ==========================
# Qt 6 EGLFS Support for Dual Display
# ==========================

# Enable Qt eglfs plugins (direct DRM/KMS rendering)
PACKAGECONFIG:append:pn-qtbase = " eglfs kms gbm gles2"

# Remove X11 to prevent conflicts with eglfs
DISTRO_FEATURES:remove = " x11"
```

**목적**:
- Qt eglfs 플러그인 강제 빌드
- X11 제거하여 eglfs 활성화 보장
- KMS/GBM/GLES2 지원 추가

### 수정 2: `/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-env/recipes-core/images/des-image.bb`

**변경 전**:
```python
IMAGE_INSTALL:append = " \
    ...
    qtbase qtbase-plugins qtdeclarative qtmultimedia qtwayland \
    ...
    weston weston-init \
    ...
"
```

**변경 후**:
```python
IMAGE_INSTALL:append = " \
    ...
    qtbase qtbase-plugins qtdeclarative qtmultimedia \
    ...
    # weston weston-init removed (conflicts with eglfs)
    # qtwayland removed (not needed for eglfs)
    ...
"
```

**목적**:
- Wayland compositor (Weston) 제거 → DRM/KMS 충돌 방지
- qtwayland 제거 → 불필요한 의존성 제거

### 수정 3: `/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-env/recipes-bsp/bootfiles/rpi-cmdline.bbappend`

**변경 전**:
```bash
CMDLINE_SERIAL = "console=tty1"
CMDLINE:append = " splash"
```

**변경 후**:
```bash
# Enable psplash boot logo and keep both serial and tty console for debugging
# serial0 = UART serial console (for debugging kernel panic)
# tty1 = HDMI console output
CMDLINE_SERIAL = "console=serial0,115200 console=tty1"
CMDLINE:append = " splash"
```

**목적**:
- UART serial console 복원 (디버깅용)
- 커널 패닉 발생 시 로그 확인 가능

---

## 빌드 및 테스트 (2025-11-11)

### 빌드 명령어:
```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des
bitbake -c cleansstate qtbase
bitbake des-image
```

### 테스트 결과:

#### ✅ 해결된 문제:
- 커널 패닉 해결됨
- 시스템 부팅 성공
- 첫 번째 모니터에 HeadUnit 표시됨

#### ❌ 새로운 문제 발견:

**문제 1: 폰트 깨짐 (첫 번째 모니터)**
- **증상**: HeadUnit이 실행되지만 모든 글자가 네모(□)로 표시됨
- **원인 (추정)**:
  - Qt 폰트 패키지 누락
  - fontconfig 설정 문제
  - TrueType/OpenType 폰트 파일 없음
- **영향**: UI는 표시되지만 텍스트 읽을 수 없음

**문제 2: Instrument Cluster 미실행 (두 번째 모니터)**
- **증상**: 터미널 화면 표시, Instrument Cluster 앱 미실행
- **원인 (추정)**:
  - systemd 서비스 실패
  - KMS 설정 파일 누락 (`/etc/cluster-kms.json`)
  - HDMI-A-2 출력 클레임 실패
  - 서비스 순서 문제
- **영향**: Dual display 목표 미달성

---

## 다음 해결 단계

### 1. Instrument Cluster 서비스 디버깅

#### 확인 명령어 (Raspberry Pi에서):
```bash
# 서비스 상태 확인
systemctl status instrument-cluster.service
systemctl status headunit.service

# 로그 확인
journalctl -u instrument-cluster.service -n 50
journalctl -u headunit.service -n 50

# KMS 설정 파일 확인
ls -la /etc/*.json
cat /etc/cluster-kms.json
cat /etc/headunit-kms.json

# DRM 디바이스 확인
ls -la /dev/dri/
dmesg | grep drm
```

#### 예상 원인 및 해결:

**A. KMS 설정 파일 누락**
- 확인 필요: `/etc/cluster-kms.json`, `/etc/headunit-kms.json` 존재 여부
- 해결: Yocto recipe에 파일 설치 추가
  - `meta-custom/meta-app/recipes-des/headunit/headunit.bb`
  - `meta-custom/meta-app/recipes-des/instrument-cluster/instrument-cluster.bb`

**B. 서비스 실행 순서 문제**
- `instrument-cluster.service`는 `After=headunit.service` 설정됨
- `ExecStartPre=/bin/sleep 3` 있음
- 3초가 부족할 수 있음 → 5초로 증가 고려

**C. DRM 출력 충돌**
- HeadUnit이 모든 DRM 출력을 점유
- KMS 설정이 제대로 적용되지 않음
- 로그에서 "failed to claim output" 메시지 확인

### 2. 폰트 문제 해결

#### A. 필요한 패키지 추가 (des-image.bb)

```python
IMAGE_INSTALL:append = " \
    ...
    fontconfig \
    fontconfig-utils \
    ttf-dejavu-sans \
    ttf-dejavu-sans-mono \
    liberation-fonts \
    ...
"
```

#### B. Qt 폰트 설정 환경변수 (systemd 서비스)

**headunit.service** 및 **instrument-cluster.service**에 추가:
```ini
Environment=QT_QPA_FONTDIR=/usr/share/fonts
Environment=QT_QPA_GENERIC_PLUGINS=
```

#### C. fontconfig 캐시 생성 확인

Yocto 이미지에 postinstall 스크립트 추가:
```bash
fc-cache -fv
```

### 3. KMS 설정 파일 확인 및 수정

#### 예상 파일 위치:
```
meta-custom/meta-app/recipes-des/headunit/files/kms-config/headunit-kms.json
meta-custom/meta-app/recipes-des/instrument-cluster/files/kms-config/cluster-kms.json
```

#### 파일 내용 검증 필요:
```json
// headunit-kms.json
{
  "device": "/dev/dri/card0",
  "outputs": [
    {
      "name": "HDMI-A-1",
      "format": "argb8888"
    }
  ]
}

// cluster-kms.json
{
  "device": "/dev/dri/card0",
  "outputs": [
    {
      "name": "HDMI-A-2",
      "format": "argb8888"
    }
  ]
}
```

#### Recipe 수정 필요 여부 확인:
- `headunit.bb`에서 `SRC_URI`에 KMS 파일 포함 여부
- `do_install()`에서 `/etc/`로 복사 여부

---

## 현재 파일 상태 요약

### 수정된 파일:
1. ✅ `build-des/conf/local.conf` - Qt eglfs 지원 추가, x11 제거
2. ✅ `meta-custom/meta-env/recipes-core/images/des-image.bb` - Weston 제거
3. ✅ `meta-custom/meta-env/recipes-bsp/bootfiles/rpi-cmdline.bbappend` - Serial console 복원

### 확인 필요한 파일:
1. ❓ `meta-custom/meta-app/recipes-des/headunit/headunit.bb` - KMS 파일 설치
2. ❓ `meta-custom/meta-app/recipes-des/instrument-cluster/instrument-cluster.bb` - KMS 파일 설치
3. ❓ `meta-custom/meta-app/recipes-des/headunit/files/kms-config/` - KMS 설정 존재 여부
4. ❓ `meta-custom/meta-app/recipes-des/instrument-cluster/files/kms-config/` - KMS 설정 존재 여부

---

## 참고 문서

### 관련 문서:
- **DUAL_DISPLAY_SOLUTION.md** - Dual display 아키텍처 설명
- **EGLFS_BUILD_FIX_PROGRESS.md** - Qt 6 eglfs 패키지 구조 분석
- **CLAUDE.md** - 프로젝트 전체 구조 및 빌드 명령어

### Qt 환경변수:
```bash
QT_QPA_PLATFORM=eglfs                      # EGLFS 플랫폼 사용
QT_QPA_EGLFS_KMS_CONFIG=/etc/xxx.json     # KMS 설정 파일
QT_LOGGING_RULES=qt.qpa.*=true            # Qt 플랫폼 로깅 활성화
QT_QPA_FONTDIR=/usr/share/fonts           # 폰트 디렉토리
```

### 디버깅 명령어:
```bash
# Qt 플러그인 확인
ls -la /usr/lib/qt6/plugins/platforms/

# eglfs 플러그인 존재 확인
find /usr -name "*eglfs*"

# 폰트 확인
fc-list
ls -la /usr/share/fonts/

# DRM/KMS 정보
modetest -M vc4
```

---

## 작업 체크리스트

### Phase 1: 커널 패닉 해결 ✅
- [x] Qt eglfs 지원 활성화
- [x] Weston 제거
- [x] Serial console 복원
- [x] 빌드 및 부팅 테스트

### Phase 2: Instrument Cluster 실행 (진행 중)
- [ ] systemd 서비스 로그 확인
- [ ] KMS 설정 파일 존재 여부 확인
- [ ] Recipe에 KMS 파일 설치 추가 (필요 시)
- [ ] 서비스 순서 및 타이밍 조정

### Phase 3: 폰트 문제 해결 (진행 중)
- [ ] 폰트 패키지 추가 (des-image.bb)
- [ ] Qt 폰트 환경변수 설정
- [ ] fontconfig 캐시 생성 확인
- [ ] 빌드 및 테스트

### Phase 4: 통합 테스트 (대기)
- [ ] Dual display 동작 확인
- [ ] D-Bus 통신 테스트
- [ ] Gear 상태 동기화 확인
- [ ] 성능 및 안정성 테스트

---

## 다음 세션 시작 시 할 일

1. **Raspberry Pi에서 로그 수집**:
   ```bash
   systemctl status instrument-cluster.service > ~/cluster-status.log
   journalctl -u instrument-cluster.service -n 100 > ~/cluster-journal.log
   ls -la /etc/*.json > ~/kms-files.log
   ls -la /usr/lib/qt6/plugins/platforms/ > ~/qt-plugins.log
   fc-list > ~/fonts.log
   ```

2. **로그 파일을 개발 머신으로 복사**:
   ```bash
   scp root@raspberrypi:~/*.log /home/seame/DES_Head-Unit/logs/
   ```

3. **로그 분석 후 문제 해결**:
   - Instrument Cluster 서비스 실패 원인 파악
   - 폰트 누락 패키지 식별
   - KMS 설정 문제 확인

4. **해결 방안 적용 및 재빌드**

---

## 참고 사항

- **빌드 시간**: qtbase 재빌드 약 30-60분 소요
- **테스트 환경**: Raspberry Pi 4, 듀얼 HDMI 1024x600
- **Git 상태**: 수정 파일들 아직 커밋 안 됨
- **백업**: local.conf.backup 존재함

---

**마지막 업데이트**: 2025-11-11
**다음 작업 우선순위**: Instrument Cluster 서비스 디버깅 → 폰트 문제 해결
