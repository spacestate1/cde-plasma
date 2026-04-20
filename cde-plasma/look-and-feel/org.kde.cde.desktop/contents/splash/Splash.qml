/*
 * CDE Splash Screen
 * Shows loading progress in a CDE-styled window
 */

import QtQuick 2.5

Rectangle {
    id: root
    color: "#5C5F6A"

    property int stage

    // CDE Colors
    readonly property color cdeFrame: "#AEB2C3"
    readonly property color cdeFrameLight: "#D4D7E2"
    readonly property color cdeFrameDark: "#5C5F6A"
    readonly property color cdeTitleBar: "#B24D7A"
    readonly property color cdeTextLight: "#FFFFFF"
    readonly property color cdeTextDark: "#000000"
    readonly property color cdeProgressFill: "#718BA5"

    readonly property int windowWidth: 340
    readonly property int windowHeight: 140
    readonly property int borderWidth: 6
    readonly property int titleHeight: 26

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

    // Main splash window
    Rectangle {
        id: splashWindow
        width: windowWidth
        height: windowHeight
        anchors.centerIn: parent
        color: cdeFrame
        opacity: 0

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
                text: "Loading Desktop"
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
                spacing: 12

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Starting Plasma Desktop..."
                    color: cdeTextDark
                    font.pixelSize: 13
                }

                // Progress bar container
                Rectangle {
                    width: 260
                    height: 22
                    color: cdeFrame
                    anchors.horizontalCenter: parent.horizontalCenter

                    Bevel { anchors.fill: parent; raised: false; size: 1 }

                    // Progress bar fill
                    Rectangle {
                        id: progressBar
                        x: 2
                        y: 2
                        width: 0
                        height: parent.height - 4
                        color: cdeProgressFill

                        Bevel { anchors.fill: parent; raised: true; size: 1 }

                        Behavior on width {
                            NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }
        }

        // Fade in animation
        OpacityAnimator {
            id: introAnimation
            running: false
            target: splashWindow
            from: 0
            to: 1
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    // Progress animation based on stage
    onStageChanged: {
        if (stage == 1) {
            introAnimation.running = true
            progressBar.width = 50
        } else if (stage == 2) {
            progressBar.width = 100
        } else if (stage == 3) {
            progressBar.width = 150
        } else if (stage == 4) {
            progressBar.width = 200
        } else if (stage == 5) {
            progressBar.width = 230
        } else if (stage == 6) {
            progressBar.width = 256
        }
    }

}
