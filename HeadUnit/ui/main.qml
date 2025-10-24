import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "pages"

ApplicationWindow {
    id: rootWindow
    width: 1024
    height: 600
    visible: true
    color: "#000000"
    title: qsTr("Head Unit Console")

    property var playerRef: musicPlayer
    property color ambientColor: "#8b5cf6"
    property real ambientBrightness: 0.6   // 0.0 ~ 1.0
    property string currentGear: "P"

    Component.onCompleted: {
        if (playerRef && playerRef.tracks.length === 0) {
            playerRef.loadLibrary();
        }
        if (viewModel) {
            ambientBrightness = Math.max(0, Math.min(1, viewModel.ambientLightLevel / 100.0));
            currentGear = mapDriveMode(viewModel.driveMode);
        }
    }

    function mapDriveMode(mode) {
        if (!mode)
            return "P";
        const upper = mode.toUpperCase();
        if (upper.startsWith("D"))
            return "D";
        if (upper.startsWith("R"))
            return "R";
        if (upper.startsWith("N"))
            return "N";
        return "P";
    }

    Connections {
        target: viewModel

        function onAmbientLightLevelChanged() {
            ambientBrightness = Math.max(0, Math.min(1, viewModel.ambientLightLevel / 100.0));
        }

        function onDriveModeChanged() {
            currentGear = mapDriveMode(viewModel.driveMode);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    Rectangle {
        id: glowPrimary
        width: 360
        height: 360
        radius: 180
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: parent.width * 0.25

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(ambientColor.r, ambientColor.g, ambientColor.b, ambientBrightness * 0.4)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(ambientColor.r, ambientColor.g, ambientColor.b, 0)
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 80
        }

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 28000
            loops: Animation.Infinite
            running: ambientBrightness > 0
        }
    }

    Rectangle {
        id: glowSecondary
        width: 340
        height: 340
        radius: 170
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: parent.width * 0.22

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(ambientColor.r * 0.9, ambientColor.g, ambientColor.b * 1.15, ambientBrightness * 0.32)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(ambientColor.r, ambientColor.g, ambientColor.b, 0)
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 80
        }

        RotationAnimation on rotation {
            from: 360
            to: 0
            duration: 24000
            loops: Animation.Infinite
            running: ambientBrightness > 0
        }
    }

    Rectangle {
        id: glowAccent
        width: 240
        height: 240
        radius: 120
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(ambientColor.r * 1.05, ambientColor.g * 0.95, ambientColor.b, ambientBrightness * 0.25)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(ambientColor.r, ambientColor.g, ambientColor.b, 0)
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 70
        }

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 32000
            loops: Animation.Infinite
            running: ambientBrightness > 0
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: homeScreen

        pushEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 280; easing.type: Easing.OutCubic }
            }
        }

        pushExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 220; easing.type: Easing.InCubic }
        }

        popEnter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
        }

        popExit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 220; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; from: 1.0; to: 0.96; duration: 220; easing.type: Easing.InCubic }
            }
        }
    }

    Component {
        id: homeScreen
        HomeScreen {
            musicPlayer: rootWindow.playerRef
            driveMode: viewModel ? viewModel.driveMode : "PARK"
            ambientColor: rootWindow.ambientColor
            ambientBrightness: rootWindow.ambientBrightness

            onOpenMusic: stackView.push(musicScreen)
            onOpenAmbient: stackView.push(ambientScreen)
            onOpenClimate: stackView.push(climateScreen)

            onGearChanged: function(gear) {
                rootWindow.currentGear = gear;
            }
        }
    }

    Component {
        id: musicScreen
        MusicScreen {
            musicPlayer: rootWindow.playerRef
            onBackClicked: stackView.pop()
        }
    }

    Component {
        id: ambientScreen
        AmbientScreen {
            currentColor: rootWindow.ambientColor
            currentBrightness: rootWindow.ambientBrightness * 100

            onColorChanged: function(color) {
                rootWindow.ambientColor = color;
            }

            onBrightnessChanged: function(level) {
                rootWindow.ambientBrightness = Math.max(0, Math.min(1, level / 100));
            }

            onBackClicked: stackView.pop()
        }
    }

    Component {
        id: climateScreen
        ClimateScreen {
            onBackClicked: stackView.pop()
        }
    }
}
