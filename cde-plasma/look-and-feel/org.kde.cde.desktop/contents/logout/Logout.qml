/*
 * CDE Logout Dialog
 */

import QtQuick 2.8

import org.kde.plasma.private.sessions 2.0

Item {
    id: root
    height: screenGeometry.height
    width: screenGeometry.width

    signal logoutRequested()
    signal haltRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal cancelRequested()
    signal lockScreenRequested()

    // CDE Colors
    readonly property color cdeBackground: "#5C5F6A"
    readonly property color cdeFrame: "#AEB2C3"
    readonly property color cdeFrameLight: "#D4D7E2"
    readonly property color cdeFrameDark: "#5C5F6A"
    readonly property color cdeTitleBar: "#B24D7A"
    readonly property color cdeTextLight: "#FFFFFF"
    readonly property color cdeTextDark: "#000000"

    readonly property int windowWidth: 320
    readonly property int windowHeight: 200
    readonly property int borderWidth: 6
    readonly property int titleHeight: 26
    readonly property int buttonWidth: 80
    readonly property int buttonHeight: 26

    function sleepRequested() {
        root.suspendRequested(2);
    }

    function hibernateRequested() {
        root.suspendRequested(4);
    }

    property real timeout: 0
    property real remainingTime: 0

    property var currentAction: {
        switch (sdtype) {
            case ShutdownType.ShutdownTypeReboot:
                return root.rebootRequested;
            case ShutdownType.ShutdownTypeHalt:
                return root.haltRequested;
            default:
                return root.logoutRequested;
        }
    }

    onRemainingTimeChanged: {
        if (remainingTime <= 0) {
            root.currentAction();
        }
    }

    Timer {
        id: countDownTimer
        running: root.timeout > 0
        repeat: true
        interval: 1000
        onTriggered: {
            root.remainingTime -= 1
        }
    }

    Component.onCompleted: {
        if (root.timeout > 0) {
            root.remainingTime = root.timeout
        } else {
            root.currentAction()
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.cancelRequested()
    }

    // Darken background
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.5
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.cancelRequested()
    }

    // Bevel component
    component Bevel: Item {
        property bool raised: true
        property int size: 2
        readonly property color light: raised ? cdeFrameLight : cdeFrameDark
        readonly property color dark: raised ? cdeFrameDark : cdeFrameLight

        Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: size; color: light }
        Rectangle { anchors { top: parent.top; left: parent.left; bottom: parent.bottom } width: size; color: light }
        Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right } height: size; color: dark }
        Rectangle { anchors { top: parent.top; right: parent.right; bottom: parent.bottom } width: size; color: dark }
    }

    // CDE Button
    component CdeButton: Rectangle {
        id: btn
        property alias text: label.text
        property bool isDefault: false
        signal clicked()

        width: buttonWidth
        height: buttonHeight
        color: area.pressed ? Qt.darker(cdeFrame, 1.1) : cdeFrame

        Bevel { anchors.fill: parent; raised: !area.pressed; size: 2 }
        Text {
            id: label
            anchors.centerIn: parent
            color: cdeTextDark
            font.pixelSize: 13
            font.bold: btn.isDefault
        }
        MouseArea {
            id: area
            anchors.fill: parent
            onClicked: btn.clicked()
        }
    }

    // Main dialog window
    Rectangle {
        id: dialog
        width: windowWidth
        height: windowHeight
        anchors.centerIn: parent
        color: cdeFrame

        Bevel { anchors.fill: parent; raised: true; size: 2 }

        // Title bar
        Rectangle {
            id: titleBar
            x: borderWidth; y: borderWidth
            width: parent.width - borderWidth * 2
            height: titleHeight
            color: cdeTitleBar

            Bevel { anchors.fill: parent; raised: true; size: 1 }

            Text {
                anchors.centerIn: parent
                text: {
                    switch (sdtype) {
                        case ShutdownType.ShutdownTypeReboot: return "Restart Computer"
                        case ShutdownType.ShutdownTypeHalt: return "Shut Down"
                        default: return "Log Out"
                    }
                }
                color: cdeTextLight
                font { pixelSize: 13; bold: true }
            }
        }

        // Content
        Rectangle {
            id: content
            x: borderWidth
            y: titleBar.y + titleBar.height + 3
            width: parent.width - borderWidth * 2
            height: parent.height - y - borderWidth
            color: cdeFrame

            Bevel { anchors.fill: parent; raised: false; size: 1 }

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        switch (sdtype) {
                            case ShutdownType.ShutdownTypeReboot:
                                return "Restart the computer?"
                            case ShutdownType.ShutdownTypeHalt:
                                return "Shut down the computer?"
                            default:
                                return "Log out of the session?"
                        }
                    }
                    color: cdeTextDark
                    font.pixelSize: 14
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: countDownTimer.running
                    text: {
                        switch (sdtype) {
                            case ShutdownType.ShutdownTypeReboot:
                                return "Restarting in " + Math.floor(root.remainingTime) + " seconds..."
                            case ShutdownType.ShutdownTypeHalt:
                                return "Shutting down in " + Math.floor(root.remainingTime) + " seconds..."
                            default:
                                return "Logging out in " + Math.floor(root.remainingTime) + " seconds..."
                        }
                    }
                    color: cdeTextDark
                    font.pixelSize: 12
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    CdeButton {
                        text: "OK"
                        isDefault: true
                        onClicked: root.currentAction()
                    }

                    CdeButton {
                        text: "Cancel"
                        onClicked: root.cancelRequested()
                    }
                }
            }
        }
    }
}
