/*
 * CDE Lock Screen for Plasma 6
 * Replaces the default Breeze lock screen with CDE-styled beveled window
 */

import QtQuick
import QtQuick.Layouts

Item {
    id: lockScreenUi

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

    // Layout metrics
    readonly property int windowWidth: 400
    readonly property int windowHeight: 230
    readonly property int borderWidth: 6
    readonly property int titleHeight: 26
    readonly property int fieldHeight: 28
    readonly property int labelWidth: 80
    readonly property int fieldGap: 10
    readonly property int contentPadding: 16
    readonly property int buttonWidth: 80
    readonly property int buttonGap: 12

    property string failMessage: ""
    property bool uiVisible: false
    // Queued password — used when doUnlock() is called before PAM is ready
    // to prompt (e.g. right after resume-from-suspend). Sent once the
    // authenticator's next promptForSecret arrives.
    property string pendingPassword: ""

    focus: true

    // Any keypress while the UI is hidden wakes and restarts auth, so users
    // who wake the machine with the keyboard aren't stuck at a dead screen.
    Keys.onPressed: (event) => {
        if (!lockScreenUi.uiVisible) {
            showAndAuth()
            event.accepted = true
        }
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

    // CDE button component
    component CdeButton: Rectangle {
        id: btn
        property alias text: label.text
        property bool enabled: true
        signal clicked()

        width: buttonWidth
        height: fieldHeight
        color: area.pressed && btn.enabled ? Qt.darker(cdeFrame, 1.1) : cdeFrame
        opacity: btn.enabled ? 1.0 : 0.6

        Bevel { anchors.fill: parent; raised: !(area.pressed && btn.enabled); size: 2 }
        Text { id: label; anchors.centerIn: parent; color: cdeTextDark; font.pixelSize: 13 }
        MouseArea { id: area; anchors.fill: parent; enabled: btn.enabled; onClicked: btn.clicked() }
    }

    // Background — click anywhere to show UI and start auth
    Rectangle {
        anchors.fill: parent
        color: cdeBackground

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: showAndAuth()
            onPositionChanged: showAndAuth()
            onPressed: showAndAuth()
        }
    }

    // Main lock window — only visible once user interacts
    Rectangle {
        id: lockWindow
        width: windowWidth
        height: windowHeight
        anchors.centerIn: parent
        color: cdeFrame
        visible: lockScreenUi.uiVisible
        opacity: lockScreenUi.uiVisible ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 200 } }

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
                anchors { fill: parent; margins: contentPadding }
                readonly property int fieldWidth: width - labelWidth - fieldGap

                // User row
                Text {
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
                    id: passwordField
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
                        enabled: !graceLockTimer.running

                        Keys.onReturnPressed: doUnlock()
                        Keys.onEnterPressed: doUnlock()
                    }
                }

                // Error/info message
                Text {
                    id: errorMsg
                    x: 0; y: (fieldHeight + 10) * 2 + 2
                    width: form.width; height: 16
                    color: cdeError; font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    text: lockScreenUi.failMessage
                }

                // Unlock button
                Row {
                    x: (form.width - buttonWidth) / 2
                    y: (fieldHeight + 10) * 2 + 24
                    spacing: buttonGap

                    CdeButton {
                        text: "Unlock"
                        enabled: !graceLockTimer.running
                        onClicked: doUnlock()
                    }
                }
            }
        }
    }

    // Clock — always visible
    Text {
        anchors { bottom: parent.bottom; right: parent.right; margins: 16 }
        color: cdeFrameLight; font.pixelSize: 13
        text: Qt.formatDateTime(new Date(), "ddd MMM d, yyyy  h:mm AP")

        Timer {
            interval: 60000; running: true; repeat: true
            onTriggered: parent.text = Qt.formatDateTime(new Date(), "ddd MMM d, yyyy  h:mm AP")
        }
    }

    // Hostname — always visible
    Text {
        anchors { bottom: parent.bottom; left: parent.left; margins: 16 }
        color: cdeFrameLight; font.pixelSize: 13
        text: "Screen is locked"
    }

    function showAndAuth() {
        if (!lockScreenUi.uiVisible) {
            lockScreenUi.uiVisible = true
            authenticator.startAuthenticating()
            passwordInput.forceActiveFocus()
        } else if (!authenticator.promptForSecret) {
            // UI was still visible (no fadeout) but PAM went stale across a
            // suspend/resume — re-arm the session so respond() will be heard.
            authenticator.startAuthenticating()
            passwordInput.forceActiveFocus()
        }
    }

    function doUnlock() {
        if (passwordInput.text.length === 0) {
            return
        }
        lockScreenUi.failMessage = ""
        if (authenticator.promptForSecret) {
            authenticator.respond(passwordInput.text)
        } else {
            // PAM isn't prompting yet (stale session after wake). Queue the
            // password and send it once onPromptForSecretChanged fires.
            lockScreenUi.pendingPassword = passwordInput.text
            authenticator.startAuthenticating()
        }
    }

    Connections {
        target: authenticator
        function onFailed(kind) {
            // kind 0 = interactive (password), ignore noninteractive failures
            if (kind !== 0) {
                return
            }
            lockScreenUi.failMessage = "Unlock failed"
            passwordInput.text = ""
            lockScreenUi.pendingPassword = ""
            graceLockTimer.restart()
        }
        function onSucceeded() {
            if (authenticator.hadPrompt) {
                Qt.quit()
            }
        }
        function onInfoMessageChanged() {
            if (authenticator.infoMessage) {
                lockScreenUi.failMessage = authenticator.infoMessage
            }
        }
        function onErrorMessageChanged() {
            if (authenticator.errorMessage) {
                lockScreenUi.failMessage = authenticator.errorMessage
            }
        }
        function onPromptForSecretChanged() {
            // Only react on the rising edge — the signal also fires when PAM
            // stops prompting (e.g. after respond()), and clearing the field
            // there would wipe text the user just typed.
            if (!authenticator.promptForSecret) {
                return
            }
            passwordInput.forceActiveFocus()
            if (lockScreenUi.pendingPassword.length > 0) {
                authenticator.respond(lockScreenUi.pendingPassword)
                lockScreenUi.pendingPassword = ""
            }
        }
    }

    // Grace lock after failed attempt — prevents rapid retries
    Timer {
        id: graceLockTimer
        interval: 3000
        onTriggered: {
            passwordInput.text = ""
            lockScreenUi.failMessage = ""
            authenticator.startAuthenticating()
            passwordInput.forceActiveFocus()
        }
    }

    // Hide UI timer — fade out after inactivity
    Timer {
        id: fadeoutTimer
        interval: 15000
        running: lockScreenUi.uiVisible
        onTriggered: {
            if (passwordInput.text.length === 0) {
                lockScreenUi.uiVisible = false
            }
        }
    }

    Connections {
        target: root
        function onClearPassword() {
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
        }
    }
}
