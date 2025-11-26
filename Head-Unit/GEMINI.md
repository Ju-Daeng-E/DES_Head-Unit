# Project Overview

This project is a head-unit infotainment system for vehicles, built using Qt 6 with C++ for the backend and QML for the frontend. It follows a Model-View-ViewModel (MVVM) architecture.

The application integrates several services, including:
- A music player
- Vehicle gear status display (via D-Bus)
- Weather information (via a REST API)
- Bluetooth connectivity for audio playback

The user interface is built with QML and includes screens for music, ambient lighting, climate control, and Bluetooth.

# Building and Running

## Dependencies
- Qt 6.9 or higher (Core, Gui, Quick, Quick Controls, Multimedia, Network, DBus, Bluetooth)
- FFmpeg
- A C++17 compatible compiler

## Build and Run Commands

1.  **Configure the project with CMake:**
    ```bash
    cmake -S . -B build/Desktop_Qt_6_9_3-Debug -DCMAKE_PREFIX_PATH=<path_to_qt_installation>
    ```

2.  **Build the project:**
    ```bash
    cmake --build build/Desktop_Qt_6_9_3-Debug
    ```

3.  **Run the application:**
    ```bash
    DES_GEAR_USE_SESSION_BUS=1 build/Desktop_Qt_6_9_3-Debug/HeadUnitApp
    ```
    The `DES_GEAR_USE_SESSION_BUS=1` environment variable is used for development to connect to the instrument cluster app on the same session bus.

# Development Conventions

- The project uses a Model-View-ViewModel (MVVM) architecture.
- The C++ backend provides services that are exposed to the QML frontend through a `ViewModel` class.
- Data is exposed to QML using `Q_PROPERTY` and signals/slots.
- The UI is defined in QML files located in the `ui` directory.
- Backend C++ code is located in the `src/backend` directory.