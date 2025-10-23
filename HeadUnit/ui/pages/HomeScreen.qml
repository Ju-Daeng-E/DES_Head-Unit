import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: homeScreen

    signal openMusic()
    signal openAmbient()

    property var musicPlayer
    property string driveMode: "PARK"
    property color ambientColor: "#8b5cf6"
    property real ambientBrightness: 0.6

    readonly property string _currentTrack: musicPlayer ? musicPlayer.currentTrack : ""

    function stripExtension(str) {
        if (!str)
            return "";
        const idx = str.lastIndexOf(".");
        return idx > -1 ? str.substring(0, idx) : str;
    }

    function trackArtist(fileName) {
        if (!fileName)
            return qsTr("Unknown artist");
        const parts = fileName.split("-");
        if (parts.length < 2)
            return qsTr("Unknown artist");
        return parts[0].replace(/_/g, " ").trim();
    }

    function trackTitle(fileName) {
        if (!fileName)
            return qsTr("No track selected");
        const parts = fileName.split("-");
        if (parts.length < 2)
            return stripExtension(fileName).replace(/_/g, " ").trim();
        return stripExtension(parts.slice(1).join("-")).replace(/_/g, " ").trim();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            timeText.text = Qt.formatTime(now, "hh:mm");
            dateText.text = Qt.formatDate(now, "dddd, MMMM d");
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 2

                Text {
                    id: timeText
                    color: "#FFFFFF"
                    font.pixelSize: 42
                    text: Qt.formatTime(new Date(), "hh:mm")
                }

                Text {
                    id: dateText
                    color: "#999999"
                    font.pixelSize: 14
                    text: Qt.formatDate(new Date(), "dddd, MMMM d")
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 140
                height: 36
                radius: 18
                color: "#1a1a1a"
                border.color: "#333333"
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "⏸"
                        color: "#999999"
                        font.pixelSize: 14
                    }

                    Text {
                        text: driveMode.length ? driveMode : qsTr("PARK")
                        color: "#999999"
                        font.pixelSize: 13
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rows: 2
            columnSpacing: 16
            rowSpacing: 16

            Rectangle {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: 16
                color: "#1a1a1a"
                border.color: "#333333"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "⏱"
                                font.pixelSize: 28
                                color: "#60a5fa"
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "0"
                                color: "#FFFFFF"
                                font.pixelSize: 32
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "km/h"
                                color: "#666666"
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        Layout.topMargin: 16
                        Layout.bottomMargin: 16
                        color: "#333333"
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "🔋"
                                font.pixelSize: 28
                                color: "#10b981"
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "78%"
                                color: "#FFFFFF"
                                font.pixelSize: 32
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("Battery")
                                color: "#666666"
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        Layout.topMargin: 16
                        Layout.bottomMargin: 16
                        color: "#333333"
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "⛽"
                                font.pixelSize: 28
                                color: "#fb923c"
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "420"
                                color: "#FFFFFF"
                                font.pixelSize: 32
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("km range")
                                color: "#666666"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: 16
                color: "#1a1a1a"
                border.color: "#333333"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "💨"
                            font.pixelSize: 18
                            color: "#60a5fa"
                        }

                        Text {
                            text: qsTr("Climate")
                            color: "#FFFFFF"
                            font.pixelSize: 14
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("22°C")
                        color: "#FFFFFF"
                        font.pixelSize: 36
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            Rectangle {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: 16
                color: musicMouse.containsMouse ? "#252525" : "#1a1a1a"
                border.color: "#333333"
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }

                MouseArea {
                    id: musicMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: homeScreen.openMusic()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    Rectangle {
                        width: 100
                        height: 100
                        radius: 12
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#a855f7" }
                            GradientStop { position: 1.0; color: "#ec4899" }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "🎵"
                            font.pixelSize: 44
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: qsTr("Music")
                            color: "#FFFFFF"
                            font.pixelSize: 18
                        }

                        Text {
                            text: trackTitle(_currentTrack)
                            color: "#CCCCCC"
                            font.pixelSize: 15
                            elide: Text.ElideRight
                        }

                        Text {
                            text: trackArtist(_currentTrack)
                            color: "#666666"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        Item { Layout.fillHeight: true }
                    }

                    Text {
                        text: "›"
                        color: "#666666"
                        font.pixelSize: 32
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: 16
                color: ambientMouse.containsMouse ? "#252525" : "#1a1a1a"
                border.color: "#333333"
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }

                MouseArea {
                    id: ambientMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: homeScreen.openAmbient()
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Text {
                            text: "💡"
                            font.pixelSize: 20
                            color: "#fbbf24"
                        }

                        Text {
                            text: qsTr("Ambient")
                            color: "#FFFFFF"
                            font.pixelSize: 14
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 60
                        height: 60
                        radius: 30
                        color: ambientColor
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(ambientBrightness * 100) + "%"
                        color: "#666666"
                        font.pixelSize: 12
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
