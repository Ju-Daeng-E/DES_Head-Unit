# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Qt 6 (QML + C++) based automotive head-unit infotainment application. Integrates music playback, ambient lighting, climate controls, and vehicle gear status into a unified UI with reusable C++ backend services.

## Build & Run Commands

### Build with CMake
```bash
cd Head-Unit
cmake -S . -B build/Desktop_Qt_6_9_3-Debug \
  -DCMAKE_PREFIX_PATH=/home/seame/Qt/6.9.3/gcc_64
cmake --build build/Desktop_Qt_6_9_3-Debug
```

### Run Application
```bash
# Development mode (session D-Bus for testing with Instrument Cluster)
DES_GEAR_USE_SESSION_BUS=1 build/Desktop_Qt_6_9_3-Debug/HeadUnitApp

# Production mode (system D-Bus for deployment)
build/Desktop_Qt_6_9_3-Debug/HeadUnitApp
```

### Clean Build
```bash
rm -rf build/
cmake -S . -B build/Desktop_Qt_6_9_3-Debug -DCMAKE_PREFIX_PATH=<your-qt-path>
cmake --build build/Desktop_Qt_6_9_3-Debug
```

## Architecture

### Three-Layer Design Pattern

**1. Backend Services Layer** (`src/backend/`)
- **Purpose**: Reusable C++ services exposing Qt properties and invokable methods to QML
- **Pattern**: Each service inherits `QObject`, uses `Q_PROPERTY` for reactive bindings, `Q_INVOKABLE` for QML-callable methods
- **Services**:
  - `MusicPlayer` (`backend/music/`): QMediaPlayer wrapper with playlist management for local audio files
  - `GearClient` (`backend/gear/`): D-Bus client for vehicle gear state via Instrument Cluster
  - `WeatherService` (`backend/weather/`): REST client for Open-Meteo weather API
  - `BluetoothManager` (`backend/bluetooth/`): Qt Bluetooth device discovery, pairing, and connection management
  - `BluetoothAudioPlayer` (`backend/bluetooth/`): AVRCP-style media control for Bluetooth audio streaming

**2. Application Lifecycle Layer** (`src/HeadUnit.*`)
- **HeadUnit class**: Owns QQmlApplicationEngine, instantiates backend services as shared_ptr, registers them to QML context
- **Initialization sequence**:
  1. Construct backend services (`_musicPlayer`, `_gearClient`, `_weatherService`, `_bluetoothManager`, `_bluetoothAudioPlayer`)
  2. Register ViewModel to QML context via `registerModel()`
  3. Register backend services via `setContextProperty()` in `loadQml()`
  4. Trigger async weather fetch via `QMetaObject::invokeMethod()`
  5. Load QML from qrc:/ resource or local file

**3. UI Layer** (`ui/`)
- **Pattern**: Component-based QML with StackView navigation
- **Structure**:
  - `main.qml`: Root ApplicationWindow with ambient glow effects, manages global state
  - `pages/`: Full-screen views (HomeScreen, MusicScreen, AmbientScreen, ClimateScreen, BluetoothScreen)
  - `components/`: Reusable widgets (GearSelector, VehicleInfoWidget, BackButton)
- **Data Flow**: Backend services → Q_PROPERTY bindings → QML reactive UI
- **Music Modes**: MusicScreen automatically switches between local file playback and Bluetooth audio based on connection state

### D-Bus Integration

**Service Contract**:
- **Service**: `com.des.vehicle`
- **Object Path**: `/com/des/vehicle/Gear`
- **Interface**: `com.des.vehicle.Gear`
- **Bus Selection**: Controlled by `DES_GEAR_USE_SESSION_BUS` environment variable
  - Set to `1`: Session bus (development, testing with local Instrument Cluster)
  - Unset: System bus (production, embedded deployment)

**Communication Flow**:
1. Instrument Cluster's `GearManager` registers D-Bus service and broadcasts `GearChanged` signals
2. Head-Unit's `GearClient` connects to same bus, subscribes to signals in `subscribeToSignals()`
3. Methods: `GetGear()` (query current), `RequestGear()` (async change request)
4. Signals: `GearChanged(gear, source, sequence)`, `GearRequestRejected(gear, reason)`

### Context Registration Pattern

All C++ backend objects are registered to QML via `QQmlContext::setContextProperty()`:

```cpp
// In HeadUnit::loadQml()
_engine->rootContext()->setContextProperty("musicPlayer", _musicPlayer.get());
_engine->rootContext()->setContextProperty("gearClient", _gearClient.get());
_engine->rootContext()->setContextProperty("weatherService", _weatherService.get());
_engine->rootContext()->setContextProperty("bluetoothManager", _bluetoothManager.get());
_engine->rootContext()->setContextProperty("bluetoothAudioPlayer", _bluetoothAudioPlayer.get());
_engine->rootContext()->setContextProperty("viewModel", &model);
```

In QML, these become global identifiers accessible anywhere:
```qml
// Direct property binding
Text { text: gearClient.currentGear }

// Invokable method calls
Button { onClicked: musicPlayer.play("song.mp3") }

// Signal connections
Connections {
    target: gearClient
    function onCurrentGearChanged() { /* react */ }
}
```

## Key Dependencies

- **Qt 6.9+**: Core, Gui, Widgets, Qml, Quick, Multimedia, Network, DBus, Bluetooth
- **Qt Multimedia Backend**: FFmpeg-based runtime for audio playback
- **Qt Bluetooth**: Device discovery, pairing, and Bluetooth audio streaming
- **Network**: Open-Meteo API for weather data
- **D-Bus**: Inter-process communication with Instrument Cluster

## Bluetooth Audio Feature

### Overview
The Head-Unit supports Bluetooth audio streaming, allowing users to play music from paired mobile devices. The system provides:
- Device discovery and scanning
- Bluetooth pairing and unpairing
- Connection management
- Media playback control (play, pause, next, previous)
- Track metadata display (title, artist, album)
- Album art support (when available)
- Automatic mode switching in MusicScreen

### Architecture
- **BluetoothManager**: Handles device scanning, pairing, and connection lifecycle
- **BluetoothAudioPlayer**: Manages media playback control and metadata
- **MusicScreen**: Automatically switches between local file playback and Bluetooth audio modes
- **BluetoothScreen**: Provides UI for device management (scan, pair, connect, disconnect, unpair)

### User Workflow
1. **Initial Setup**: Navigate to Bluetooth settings from HomeScreen
2. **Scan for Devices**: Tap "Scan" button to discover nearby Bluetooth devices
3. **Pair Device**: Select discovered device and tap "Pair"
4. **Connect**: Once paired, tap "Connect" to establish audio connection
5. **Play Music**: Open MusicScreen - it automatically switches to Bluetooth mode when device is connected
6. **Control Playback**: Use play/pause, next, previous buttons to control phone's music player
7. **View Metadata**: Track title, artist, and album information displayed automatically
8. **Disconnect**: Return to Bluetooth settings and tap "Disconnect" or "Unpair" to remove device

### Key QML Properties
```qml
// BluetoothManager
bluetoothManager.scanning: bool
bluetoothManager.bluetoothAvailable: bool
bluetoothManager.discoveredDevices: list
bluetoothManager.pairedDevices: list
bluetoothManager.connected: bool
bluetoothManager.connectedDeviceName: string

// BluetoothAudioPlayer
bluetoothAudioPlayer.playing: bool
bluetoothAudioPlayer.trackTitle: string
bluetoothAudioPlayer.trackArtist: string
bluetoothAudioPlayer.duration: qint64
bluetoothAudioPlayer.position: qint64
bluetoothAudioPlayer.hasAlbumArt: bool
```

## Development Patterns

### Adding New Backend Service

1. Create service class in `src/backend/<domain>/`
2. Inherit `QObject`, use `Q_OBJECT` macro
3. Expose state via `Q_PROPERTY` with getters and `NOTIFY` signals
4. Mark QML-callable methods with `Q_INVOKABLE`
5. Add to `HEADUNIT_SOURCES` and `HEADUNIT_HEADERS` in `CMakeLists.txt`
6. Instantiate in `HeadUnit` constructor, register in `loadQml()`

### Adding New QML Screen

1. Create `.qml` file in `ui/pages/`
2. Add to `QML_FILES` in `qt_add_qml_module()` in `CMakeLists.txt`
3. Create Component in `main.qml`
4. Add navigation trigger in HomeScreen or other entry point
5. Use `stackView.push()` for navigation, `stackView.pop()` for back

### Debugging QML Issues

- Check QML import errors: Clear `build/` directory and rebuild
- Verify context properties: `qDebug() << _engine->rootContext()->contextProperty("name")`
- Enable QML debugging: Set `QT_DEBUG_PLUGINS=1` environment variable (already in `main.cpp`)

### D-Bus Troubleshooting

- **Error**: `[GearClient] DBus interface invalid`
  - **Cause**: Instrument Cluster not running or wrong bus type
  - **Fix**: Start Instrument Cluster first, verify `DES_GEAR_USE_SESSION_BUS` matches
- **Check bus**: `dbus-monitor --session` (dev) or `dbus-monitor --system` (prod)
- **Verify service**: `qdbus --session com.des.vehicle` or `qdbus --system com.des.vehicle`

## Asset Management

- **Audio files**: Place MP3s in `design/assets/`, installed to `${CMAKE_INSTALL_DATADIR}/headunit/music`
- **MusicPlayer**: Auto-loads from `design/assets/` via `loadLibrary()`
- **Deployment**: `install(DIRECTORY design/assets/ ...)` in CMakeLists.txt handles packaging

## Yocto Integration

- Recipe path: `work/meta-custom/meta-app/recipes-des/headunit/headunit.bb`
- Source path: `${TOPDIR}/../../Head-Unit` (relative to Yocto build directory)
- Before `bitbake des-image`: Ensure changes committed/synced or handled by `do_prepare_sources`
- No need to rebuild Head-Unit separately before Yocto build

## Common Errors

| Symptom | Solution |
|---------|----------|
| `[GearClient] DBus interface invalid` | Verify Instrument Cluster running and bus type matches (`DES_GEAR_USE_SESSION_BUS`) |
| Music not playing | Check Qt Multimedia plugins installed, MP3s exist in `design/assets/` |
| Weather not updating | Verify network connectivity, check `curl` to Open-Meteo API, inspect logs |
| QML import errors | Clear `build/` directory: `rm -rf build/ && cmake --build build/` |
| Undefined reference during linking | Verify all sources in `HEADUNIT_SOURCES` and linked libraries in `target_link_libraries()` |

## Code Style

- **C++17**: Modern C++ with standard library containers, smart pointers (`std::shared_ptr`, `std::unique_ptr`)
- **Qt Naming**: Private members suffixed with `_` (e.g., `currentGear_`, `player_`)
- **Signals/Slots**: Use new connect syntax with lambdas where appropriate
- **QML**: PascalCase for component files, camelCase for properties and functions

## Qt Creator Integration

1. Open `CMakeLists.txt` via `File > Open File or Project...`
2. Configure with `Desktop Qt 6.9.x` kit
3. Add `DES_GEAR_USE_SESSION_BUS=1` to `Projects > Run > Environment`
4. Run Instrument Cluster app first, then run HeadUnitApp from Qt Creator
