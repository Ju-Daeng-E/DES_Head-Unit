import QtQuick 2.15

Item {
    id: root
    anchors.fill: parent
    // Remove fixed dimensions, let it scale with parent

    property int actualSpeed: ViewModel.speed
    property int actualCapacity: ViewModel.capacity
    property string actualGear: ViewModel.driveMode

    Image {
        id: backGround
        source: "qrc:/asset/BackGround.png"
        sourceSize.height: 650
        sourceSize.width: 1024
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        anchors.topMargin: 0
        anchors.bottomMargin: 0
        fillMode: Image.PreserveAspectFit
    }

    LeftCluster {
        id: leftCluster
        // Use anchors instead of absolute positioning
        anchors {
            left: parent.left
            // 70/1920 ≈ 0.036
            top: parent.top
            // 205/1080 ≈ 0.19
        }
        // Scale the cluster size relative to parent
        width: parent.width * 0.42  // Approximate ratio
        height: parent.height * 0.69
        anchors.leftMargin: 23
        anchors.topMargin: 91

        speed: actualSpeed
    }

    RightCluster {
        id: rightCluster
        // Use anchors for right positioning
        anchors {
            right: parent.right
            rightMargin: parent.width * 0.046  // (1920-1027-800)/1920 ≈ 0.046
            top: parent.top
            topMargin: parent.height * 0.19    // Same as left cluster
        }
        // Scale the cluster size relative to parent
        width: parent.width * 0.42
        height: parent.height * 0.69

        capacity: actualCapacity
    }

    Item {
        id: middleSlot
        anchors {
            left: leftCluster.right
            right: rightCluster.left
            top: leftCluster.bottom
        }

        Gear {
            id: gear

            anchors.centerIn: middleSlot
            width: middleSlot.width * 2
            height: width * (380/450)

            gear: actualGear
        }
        height: parent.height* 0.12
        anchors.leftMargin: 3
        anchors.rightMargin: -3
        anchors.topMargin: -80  //슬롯 높이
    }

}
