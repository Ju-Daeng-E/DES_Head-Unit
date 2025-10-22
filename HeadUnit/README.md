# HeadUnit 미디어 플레이어 프로토타입

이 저장소는 간단한 차량용 헤드유닛(Media, 기본 홈 화면 등)을 Qt6/QML 기반으로 실험하기 위한 샘플입니다. C++ 백엔드에서 비즈니스 로직(재생, 상태 관리)을 처리하고 QML은 화면 구성에 집중하도록 분리되어 있습니다.

## 1. 디렉터리 구조
```
HeadUnit/
├── CMakeLists.txt           # Qt6용 CMake 설정
├── README.md                # 현재 문서
├── src/
│   ├── main.cpp             # 진입점, QGuiApplication + QML 로더
│   ├── HeadUnit.h/.cpp      # QML 엔진 초기화, 컨텍스트 주입, 타이머 유틸
│   ├── ViewModel.h/.cpp     # QML에서 읽는 상태 값 (Drive mode 등)
│   └── backend/
│       └── music/
│           ├── music_player.h/.cpp  # QMediaPlayer 래핑, 재생 제어
├── ui/
│   ├── main.qml             # 기본 홈 화면 (Music Player 버튼 포함)
│   └── pages/
│       └── music.qml        # 음악 플레이어 UI
├── design/assets/           # (선택) 오디오 파일, 이미지 등 리소스 배치 위치
└── build/                   # Qt Creator나 CMake 빌드 아웃풋 (생성될 수 있음)
```

## 2. 빌드 & 실행
Qt 6.9.3 Desktop Kit(또는 호환 버전)가 설치되어 있고 `QtMultimedia` 모듈이 추가되어 있어야 합니다.

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_PREFIX_PATH=/home/jeongmin/Qt/6.9.3/gcc_64
cmake --build .
./HeadUnitApp
```

- `CMAKE_PREFIX_PATH`는 Qt 설치 경로에 맞게 조정하세요.
- 실행 전 `design/assets/music`에 mp3/ogg 등 오디오 파일을 넣으면 `MusicPlayer`가 재생 목록을 자동으로 채웁니다.

## 3. 실행 흐름 요약
1. **main.cpp**
   - `QApplication`을 생성하고 `HeadUnit`과 `ViewModel` 인스턴스를 만듭니다.
   - `HeadUnit::registerModel`로 `viewModel`을 QML에서 접근 가능하도록 주입합니다.
   - `HeadUnit::loadQml`을 호출해 `qrc:/HeadUnit/ui/main.qml`을 로드합니다.

2. **HeadUnit**
   - `QQmlApplicationEngine`을 소유하고, `musicPlayer` 객체를 컨텍스트에 등록합니다.
   - `loadQml` 호출 시 `ApplicationWindow`(main.qml)가 올라오며 `Loader`를 통해 하위 페이지를 전환합니다.
   - 차량 센서 연동을 위한 타이머 관리 인터페이스가 구현돼 있습니다(현재는 사용 예시만 존재).

3. **ViewModel**
   - `driveMode`, `ambientLightLevel`, `musicPlaying` 등의 값과 시그널을 제공합니다.
   - `receiveTimeout()`을 timer 이름에 따라 분기해 각 상태 업데이트 함수를 호출하는 구조입니다.

4. **MusicPlayer (C++ 백엔드)**
   - `QMediaPlayer`와 `QAudioOutput`을 사용해 실제 오디오 재생을 담당합니다.
   - `loadLibrary()`가 음악 파일을 탐색하고, `play()`, `next()`, `previous()` 등 메서드를 통해 QML에서 제어합니다.
   - 재생 상태 변화는 `playingChanged`, `currentTrackChanged`, `playbackError` 시그널로 QML에 전달됩니다.

5. **QML UI**
   - `ui/main.qml`: 홈 화면. “Music Player” 버튼을 누르면 `Loader`가 `pages/music.qml`을 불러옵니다.
   - `ui/pages/music.qml`: 트랙리스트, 재생/일시정지, 이전/다음 버튼을 가진 간단한 음악 플레이어 화면입니다. `musicPlayer` 컨텍스트 객체를 사용합니다.

## 4. 커스텀 & 확장 아이디어
- **추가 페이지**: `ui/pages/`에 QML 파일을 만들고 `main.qml`의 버튼 또는 메뉴를 확장해 로딩할 수 있습니다.
- **재생목록 관리**: 현재는 디렉터리 스캔 결과만 사용합니다. JSON/YAML/DB 등을 활용해 메타데이터를 저장하는 방법을 고려할 수 있습니다.
- **테마/스타일**: `Qt Quick Controls` 테마나 `palette`를 적용해 다크/라이트 모드를 지원할 수 있습니다.
- **센서 연동**: `HeadUnit::connectTimerModel`에 실제 차량 데이터 소켓/버스를 연결해 `ViewModel`을 갱신하면 계기판, 조명, 기어 변환 등 다양한 기능을 넣을 수 있습니다.

## 5. 문제 해결
- **QML 파일을 찾지 못하는 경우**: 리소스 경로가 `qrc:/HeadUnit/...`로 노출되므로 `qt_add_qml_module`에 파일이 등록되어 있는지 확인합니다.
- **오디오가 재생되지 않는 경우**: Qt Multimedia 모듈 설치 여부, 오디오 파일 위치, 그리고 런타임 환경(사운드 백엔드) 설정을 점검하세요.
- **화면이 안 뜨는 경우**: QML 루트가 `ApplicationWindow`인지, `visible: true`가 설정됐는지 확인하세요.

## 6. 라이선스
원본 레포 그대로 MIT 라이선스입니다. 상세 조건은 기존 LICENSE 파일을 참고해 주세요.
