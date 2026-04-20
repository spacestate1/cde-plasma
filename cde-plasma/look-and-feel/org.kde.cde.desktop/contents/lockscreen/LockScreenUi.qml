/*
 * CDE Lock Screen Theme for Plasma 6
 * Matches the SDDM login theme styling
 */

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    // CDE Color Palette (matches SDDM theme)
    readonly property color cdeBackground: "#5C5F6A"
    readonly property color cdeFrame: "#AEB2C3"
    readonly property color cdeFrameLight: "#D4D7E2"
    readonly property color cdeFrameDark: "#5C5F6A"
    readonly property color cdeTitleBar: "#B24D7A"
    readonly property color cdeTextLight: "#FFFFFF"
    readonly property color cdeTextDark: "#000000"
    readonly property color cdeInputBg: "#FFFFFF"
    readonly property color cdeError: "#CC0000"

    // Layout metrics (matches SDDM theme)
    readonly property int windowWidth: 400
    readonly property int windowHeight: 220
    readonly property int borderWidth: 6
    readonly property int titleHeight: 26
    readonly property int fieldHeight: 26
    readonly property int labelWidth: 80
    readonly property int fieldGap: 10
    readonly property int padding: 14
    readonly property int buttonWidth: 80
    readonly property int buttonGap: 12

    property string failMessage: ""

    Rectangle {
        anchors.fill: parent
        color: cdeBackground
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

    // CDE-style button component
    component CdeButton: Rectangle {
        id: btn
        property alias text: label.text
        signal clicked()

        width: buttonWidth
        height: fieldHeight
        color: area.pressed ? Qt.darker(cdeFrame, 1.1) : cdeFrame

        Bevel { anchors.fill: parent; raised: !area.pressed; size: 2 }
        Text { id: label; anchors.centerIn: parent; color: cdeTextDark; font.pixelSize: 13 }
        MouseArea { id: area; anchors.fill: parent; onClicked: btn.clicked() }
    }

    // Main lock window
    Rectangle {
        id: lockWindow
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
                text: "Screen Locked"
                color: cdeTextLight
                font { pixelSize: 13; bold: true }
            }
        }

        // Content area
        Rectangle {
            id: content
            x: borderWidth
            y: titleBar.y + titleBar.height + 3
            width: parent.width - borderWidth * 2
            height: parent.height - y - borderWidth
            color: cdeFrame

            Bevel { anchors.fill: parent; raised: false; size: 1 }

            Item {
                id: form
                anchors { fill: parent; margins: padding }

                readonly property int fieldWidth: width - labelWidth - fieldGap

                // User info
                Text {
                    id: userLabel
                    x: 0; y: 0; width: labelWidth; height: fieldHeight
                    text: "User:"
                    color: cdeTextDark; font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                }
                Text {
                    x: labelWidth + fieldGap; y: 0
                    width: form.fieldWidth; height: fieldHeight
                    text: kscreenlocker_userName
                    color: cdeTextDark; font { pixelSize: 13; bold: true }
                    verticalAlignment: Text.AlignVCenter
                }

                // Password row
                Text {
                    x: 0; y: fieldHeight + 10
                    width: labelWidth; height: fieldHeight
                    text: "Password:"
                    color: cdeTextDark; font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                }
                Rectangle {
                    x: labelWidth + fieldGap; y: fieldHeight + 10
                    width: form.fieldWidth; height: fieldHeight
                    color: cdeInputBg

                    Bevel { anchors.fill: parent; raised: false; size: 1 }
                    TextInput {
                        id: passwordInput
                        anchors { fill: parent; margins: 5 }
                        echoMode: TextInput.Password
                        font.pixelSize: 13; color: cdeTextDark
                        clip: true; focus: true

                        Keys.onReturnPressed: tryUnlock()
                        Keys.onEnterPressed: tryUnlock()
                    }
                }

                // Error message
                Text {
                    id: errorMsg
                    x: 0; y: (fieldHeight + 10) * 2
                    width: form.width; height: 16
                    color: cdeError; font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    text: root.failMessage
                }

                // Unlock button
                Row {
                    x: (form.width - buttonWidth) / 2
                    y: (fieldHeight + 10) * 2 + 22
                    spacing: buttonGap

                    CdeButton {
                        text: "Unlock"
                        onClicked: tryUnlock()
                    }
                }
            }
        }
    }

    // Clock in corner
    Text {
        anchors { bottom: parent.bottom; right: parent.right; margins: 16 }
        color: cdeFrameLight; font.pixelSize: 13
        text: Qt.formatDateTime(new Date(), "ddd MMM d, yyyy  h:mm AP")

        Timer {
            interval: 60000; running: true; repeat: true
            onTriggered: parent.text = Qt.formatDateTime(new Date(), "ddd MMM d, yyyy  h:mm AP")
        }
    }

    function tryUnlock() {
        root.failMessage = ""
        authenticator.tryUnlock(passwordInput.text)
    }

    Connections {
        target: authenticator
        function onFailed() {
            root.failMessage = "Unlock failed"
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
        }
        function onSucceeded() {
            root.failMessage = ""
        }
        function onInfoMessage(msg) {
            root.failMessage = msg
        }
        function onErrorMessage(msg) {
            root.failMessage = msg
        }
        function onPrompt(msg) {
            root.failMessage = ""
            passwordInput.forceActiveFocus()
        }
        function onPromptForSecret(msg) {
            root.failMessage = ""
            passwordInput.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus()
    }
}
