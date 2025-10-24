# HeadUnit – Qt 6 Connected Infotainment Prototype

이 프로젝트는 차량용 헤드유닛 UI를 Qt 6(QML + C++)로 구현한 모듈형 샘플입니다.  
음악 재생, 앰비언트 라이트, 기후·날씨 위젯을 분리된 QML 페이지로 구성하고, C++ 백엔드가 재사용 가능한 서비스(뮤직 플레이어, 날씨 API)를 제공합니다.

## 주요 화면

| 화면 | 역할 |
| --- | --- |
| **Home** | 현재 시간·기어 상태·차량 위젯, 음악·앰비언트·기후 카드 |
| **Music** | `QMediaPlayer` 기반 라이브러리 재생·플레이리스트 제어 |
| **Ambient Light** | 16가지 프리셋, 존별 하이라이트, 밝기 슬라이더, 퀵 액션 |
| **Climate Control** | 온도/팬 속도 조절, A/C/내기순환/성에 제거, Open‑Meteo API 날씨 |

## 아키텍처 개요

```
HeadUnit/
├── CMakeLists.txt
├── README.md                  # 현재 문서
├── src/
│   ├── main.cpp               # QApplication + HeadUnit 부트스트랩
│   ├── HeadUnit.h/.cpp        # QQmlApplicationEngine, 컨텍스트 주입
│   ├── ViewModel.h/.cpp       # 기어/앰비언트 상태 노출
│   └── backend/
│       ├── music/music_player.h/.cpp    # QMediaPlayer, 디렉터리 스캔
│       └── weather/weather_service.h/.cpp # Open‑Meteo REST 클라이언트
├── ui/
│   ├── main.qml               # ApplicationWindow, StackView
│   ├── components/            # BackButton, GearSelector, VehicleInfoWidget
│   └── pages/
│       ├── HomeScreen.qml
│       ├── MusicScreen.qml
│       ├── AmbientScreen.qml
│       └── ClimateScreen.qml
├── design/assets/             # 샘플 음악/이미지
└── build/                     # (생성물) CMake/Qt Creator 출력
```

## 빌드 & 실행

요구 사항

- Qt 6.9 이상 (Core, Gui, Quick, Quick Controls, Multimedia, Network)
- FFmpeg 기반 Qt Multimedia 런타임 (Qt 기본 제공)
- 인터넷 연결 (기상 정보 갱신 시)

### CMake

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_PREFIX_PATH=/home/jeongmin/Qt/6.9.3/gcc_64
cmake --build .
./HeadUnitApp
```

> `CMAKE_PREFIX_PATH` 는 Qt 설치 경로에 맞게 수정합니다.  
> `design/assets/`에 MP3 등을 추가하면 앱이 실행 시 자동으로 라이브러리를 채웁니다.

### Qt Creator

1. `CMakeLists.txt`를 열어 Kit(Qt 6 Desktop) 설정  
2. Configure > Build  
3. Run (네트워크가 허용된 환경에서 실행)

## 동작 요약

1. **main.cpp**
   - `QApplication` 생성 후 `HeadUnit`과 `ViewModel`을 초기화합니다.
   - `HeadUnit::registerModel("viewModel", model)` 로 QML에서 상태를 읽을 수 있게 합니다.
2. **HeadUnit**
   - `musicPlayer` / `weatherService` 인스턴스를 QML 컨텍스트에 주입합니다.
   - 초기 QML(`ui/main.qml`)을 로드하고 필요 시 에러를 감지해 프로세스를 종료합니다.
3. **ViewModel**
   - 기어/앰비언트 센서 값을 QML이 읽을 수 있는 property + signal로 노출합니다.
4. **MusicPlayer (C++)**
   - 디렉터리를 스캔해 트랙 리스트(`QStringList`)를 만들고 플레이/토글/다음 곡 등 메서드를 제공합니다.
5. **WeatherService (C++)**
   - Open‑Meteo REST API를 GET 요청으로 호출하고, 기온·습도·강수량 등 값을 Q_PROPERTY로 노출합니다.
6. **QML UI**
   - `ui/main.qml`은 StackView로 홈/음악/앰비언트/클라이밋 페이지를 전환합니다.
   - 각 페이지는 `musicPlayer`·`weatherService`·`viewModel`을 직접 사용합니다.

## 확장 포인트

- **센서 데이터** – `ViewModel`에 차량 CAN 신호를 연결해 속도·배터리 등을 동적 반영.
- **날씨 지역 변경** – `weather_service.cpp`의 `kLatitude/kLongitude` 값을 원하는 좌표로 변경.
- **테마** – `components/*`나 `pages/*`의 색상을 브랜드에 맞게 수정.
- **오디오 소스** – `music_player.cpp`의 라이브러리 경로 탐색 규칙을 커스터마이즈.
- **OTA/업데이트** – CI에서 `bitbake headunit`이나 패키지 빌드를 돌려 Yocto 이미지에 통합.

## 트러블슈팅

| 상황 | 해결 |
| --- | --- |
| 앱이 바로 종료됨 | 콘솔 로그 확인 (`QML debugging is enabled...`). QML 로딩 실패 시 `HeadUnit.cpp`에서 `EXIT_FAILURE`로 종료합니다. |
| 음악이 안 나옴 | Qt Multimedia 모듈 설치, ALSA/Pulse 환경 확인, `design/assets/` 경로에 MP3 존재 여부 체크 |
| 날씨가 계속 “Updating…” 상태 | 네트워크 연결 또는 Open‑Meteo API 응답 확인 (`curl http://api.open-meteo.com/...`). 실패 메시지는 빨간 글자로 표시됩니다. |
| QML import 오류 | `cmake --build`가 생성하는 `.rcc/qmlcache`를 비워주거나 `build/` 디렉터리를 삭제 후 재빌드 |

## 라이선스

MIT License. 자세한 조건은 루트의 `LICENSE` 파일을 확인하세요.

