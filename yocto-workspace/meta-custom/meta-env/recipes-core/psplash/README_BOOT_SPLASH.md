# DES Cockpit 부팅 스플래시 커스터마이제이션 가이드

## 현재 설정

- **기본 배경색**: 다크 블루 (`#1A1A2E`)
- **진행 바 색상**: 브라이트 블루 (`#007ACC`)
- **텍스트 색상**: 화이트 (`#FFFFFF`)
- **해상도**: 800x480 (Raspberry Pi HDMI 기본 해상도)

## 빠른 시작

### 방법 1: 색상만 변경하기 (간단)

`psplash/psplash-poky-img.h` 파일에서 색상 매크로를 수정:

```c
#define PSPLASH_BACKGROUND_COLOR 0x1a, 0x1a, 0x2e  /* RGB 값 변경 */
#define PSPLASH_BAR_COLOR        0x00, 0x7a, 0xcc
#define PSPLASH_TEXT_COLOR       0xff, 0xff, 0xff
```

RGB 값은 16진수로 표현합니다 (예: 빨강 = `0xff, 0x00, 0x00`)

### 방법 2: 커스텀 이미지 사용하기 (고급)

#### 1단계: 이미지 준비

- **형식**: PNG
- **권장 크기**: 800x480 픽셀
- **색상 모드**: RGB (24-bit)
- **디자인 팁**:
  - 중앙 하단에 진행 바를 위한 공간 확보
  - 단순하고 명확한 디자인 (빠른 부팅 시 잘 보이도록)
  - DES Cockpit 로고나 브랜딩 요소 포함

#### 2단계: PSplash 헤더로 변환

```bash
cd meta-custom/meta-env/recipes-core/psplash
./create_splash.sh your_splash_image.png psplash/psplash-poky-img.h
```

**필수 도구 설치** (처음 한 번만):
```bash
sudo apt-get install imagemagick
```

#### 3단계: 이미지 재빌드

```bash
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake -c cleansstate psplash
bitbake des-image
```

## 디자인 예시

### 예시 1: 단순 로고 + 텍스트
```
┌──────────────────────────────────┐
│                                  │
│        [DES Cockpit Logo]        │
│                                  │
│      Automotive Infotainment     │
│                                  │
│     [Progress Bar ▓▓▓░░░░]      │
└──────────────────────────────────┘
```

### 예시 2: 그라디언트 배경 + 브랜딩
```
┌──────────────────────────────────┐
│  ░░░▒▒▒▓▓▓ Gradient BG ▓▓▓▒▒▒░░░ │
│                                  │
│            DES 2025              │
│     Head Unit System v1.0        │
│                                  │
│     [Progress Bar ▓▓▓▓░░░]       │
└──────────────────────────────────┘
```

## 고급 커스터마이제이션

### 부팅 시 표시되는 텍스트 변경

`conf/local.conf`에 추가:
```bash
SPLASH_IMAGES = "file://psplash-poky-img.h;outsuffix=default"
```

### 진행 바 위치/크기 조정

`psplash-poky-img.h`에서 매크로 추가:
```c
#define PSPLASH_IMG_SPLIT_NUMERATOR   5
#define PSPLASH_IMG_SPLIT_DENOMINATOR 6
```

### 애니메이션 효과 (고급)

PSplash는 기본적으로 애니메이션을 지원하지 않지만, Plymouth로 전환하면 가능합니다:

```bash
# des-image.bb에서
IMAGE_INSTALL:append = " plymouth plymouth-themes-spinner "
```

## 디버깅

### 부팅 스플래시가 표시되지 않는 경우

1. **커널 파라미터 확인**:
   ```bash
   # config.txt에 추가되어야 함
   console=tty1
   ```

2. **PSplash 서비스 상태 확인**:
   ```bash
   systemctl status psplash-start
   ```

3. **프레임버퍼 테스트**:
   ```bash
   cat /dev/urandom > /dev/fb0
   ```

### 색상이 이상하게 보이는 경우

- RGB 순서 확인 (BGR일 수도 있음)
- Gamma 설정 확인 (`config.txt`)

## 빌드 시간 최적화

PSplash만 재빌드:
```bash
bitbake -c cleansstate psplash
bitbake psplash
```

전체 이미지 재빌드 없이 테스트:
```bash
# SD 카드의 rootfs 파티션에 직접 복사
scp tmp-glibc/work/*/psplash/*/image/usr/bin/psplash root@raspberrypi:/usr/bin/
```

## 참고 자료

- **PSplash 문서**: https://git.yoctoproject.org/psplash
- **이미지 가이드라인**: 800x480, RGB, PNG
- **색상 도구**: https://htmlcolorcodes.com/

## 문제 해결

| 문제 | 해결 방법 |
|------|----------|
| 이미지가 깨져 보임 | 이미지 크기를 정확히 800x480으로 조정 |
| 텍스트가 안 보임 | 배경과 텍스트 색상 대비 확인 |
| 진행 바가 안 보임 | 하단 여백 확보 (최소 80px) |
| 부팅이 너무 빨라서 안 보임 | 정상입니다! 느린 부팅이 오히려 문제 |
