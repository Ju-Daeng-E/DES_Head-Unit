# Qt 6 EGLFS 빌드 오류 수정 진행 상황

## 문제 상황

### 발생한 오류
```bash
ERROR: Nothing RPROVIDES 'qtbase-plugins-platforms-eglfs'
(but /home/seame/DES_Head-Unit/yocto-workspace/build-des/../meta-custom/meta-env/recipes-core/images/des-image.bb RDEPENDS on or otherwise requires it)
```

### 오류 원인
`des-image.bb`에 추가한 패키지 이름이 Qt 5 기준이어서 Qt 6에서는 존재하지 않음:
```python
# 잘못된 패키지 이름 (Qt 5 스타일)
qtbase-plugins-platforms-eglfs
qtbase-plugins-platforms-eglfs-kms
```

## 조사 내용

### Qt 6 아키텍처 차이점

**Qt 5에서는:**
- eglfs 플러그인이 별도 패키지로 분리됨
- `qtbase-plugins-platforms-eglfs` 같은 개별 패키지 존재

**Qt 6에서는:**
- eglfs 플러그인이 `qtbase-plugins` 패키지에 통합됨
- PACKAGECONFIG 옵션으로 빌드 여부 제어
- 별도의 eglfs 전용 패키지가 없음

### 확인한 파일들

#### 1. `/home/seame/DES_Head-Unit/yocto-workspace/meta-qt6/recipes-qt/qt6/qtbase_git.bb`

**핵심 내용 (Line 54-61):**
```python
PACKAGECONFIG_GRAPHICS ?= "\
    ${@bb.utils.filter('DISTRO_FEATURES', 'vulkan', d)} \
    ${@bb.utils.filter('DISTRO_FEATURES', 'wayland', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'opengl', \
        bb.utils.contains('DISTRO_FEATURES', 'x11', 'gl', 'kms gbm gles2 eglfs', d), 'no-opengl', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'directfb', 'directfb', '', d)} \
    linuxfb \
"
```

**EGLFS 관련 PACKAGECONFIG (Line 132-136):**
```python
PACKAGECONFIG[eglfs] = "-DFEATURE_eglfs=ON,-DFEATURE_eglfs=OFF"
PACKAGECONFIG[eglfs-egldevice] = "-DFEATURE_eglfs_egldevice=ON,-DFEATURE_eglfs_egldevice=OFF"
PACKAGECONFIG[kms] = "-DFEATURE_kms=ON,-DFEATURE_kms=OFF,drm virtual/egl"
PACKAGECONFIG[gles2] = "-DFEATURE_opengles2=ON,-DFEATURE_opengles2=OFF,virtual/libgles2 virtual/egl"
PACKAGECONFIG[gbm] = "-DFEATURE_gbm=ON,-DFEATURE_gbm=OFF,virtual/libgbm"
```

**분석:**
- `DISTRO_FEATURES`에 `opengl`이 있고 `x11`이 없으면 자동으로 `eglfs` 활성화됨
- eglfs는 `kms`, `gbm`, `gles2`와 함께 동작
- 별도 패키지가 아니라 qtbase 빌드 시 포함됨

#### 2. `/home/seame/DES_Head-Unit/yocto-workspace/meta-qt6/recipes-qt/qt6/qt6.inc`

**패키지 구조 (Line 40-69):**
```python
PACKAGE_BEFORE_PN = "${PN}-qmlplugins ${PN}-tools ${PN}-plugins ${PN}-examples"

FILES:${PN}-plugins = " \
    ${QT6_INSTALL_PLUGINSDIR}/*/*${SOLIBSDEV} \
    ${QT6_INSTALL_PLUGINSDIR}/*/*/*${SOLIBSDEV} \
    ${QT6_INSTALL_PLUGINSDIR}/*/*/*/*${SOLIBSDEV} \
"
```

**분석:**
- Qt 6에서는 모든 플랫폼 플러그인이 `qtbase-plugins` 패키지에 포함됨
- eglfs 플러그인도 `${QT6_INSTALL_PLUGINSDIR}/platforms/` 아래에 설치됨
- 별도로 분리된 eglfs 패키지는 존재하지 않음

### 현재 시스템 설정 확인 필요

다음을 확인해야 함:
1. `build-des/conf/local.conf`의 `DISTRO_FEATURES` 설정
2. 현재 qtbase가 어떤 PACKAGECONFIG로 빌드되었는지
3. eglfs 플러그인이 이미 빌드되어 있는지 여부

## 해결 방안

### 옵션 1: 기존 qtbase에 이미 eglfs가 포함되어 있는 경우

**수정할 파일:** `des-image.bb`

**변경 전:**
```python
IMAGE_INSTALL:append = " \
    qtbase qtbase-plugins qtdeclarative qtmultimedia qtwayland \
    qtdeclarative-plugins qtdeclarative-qmlplugins qtshadertools \
    qtbase-plugins-platforms-eglfs qtbase-plugins-platforms-eglfs-kms \  # 이 두 줄 삭제
    ...
"
```

**변경 후:**
```python
IMAGE_INSTALL:append = " \
    qtbase qtbase-plugins qtdeclarative qtmultimedia qtwayland \
    qtdeclarative-plugins qtdeclarative-qmlplugins qtshadertools \
    # eglfs는 qtbase-plugins에 이미 포함되어 있음
    ...
"
```

**장점:**
- 가장 간단한 해결책
- 추가 빌드 시간 불필요

**단점:**
- eglfs가 실제로 빌드되어 있는지 확인 필요
- 빌드되지 않았다면 작동하지 않음

### 옵션 2: qtbase를 eglfs 지원으로 재빌드

**수정할 파일:** `build-des/conf/local.conf`

**추가할 내용:**
```bash
# Qt 6 EGLFS 지원 활성화
PACKAGECONFIG:append:pn-qtbase = " eglfs kms gbm gles2"

# DISTRO_FEATURES 확인 및 수정 (필요한 경우)
DISTRO_FEATURES:append = " opengl"
DISTRO_FEATURES:remove = " x11"  # X11이 있으면 eglfs 대신 xcb 사용됨
```

**그리고 des-image.bb에서 잘못된 패키지 이름 제거:**
```python
IMAGE_INSTALL:append = " \
    qtbase qtbase-plugins qtdeclarative qtmultimedia qtwayland \
    qtdeclarative-plugins qtdeclarative-qmlplugins qtshadertools \
    # 잘못된 줄 제거됨
    ...
"
```

**장점:**
- 확실하게 eglfs 지원 보장
- 명시적 설정으로 향후 문제 방지

**단점:**
- qtbase 재빌드 필요 (시간 소요)
- DISTRO_FEATURES 변경이 다른 패키지에 영향 줄 수 있음

### 옵션 3: 하이브리드 접근 (권장)

**1단계: 현재 상태 확인**
```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des
oe-pkgdata-util list-pkg-files qtbase-plugins | grep eglfs
```

**2단계: eglfs가 없으면 local.conf 수정**
```bash
# build-des/conf/local.conf에 추가
PACKAGECONFIG:append:pn-qtbase = " eglfs kms gbm gles2"
```

**3단계: des-image.bb 수정 (항상)**
잘못된 패키지 이름 제거

## 다음 단계

1. ✅ **완료:** Qt 6 아키텍처 조사 및 문제 원인 파악
2. ⏳ **진행 중:** 현재 qtbase 빌드 설정 확인
3. ⏱️ **대기 중:** 해결 방안 선택 및 적용
4. ⏱️ **대기 중:** 이미지 재빌드
5. ⏱️ **대기 중:** 테스트 및 검증

## 참고 자료

### Qt 6 EGLFS 문서
- Qt 6는 PACKAGECONFIG 기반으로 플랫폼 플러그인 빌드
- eglfs는 `qtbase-plugins` 패키지에 통합됨
- 별도의 분리된 eglfs 패키지는 존재하지 않음

### Yocto Qt 6 레이어 구조
```
meta-qt6/
├── recipes-qt/qt6/
│   ├── qtbase_git.bb          # eglfs PACKAGECONFIG 정의
│   ├── qt6.inc                # 패키지 분할 규칙
│   └── qt6-git.inc            # 공통 설정
```

### 핵심 개념
- **PACKAGECONFIG**: Yocto에서 선택적 기능을 제어하는 메커니즘
- **DISTRO_FEATURES**: 배포판 전체의 기능 플래그
- **IMAGE_INSTALL**: 이미지에 설치할 패키지 목록
- **RDEPENDS**: 런타임 의존성

## 현재 작업 상태

파일 조사 단계에서 중단됨. 다음 확인 필요:
- `build-des/conf/local.conf` 내용
- 현재 qtbase PACKAGECONFIG 설정
- 빌드된 qtbase-plugins에 eglfs 포함 여부
