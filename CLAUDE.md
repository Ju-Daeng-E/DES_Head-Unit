# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DES Cockpit Workspace: Integrated development environment for two Qt 6 applications (Instrument Cluster and Head-Unit) with Yocto build system for Raspberry Pi 4 deployment. The applications communicate via D-Bus for real-time vehicle state synchronization.

**Technology Stack**: Qt 6.9+ (QML + C++17), Yocto Project, D-Bus IPC, CAN bus integration, systemd

## Build Commands

### Local Development (Laptop)

**Instrument Cluster (appIC)**
```bash
cd DES_Instrument-Cluster/Cluster-app
cmake -S . -B build -DCMAKE_PREFIX_PATH=/path/to/Qt/6.9.3/gcc_64
cmake --build build
DES_GEAR_USE_SESSION_BUS=1 build/appIC
```

**Head-Unit**
```bash
cd Head-Unit
cmake -S . -B build -DCMAKE_PREFIX_PATH=/path/to/Qt/6.9.3/gcc_64
cmake --build build
DES_GEAR_USE_SESSION_BUS=1 build/HeadUnitApp
```

**Important**: Always start Instrument Cluster BEFORE Head-Unit to ensure D-Bus service registration.

### Yocto Build (Raspberry Pi 4)

```bash
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake des-image
```

**Build artifacts**: `build-des/tmp-glibc/deploy/images/raspberrypi4-64/`

**Clean rebuild**:
```bash
bitbake -c cleanall headunit instrument-cluster
bitbake des-image
```

## D-Bus Architecture

**Critical**: The entire vehicle state synchronization relies on D-Bus IPC between applications.

### Service Registration (Instrument Cluster)
- **Service**: `com.des.vehicle`
- **Object**: `/com/des/vehicle/Gear`
- **Interface**: `com.des.vehicle.Gear`
- **Provider**: `GearManager` class in Cluster-app (`src/module/GearManager.cpp`)

### Client Connection (Head-Unit)
- **Consumer**: `GearClient` class in Head-Unit (`src/backend/gear/gear_client.cpp`)
- **Methods**: `GetGear() -> [quint8, quint32]`, `RequestGear(quint8, QString)`
- **Signals**: `GearChanged(quint8, QString, quint32)`, `GearRequestRejected(quint8, QString)`

### Environment Configuration
- **Development**: `DES_GEAR_USE_SESSION_BUS=1` → session bus
- **Production**: No env var → system bus with policy enforcement

### Debugging D-Bus
```bash
# Session bus (development)
busctl --user list | grep com.des.vehicle
busctl --user introspect com.des.vehicle /com/des/vehicle/Gear

# System bus (production)
busctl --system list | grep com.des.vehicle
```

## Code Architecture

### Instrument Cluster (DES_Instrument-Cluster/Cluster-app/)

**Core Classes**:
- `InstrumentCluster`: Application orchestrator, QML engine initialization
- `ViewModel`: Q_PROPERTY bridge to QML layer, timer-driven updates
- `GearManager`: D-Bus service provider, vehicle state authority
- `SharedMemory`: IPC mechanism for vehicle telemetry data
- `CanGateway`: CAN bus interface (can0/can1)
- `BatteryMonitor`/`INA219`: I2C battery monitoring via Adafruit INA219

**Data Flow**: CAN → SharedMemory → ViewModel → QML UI
               GearManager ↔ D-Bus ↔ GearClient (Head-Unit)

### Head-Unit (Head-Unit/)

**Core Classes**:
- `HeadUnit`: QML engine setup, context property registration
- `ViewModel`: Application state aggregator
- `GearClient`: D-Bus consumer for vehicle gear state
- `MusicPlayer`: QMediaPlayer wrapper with playlist management
- `WeatherService`: Open-Meteo API REST client with QNetworkAccessManager

**QML Structure**:
- `ui/main.qml`: Root navigation container
- `ui/pages/`: HomeScreen, MusicScreen, AmbientScreen, ClimateScreen
- `ui/components/`: GearSelector, VehicleInfoWidget, BackButton

**Data Flow**: GearClient ← D-Bus ← GearManager (Cluster)
               MusicPlayer → QML (Q_PROPERTY bindings)
               WeatherService → HTTP → Open-Meteo API

## Yocto Integration

### Recipe Locations
- **Head-Unit**: `meta-custom/meta-app/recipes-des/headunit/headunit.bb`
- **Instrument Cluster**: `meta-custom/meta-app/recipes-des/instrument-cluster/instrument-cluster.bb`
- **Image**: `meta-custom/meta-env/recipes-core/images/des-image.bb`

### Source Path Configuration
Both recipes reference source code via `${TOPDIR}/../../[App-Directory]`. Changes to application code require:
1. Commit changes to git (recipes may reference git)
2. OR ensure `do_prepare_sources` task copies latest sources

### systemd Services
- `headunit.service`: Starts Head-Unit on boot with Wayland environment
- `instrument-cluster.service`: Starts Cluster-app with D-Bus system bus
- `piracer-controller.service`: Vehicle control integration
- `can0.service`/`can1.service`: CAN interface initialization

## Common Development Patterns

### Adding Qt Properties to ViewModel
1. Add Q_PROPERTY declaration with NOTIFY signal
2. Implement getter/setter with emit signal on change
3. Register context property in main application class
4. Access from QML via `viewModel.propertyName`

### D-Bus Signal Subscription
```cpp
// In GearClient constructor
QDBusConnection::sessionBus().connect(
    "com.des.vehicle",
    "/com/des/vehicle/Gear",
    "com.des.vehicle.Gear",
    "GearChanged",
    this,
    SLOT(onGearChanged(quint8, QString, quint32))
);
```

### QML Module Registration
CMakeLists.txt uses `qt_add_qml_module()` with explicit QML_FILES and RESOURCES. Changes to QML file locations require CMakeLists.txt update and rebuild.

## Testing & Validation

### Manual Testing Workflow
1. Start Instrument Cluster in terminal 1
2. Verify D-Bus service registration: `busctl --user list | grep com.des.vehicle`
3. Start Head-Unit in terminal 2
4. Change gear in Cluster UI → verify Head-Unit gear display updates
5. Monitor D-Bus traffic: `dbus-monitor --session "interface='com.des.vehicle.Gear'"`

### Common Issues

| Symptom | Root Cause | Solution |
|---------|-----------|----------|
| `DBus interface invalid` | Cluster not running first, or bus mismatch | Check Cluster is running; verify both use same bus (session/system) |
| Music playback fails | Missing Qt Multimedia plugins or MP3 files | Install `gstreamer-plugins-good`, verify `design/assets/*.mp3` exist |
| QML import errors | Stale CMake cache or missing QML module | Delete `build/` directory, reconfigure CMake |
| Gear state not syncing | D-Bus signal not subscribed | Check `subscribeToSignals()` called in GearClient constructor |

## File Organization

### Build Artifacts
- `build/`, `build-*/`: CMake build directories (gitignored)
- `.qtc_clangd/`: Qt Creator language server cache (gitignored)
- `CMakeLists.txt.user`: Qt Creator project settings (gitignored)

### Design Assets
- `DES_Instrument-Cluster/Cluster-app/design/`: QML files and image assets
- `Head-Unit/design/assets/`: Sample audio files (MP3) for music player
- `Head-Unit/ui/`: QML UI components and pages

## Yocto-Specific Notes

### Layer Structure
- `meta-custom/meta-app/`: Application recipes (Cluster, Head-Unit)
- `meta-custom/meta-env/`: System configuration (D-Bus policies, images)
- `meta-custom/meta-piracer/`: Hardware integration (CAN, I2C, vehicle control)

### Recipe Modification Workflow
1. Edit `.bb` recipe file
2. Clean specific recipe: `bitbake -c cleansstate <recipe-name>`
3. Rebuild: `bitbake <recipe-name>`
4. Test in QEMU or deploy to Raspberry Pi

### D-Bus Policy Files
System bus policies defined in `meta-custom/meta-env/recipes-core/dbus/des-gear-dbus-config/` ensure security constraints for production deployment.
