import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: rootWindow
    visible: true
    width: 1024
    height: 600
    title: qsTr("HeadUnit Console")
    color: "transparent"

    property bool showingMusic: false

    function openMusic() {
        showingMusic = true
    }

    function goHome() {
        showingMusic = false
    }

    function formattedTrackTitle(fileName) {
        if (!fileName || fileName.length === 0)
            return qsTr("No track selected");
        var base = fileName;
        var dot = base.lastIndexOf(".");
        if (dot > 0)
            base = base.substring(0, dot);
        var parts = base.split("-");
        if (parts.length > 1)
            base = parts.slice(1).join("-");
        return base.replace(/_/g, " ").trim();
    }

    function formattedTrackArtist(fileName) {
        if (!fileName || fileName.length === 0)
            return qsTr("Unknown artist");
        var parts = fileName.split("-");
        if (parts.length < 2)
            return qsTr("Unknown artist");
        return parts[0].replace(/_/g, " ").trim();
    }

    function formatTime(ms) {
        if (!ms || ms <= 0)
            return "00:00";
        var totalSeconds = Math.floor(ms / 1000);
        var minutes = Math.floor(totalSeconds / 60);
        var seconds = totalSeconds % 60;
        return (minutes < 10 ? "0" + minutes : "" + minutes)
                + ":" + (seconds < 10 ? "0" + seconds : "" + seconds);
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#161c2e" }
            GradientStop { position: 1.0; color: "#0a0f1d" }
        }
    }

    Item {
        id: dashboard
        anchors.fill: parent
        visible: !showingMusic

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 24

            RowLayout {
                Layout.fillWidth: true

                Column {
                    spacing: 6
                    Text {
                        text: qsTr("Welcome back")
                        color: "#94a3b8"
                        font.pixelSize: 18
                    }
                    Text {
                        text: qsTr("Head Unit Control Center")
                        color: "#f8fafc"
                        font.pixelSize: 32
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 240
                    height: 90
                    radius: 20
                    color: "#101926"
                    border.color: "#253048"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 24

                        Column {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 90
                            spacing: 4
                            Text {
                                text: qsTr("Ambient")
                                color: "#a8b3c7"
                                font.pixelSize: 12
                                font.letterSpacing: 1.5
                            }
                            Text {
                                text: viewModel ? viewModel.ambientLightLevel : 0
                                color: "#f8fafc"
                                font.pixelSize: 26
                                font.weight: Font.Bold
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            width: 1
                            color: "#2e3a52"
                            opacity: 0.7
                        }

                        Column {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 110
                            spacing: 4
                            Text {
                                text: qsTr("Drive")
                                color: "#a8b3c7"
                                font.pixelSize: 12
                                font.letterSpacing: 1.5
                            }
                            Text {
                                text: (viewModel ? viewModel.driveMode : "NEUTRAL")
                                color: "#38bdf8"
                                font.pixelSize: 24
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignRight
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            GridLayout {
                id: tileGrid
                columns: 4
                rowSpacing: 18
                columnSpacing: 18
                Layout.fillWidth: true
                Layout.preferredHeight: 260

                Item {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 180

                    Rectangle {
                        id: musicTile
                        anchors.fill: parent
                        radius: 22
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#4338ca" }
                            GradientStop { position: 1.0; color: "#2e1065" }
                        }
                        border.color: "#4f46e5"
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 12

                            Item {
                                id: noteIcon
                                width: 56
                                height: 72

                                Rectangle {
                                    width: 14
                                    height: 54
                                    radius: 7
                                    color: "#f8fafc"
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                }
                                Rectangle {
                                    width: 34
                                    height: 10
                                    radius: 5
                                    color: "#c7d2fe"
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 36
                                }
                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: "#38bdf8"
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: -8
                                }
                            }

                            Text {
                                text: qsTr("Music Player")
                                color: "#f8fafc"
                                font.pixelSize: 22
                                font.bold: true
                            }
                            Text {
                                text: qsTr("Dive into playlists")
                                color: "#c7d2fe"
                                font.pixelSize: 14
                            }

                            Item { Layout.fillHeight: true }

                            Rectangle {
                                width: 44
                                height: 6
                                radius: 3
                                color: "#c7d2fe"
                                opacity: 0.7
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootWindow.openMusic()
                        }
                    }
                }

                Repeater {
                    model: 3
                    delegate: Item {
                        Layout.preferredWidth: 200
                        Layout.preferredHeight: 180

                        Rectangle {
                            anchors.fill: parent
                            radius: 22
                            color: "#1e293b"
                            border.color: "#334155"

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: index === 0 ? qsTr("Navigation")
                                         : index === 1 ? qsTr("Climate")
                                         : qsTr("Settings")
                                    color: "#94a3b8"
                                    font.pixelSize: 18
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Text {
                                    text: index === 0 ? qsTr("Coming soon")
                                         : index === 1 ? qsTr("Adjust temps")
                                         : qsTr("Vehicle preferences")
                                    color: "#64748b"
                                    font.pixelSize: 14
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 140
                radius: 22
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#0f172a" }
                    GradientStop { position: 1.0; color: "#111c32" }
                }
                border.color: "#1f2b44"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 18

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Quick status")
                            color: "#a8b3c7"
                            font.pixelSize: 16
                            font.weight: Font.Medium
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: musicPlayer && musicPlayer.playing ? "#22c55e" : "#f97316"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: musicPlayer && musicPlayer.playing ? qsTr("Playing") : qsTr("Paused")
                            color: "#e2e8f0"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 28

                    Column {
                        Layout.fillWidth: true
                        spacing: 10

                        Column {
                            spacing: 4
                            Text {
                                text: qsTr("Current track")
                                color: "#64748b"
                                font.pixelSize: 14
                            }
                            Text {
                                text: musicPlayer && musicPlayer.currentTrack.length
                                      ? formattedTrackTitle(musicPlayer.currentTrack)
                                      : qsTr("No track selected")
                                color: "#f8fafc"
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                text: musicPlayer && musicPlayer.currentTrack.length
                                      ? formattedTrackArtist(musicPlayer.currentTrack)
                                      : qsTr("Unknown artist")
                                color: "#94a3b8"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                        }

                        RowLayout {
                            spacing: 12
                            enabled: musicPlayer && musicPlayer.tracks.length > 0

                            ToolButton {
                                id: quickPrev
                                hoverEnabled: true
                                onClicked: musicPlayer.previous()
                                contentItem: Text {
                                    text: "<<"
                                    color: quickPrev.hovered ? "#f8fafc" : "#cbd5f5"
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                }
                                background: Rectangle {
                                    implicitWidth: 48
                                    implicitHeight: 40
                                    radius: 12
                                    color: quickPrev.hovered ? "#243047" : "#1b2536"
                                    border.color: "#2c3a56"
                                }
                            }

                            ToolButton {
                                id: quickToggle
                                hoverEnabled: true
                                onClicked: musicPlayer && musicPlayer.playing ? musicPlayer.pause() : musicPlayer.play()
                                contentItem: Text {
                                    text: musicPlayer && musicPlayer.playing ? qsTr("Pause") : qsTr("Play")
                                    color: quickToggle.hovered ? "#0f172a" : "#f8fafc"
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }
                                background: Rectangle {
                                    implicitWidth: 80
                                    implicitHeight: 40
                                    radius: 12
                                    color: quickToggle.hovered ? "#f8fafc" : "#22c55e"
                                    border.color: quickToggle.hovered ? "#cbd5f5" : "#16a34a"
                                }
                            }

                            ToolButton {
                                id: quickNext
                                hoverEnabled: true
                                onClicked: musicPlayer.next()
                                contentItem: Text {
                                    text: ">>"
                                    color: quickNext.hovered ? "#f8fafc" : "#cbd5f5"
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                }
                                background: Rectangle {
                                    implicitWidth: 48
                                    implicitHeight: 40
                                    radius: 12
                                    color: quickNext.hovered ? "#243047" : "#1b2536"
                                    border.color: "#2c3a56"
                                }
                            }
                        }
                    }

                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        Rectangle {
                            width: 260
                            height: 12
                            radius: 6
                            color: "#1e293b"
                            border.color: "#23324a"

                            Rectangle {
                                width: parent.width * (musicPlayer ? musicPlayer.progress : 0.0)
                                height: parent.height
                                radius: parent.radius
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#38bdf8" }
                                    GradientStop { position: 1.0; color: "#4f46e5" }
                                }
                                Behavior on width {
                                    NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
                                }
                            }
                        }

                        RowLayout {
                            width: 260
                            spacing: 0

                            Text {
                                text: formatTime(musicPlayer ? musicPlayer.position : 0)
                                color: "#94a3b8"
                                font.pixelSize: 12
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: formatTime(musicPlayer ? musicPlayer.duration : 0)
                                color: "#94a3b8"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
                }
            }
        }
    }

    Loader {
        id: musicLoader
        anchors.fill: parent
        active: showingMusic
        visible: showingMusic
        source: showingMusic ? "pages/music.qml" : ""
        onLoaded: {
            if (item && ("anchors" in item)) {
                item.anchors.fill = parent
            }
            if (item && item.hasOwnProperty("onNavigateHome")) {
                item.onNavigateHome = rootWindow.goHome
            }
        }
    }

    ToolButton {
        id: homeButton
        visible: showingMusic
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 20
        z: 30
        hoverEnabled: true
        onClicked: rootWindow.goHome()
        contentItem: Text {
            text: "\u2302"
            color: homeButton.hovered ? "#0f172a" : "#cbd5f5"
            font.pixelSize: 20
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            implicitWidth: 52
            implicitHeight: 52
            radius: 18
            color: homeButton.hovered ? "#cbd5f5" : "#1b2536"
            border.color: "#2c3a56"
            border.width: 1
        }
    }
}
