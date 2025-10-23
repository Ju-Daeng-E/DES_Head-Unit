import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

ApplicationWindow {
    id: rootWindow
    width: 1024
    height: 600
    visible: true
    color: "#000000"
    title: qsTr("Head Unit Console")

    property color ambientColor: "#8b5cf6"
    property real ambientBrightness: 0.6   // 0.0 ~ 1.0
    property var playerRef: musicPlayer

    Component.onCompleted: {
        if (playerRef) {
            playerRef.loadLibrary();
        }
    }

    Connections {
        target: playerRef
        onTracksChanged: {
            if (playerRef.tracks.length > 0 && !playerRef.currentTrack) {
                playerRef.play(playerRef.tracks[0]);
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: parent.width * 0.22
        anchors.top: parent.top
        width: 320
        height: 320
        radius: 160
        color: Qt.rgba(ambientColor.r, ambientColor.g, ambientColor.b, ambientBrightness * 0.35)

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
        }

        Behavior on color {
            ColorAnimation { duration: 600 }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: parent.width * 0.22
        anchors.bottom: parent.bottom
        width: 320
        height: 320
        radius: 160
        color: Qt.rgba(ambientColor.r, ambientColor.g, ambientColor.b, ambientBrightness * 0.25)

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
        }

        Behavior on color {
            ColorAnimation { duration: 600 }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 220
        height: 220
        radius: 110
        color: Qt.rgba(ambientColor.r, ambientColor.g, ambientColor.b, ambientBrightness * 0.18)

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
        }

        Behavior on color {
            ColorAnimation { duration: 600 }
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: homeScreen

        pushEnter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250 }
        }
        pushExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 200 }
        }
        popEnter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250 }
        }
        popExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 200 }
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
}
