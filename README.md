# DES Cockpit Workspace (Head‑Unit + Cluster + Yocto)

An integrated workspace that hosts three related parts:
- Head‑Unit: a Qt 6/QML application for the head unit UI.
- Instrument Cluster: a Qt 6/QML cluster app plus Arduino sketches and Pi helper scripts.
- Yocto: a full Yocto Project workspace to build deployable Raspberry Pi images.

This README focuses on using all three together so you can both run locally and build images with Yocto.

## Directory Structure

```
.
├── Head-Unit/                # Qt Head‑Unit application
│   ├── ui/                   # QML (main, pages, components)
│   ├── src/                  # C++ backends (gear, music, weather)
│   ├── design/assets/        # sample audio assets (.mp3)
│   └── CMakeLists.txt
├── DES_Instrument-Cluster/   # Instrument Cluster app + helpers
│   ├── Cluster-app/          # Qt 6/QML app (appIC)
│   ├── Arduino/              # speed sensor sketches
│   ├── Pi-controller/        # Raspberry Pi helper scripts
│   └── systemd/              # systemd unit files
├── yocto-workspace/          # Yocto Project workspace
│   ├── poky/
│   ├── meta-openembedded/
│   ├── meta-qt6/
│   ├── meta-raspberrypi/
│   └── meta-custom/
│       ├── meta-env/         # distro + image (des-image)
│       ├── meta-app/         # headunit + instrument-cluster recipes
│       └── meta-piracer/     # CAN + PiRacer controller recipes
└── .github/workflows/        # CI (Yocto + Qt builds)
```

## Architecture

- Head‑Unit and Instrument Cluster communicate over D‑Bus.
  - Service: `com.des.vehicle`
  - Object: `/com/des/vehicle/Gear`
  - Interface: `com.des.vehicle.Gear`
  - Methods: `GetGear()`, `RequestGear(quint8 gear, QString source)`
  - Signals: `GearChanged(quint8, QString, quint32)`, `GearRequestRejected(quint8, QString)`
- Dev runs typically use the session bus: set `DES_GEAR_USE_SESSION_BUS=1`.
- On device, system bus is used by default.

Optional diagram: `DES_Instrument-Cluster/.github/Architecture.drawio.png`.

## Getting Started

### Prerequisites
- Linux dev machine or Raspberry Pi 4B (64‑bit)
- Qt 6.5+ (Core, Gui, Widgets, Quick, Qml, Multimedia, Network, DBus)
- D‑Bus runtime; Wayland/Weston for on‑device UI
- For cluster sensor demo: Arduino Uno‑class board, LM363 speed sensor, CAN shield/HAT

## Build and Run (Local)

Head‑Unit via CMake
```sh
cmake -S Head-Unit -B headunit-build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/path/to/Qt/6.x/gcc_64
cmake --build headunit-build -- -j"$(nproc || echo 2)"
DES_GEAR_USE_SESSION_BUS=1 ./headunit-build/HeadUnitApp
```

Instrument Cluster (Docker helper)
```sh
cd DES_Instrument-Cluster/Cluster-app
# On ARM hosts:
cp ../build-tool/Dockerfile ./ && cp ../build-tool/Makefile ./
# On x86 hosts (cross to aarch64):
# cp ../build-tool/Dockerfile.x86 ./Dockerfile && cp ../build-tool/Makefile.x86 ./Makefile && cp ../build-tool/toolchain-aarch64.cmake ./
make            # build inside Docker
# make run      # optional: deploy to Pi and run ~/appIC
```

Tip: Start the Cluster first so the D‑Bus service is registered, then run Head‑Unit.

## Yocto Build (Raspberry Pi Image)

Environment
```sh
cd yocto-workspace
. poky/oe-init-build-env build-des
```

Build just the app package
```sh
bitbake headunit
```

Build the full image
```sh
BITBAKE_IMAGE=des-image
bitbake ${BITBAKE_IMAGE}
```

Artifacts
- Images under: `yocto-workspace/build-des/tmp-glibc/deploy/images/raspberrypi4-64/`
- Packages (rpm/deb/ipk) under the respective deploy subfolders

Key custom layers
- `meta-custom/meta-env`: distro config (`des.conf`) and `des-image.bb`
- `meta-custom/meta-app`: `headunit.bb`, `instrument-cluster.bb` and their systemd units
- `meta-custom/meta-piracer`: CAN interface units (`can0.service`, `can1.service`) and `piracer-controller`

## Systemd Services (on device)
- Head‑Unit: `headunit.service` → launches `/usr/bin/HeadUnitApp -platform wayland`
- Instrument Cluster: `instrument-cluster.service` → launches `/usr/bin/appIC`
- CAN bring‑up: `can0.service`, `can1.service`
- PiRacer: `piracer-controller.service`

All are installed/enabled by their Yocto recipes.

## CI
- Workflow: `.github/workflows/yocto-ci.yml`
- Jobs:
  - Parse metadata and optional full image builds on a self‑hosted runner
  - Per‑recipe build for `headunit`
  - Optional CMake build using Yocto eSDK toolchain for quick verification

## Contributing
- Pull requests and issues are welcome.

## License
- MIT License (if applicable; see LICENSE if present)

## Authors
