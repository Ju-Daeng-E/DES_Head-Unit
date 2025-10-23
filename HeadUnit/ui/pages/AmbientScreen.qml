import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: ambientScreen

    signal backClicked()
    signal colorChanged(color selectedColor)
    signal brightnessChanged(real brightness)

    property color currentColor: "#8b5cf6"
    property real currentBrightness: 60

    property var colorPresets: [
        { name: "Purple", color: "#8b5cf6" },
        { name: "Blue", color: "#3b82f6" },
        { name: "Cyan", color: "#06b6d4" },
        { name: "Teal", color: "#14b8a6" },
        { name: "Green", color: "#10b981" },
        { name: "Lime", color: "#84cc16" },
        { name: "Yellow", color: "#f59e0b" },
        { name: "Orange", color: "#f97316" },
        { name: "Red", color: "#ef4444" },
        { name: "Pink", color: "#ec4899" },
        { name: "Rose", color: "#f43f5e" },
        { name: "Violet", color: "#a855f7" }
    ]

    property var zones: [
        { name: "All Zones", icon: "🌐" },
        { name: "Front", icon: "⬆️" },
        { name: "Back", icon: "⬇️" },
        { name: "Left", icon: "⬅️" },
        { name: "Right", icon: "➡️" }
    ]

    property int selectedZone: 0

    Rectangle {
        anchors.fill: parent
        color: "#000000"

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: "#0a0a0a"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24

                    Button {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44

                        background: Rectangle {
                            radius: 22
                            color: parent.hovered ? "#2a2a2a" : "#1a1a1a"
                            border.color: "#333333"
                            border.width: 1

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        contentItem: Text {
                            text: "‹"
                            color: "#FFFFFF"
                            font.pixelSize: 28
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: ambientScreen.backClicked()
                    }

                    Text {
                        Layout.leftMargin: 16
                        text: qsTr("Ambient Light")
                        color: "#FFFFFF"
                        font.pixelSize: 22
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "💡"
                        font.pixelSize: 24
                        color: "#fbbf24"
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 24

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 16

                        Text {
                            text: qsTr("Preview")
                            color: "#FFFFFF"
                            font.pixelSize: 16
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 20
                            color: "#0f0f0f"
                            border.color: "#333333"
                            border.width: 1

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * 0.7
                                height: parent.height * 0.6
                                radius: 16
                                color: Qt.rgba(currentColor.r, currentColor.g, currentColor.b, 0.12)
                                border.width: 3
                                border.color: Qt.rgba(currentColor.r, currentColor.g, currentColor.b, currentBrightness / 100)

                                Behavior on border.color {
                                    ColorAnimation { duration: 300 }
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 300 }
                                }

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    blurEnabled: true
                                    blur: 0.8
                                    blurMax: 32
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "🚗"
                                    font.pixelSize: 80
                                    opacity: 0.3
                                }
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 20
                                text: Math.round(currentBrightness) + "%"
                                color: "#FFFFFF"
                                font.pixelSize: 28
                            }
                        }

                        Text {
                            text: qsTr("Zones")
                            color: "#FFFFFF"
                            font.pixelSize: 16
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: zones

                                Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 50

                                    background: Rectangle {
                                        radius: 10
                                        color: selectedZone === index ? "#8b5cf6"
                                              : (parent.hovered ? "#2a2a2a" : "#1a1a1a")
                                        border.color: selectedZone === index ? "#a78bfa" : "#333333"
                                        border.width: 1

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    contentItem: RowLayout {
                                        spacing: 6

                                        Text {
                                            text: modelData.icon
                                            font.pixelSize: 16
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: modelData.name
                                            color: "#FFFFFF"
                                            font.pixelSize: 12
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }

                                    onClicked: selectedZone = index
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 340
                        Layout.fillHeight: true
                        spacing: 24

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: qsTr("Color")
                                color: "#FFFFFF"
                                font.pixelSize: 16
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                rowSpacing: 12
                                columnSpacing: 12

                                Repeater {
                                    model: colorPresets

                                    Rectangle {
                                        Layout.preferredWidth: 70
                                        Layout.preferredHeight: 70
                                        radius: 12
                                        color: modelData.color
                                        border.color: currentColor === modelData.color ? "#FFFFFF" : "transparent"
                                        border.width: 3
                                        scale: currentColor === modelData.color ? 1.05 : 1.0

                                        Behavior on scale {
                                            NumberAnimation { duration: 200 }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: 200 }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                ambientScreen.currentColor = modelData.color;
                                                ambientScreen.colorChanged(modelData.color);
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            color: "#FFFFFF"
                                            font.pixelSize: 28
                                            visible: currentColor === modelData.color
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: qsTr("Brightness")
                                    color: "#FFFFFF"
                                    font.pixelSize: 16
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: Math.round(currentBrightness) + "%"
                                    color: "#999999"
                                    font.pixelSize: 15
                                }
                            }

                            Slider {
                                id: brightnessSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                value: currentBrightness

                                onValueChanged: {
                                    ambientScreen.currentBrightness = value;
                                    ambientScreen.brightnessChanged(value);
                                }

                                background: Rectangle {
                                    x: brightnessSlider.leftPadding
                                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 200
                                    implicitHeight: 6
                                    width: brightnessSlider.availableWidth
                                    height: implicitHeight
                                    radius: 3
                                    color: "#333333"

                                    Rectangle {
                                        width: brightnessSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: ambientScreen.currentColor
                                        radius: 3
                                    }
                                }

                                handle: Rectangle {
                                    x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 12
                                    color: "#FFFFFF"
                                    border.color: ambientScreen.currentColor
                                    border.width: 3
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: qsTr("Quick Settings")
                                color: "#FFFFFF"
                                font.pixelSize: 16
                            }

                            Button {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50

                                background: Rectangle {
                                    radius: 10
                                    color: parent.hovered ? "#2a2a2a" : "#1a1a1a"
                                    border.color: "#333333"
                                    border.width: 1

                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                contentItem: Text {
                                    text: qsTr("Turn Off Lights")
                                    color: "#FFFFFF"
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    ambientScreen.currentBrightness = 0;
                                    ambientScreen.brightnessChanged(0);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
