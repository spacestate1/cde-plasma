/*
 * CDE Lock Screen UI for Plasma 5.
 *
 * Instantiated by LockScreen.qml; sized via anchors.fill: parent. The parent
 * LockScreen.qml owns the "magic" properties kscreenlocker writes/reads.
 *
 * Plasma 5 authenticator API (differs from Plasma 6):
 *   authenticator.tryUnlock()                  — start a PAM session, no args
 *   authenticator.respond(password)            — reply when PAM asks
 *   authenticator.graceLocked                  — true in post-login grace
 *   signals: failed(), succeeded(),
 *            infoMessage(s), errorMessage(s),
 *            prompt(s), promptForSecret(s)
 *
 * There is no `promptForSecret` or `hadPrompt` *property* on P5 — both are
 * tracked locally from the signal handlers below.
 */

import QtQuick 2.15

Item {
    id: lockScreenUi

    // Set by LockScreen.qml so we can mirror uiVisible back to the root's
    // viewVisible (tells kscreenlocker the greeter is actively on-screen).
    property Item lockView: null

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

    property string failMessage: ""
    property bool uiVisible: false
    // Set true by onPromptForSecret; cleared after respond() or onFailed.
    property bool promptReady: false
    // True once PAM has prompted interactively this session.
    property bool hadPrompt: false
    // Queued password if the user submits before PAM is ready.
    property string pendingPassword: ""
    // Whether the current PAM auth attempt has been sent to respond().
    property bool attemptInFlight: false

    focus: true
    activeFocusOnTab: true

    Component.onCompleted: console.log("CDE-LOCK: UI loaded, size=" + width + "x" + height)

    // ----- External-facing API (called from LockScreen.qml) -----

    function clearPassword() {
        passwordInput.text = ""
        passwordInput.forceActiveFocus()
    }

    function onViewHidden() {
        // Screen going off — stop timers, clear transient state.
        fadeoutTimer.stop()
        lockScreenUi.pendingPassword = ""
        lockScreenUi.attemptInFlight = false
        clearPassword()
        lockScreenUi.uiVisible = false
    }

    function onViewShown() {
        // Screen coming back on — make sure we're ready to authenticate.
        if (lockScreenUi.uiVisible) {
            fadeoutTimer.restart()
            passwordInput.forceActiveFocus()
        }
    }

    // Propagate uiVisible up to the root so kscreenlocker sees the greeter
    // as actively interacting (keeps the backlight on).
    onUiVisibleChanged: {
        if (lockView) {
            lockView.viewVisible = uiVisible
        }
    }

    // ----- Global key handling on the background (UI hidden) -----

    // Any keypress while the UI is hidden wakes and starts auth.
    Keys.onPressed: {
        if (!lockScreenUi.uiVisible) {
            showAndAuth()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            // Esc hides the lock window — Breeze-equivalent behavior.
            lockScreenUi.uiVisible = false
            clearPassword()
            event.accepted = true
        }
    }

    // ----- Background (always visible) -----

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

    // ----- Main lock window (visible only when uiVisible) -----

    Rectangle {
        id: lockWindow
        width: windowWidth
        height: windowHeight
        anchors.centerIn: parent
        color: cdeFrame
        visible: lockScreenUi.uiVisible
        opacity: lockScreenUi.uiVisible ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 200 } }

        // Outer raised bevel
        Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 2; color: cdeFrameLight }
        Rectangle { anchors { top: parent.top; left: parent.left; bottom: parent.bottom } width: 2; color: cdeFrameLight }
        Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right } height: 2; color: cdeFrameDark }
        Rectangle { anchors { top: parent.top; right: parent.right; bottom: parent.bottom } width: 2; color: cdeFrameDark }

        // Title bar
        Rectangle {
            id: titleBar
            x: borderWidth; y: borderWidth
            width: parent.width - borderWidth * 2
            height: titleHeight
            color: cdeTitleBar

            Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 1; color: cdeFrameLight }
            Rectangle { anchors { top: parent.top; left: parent.left; bottom: parent.bottom } width: 1; color: cdeFrameLight }
            Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right } height: 1; color: cdeFrameDark }
            Rectangle { anchors { top: parent.top; right: parent.right; bottom: parent.bottom } width: 1; color: cdeFrameDark }

            Text {
                anchors.centerIn: parent
                text: "Screen Locked"
                color: cdeTextLight
                font { pixelSize: 13; bold: true }
            }
        }

        // Content area (sunken)
        Rectangle {
            id: content
            x: borderWidth
            y: titleBar.y + titleBar.height + 3
            width: parent.width - borderWidth * 2
            height: parent.height - y - borderWidth
            color: cdeFrame

            Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 1; color: cdeFrameDark }
            Rectangle { anchors { top: parent.top; left: parent.left; bottom: parent.bottom } width: 1; color: cdeFrameDark }
            Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right } height: 1; color: cdeFrameLight }
            Rectangle { anchors { top: parent.top; right: parent.right; bottom: parent.bottom } width: 1; color: cdeFrameLight }

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
                    text: (typeof kscreenlocker_userName !== "undefined") ? kscreenlocker_userName : ""
                    color: cdeTextDark; font { pixelSize: 13; bold: true }
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
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

                    Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 1; color: cdeFrameDark }
                    Rectangle { anchors { top: parent.top; left: parent.left; bottom: parent.bottom } width: 1; color: cdeFrameDark }
                    Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right } height: 1; color: cdeFrameLight }
                    Rectangle { anchors { top: parent.top; right: parent.right; bottom: parent.bottom } width: 1; color: cdeFrameLight }

                    TextInput {
                        id: passwordInput
                        anchors { fill: parent; margins: 5 }
                        echoMode: TextInput.Password
                        font.pixelSize: 13; color: cdeTextDark
                        clip: true; focus: true
                        activeFocusOnTab: true
                        enabled: !graceLockTimer.running
                                 && !(typeof authenticator !== "undefined" && authenticator.graceLocked)

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
                    elide: Text.ElideRight
                }

                // Unlock button
                Rectangle {
                    id: unlockBtn
                    width: buttonWidth; height: fieldHeight
                    x: (form.width - buttonWidth) / 2
                    y: (fieldHeight + 10) * 2 + 24
                    color: btnArea.pressed && btnArea.enabled ? Qt.darker(cdeFrame, 1.1) : cdeFrame
                    opacity: btnArea.enabled ? 1.0 : 0.6

                    property bool _raised: !(btnArea.pressed && btnArea.enabled)
                    Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 2; color: unlockBtn._raised ? cdeFrameLight : cdeFrameDark }
                    Rectangle { anchors { top: parent.top; left: parent.left; bottom: parent.bottom } width: 2; color: unlockBtn._raised ? cdeFrameLight : cdeFrameDark }
                    Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right } height: 2; color: unlockBtn._raised ? cdeFrameDark : cdeFrameLight }
                    Rectangle { anchors { top: parent.top; right: parent.right; bottom: parent.bottom } width: 2; color: unlockBtn._raised ? cdeFrameDark : cdeFrameLight }

                    Text { anchors.centerIn: parent; text: "Unlock"; color: cdeTextDark; font.pixelSize: 13 }
                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        enabled: !graceLockTimer.running
                                 && !(typeof authenticator !== "undefined" && authenticator.graceLocked)
                        onClicked: doUnlock()
                    }
                }
            }
        }
    }

    // ----- Clock and bottom-left label (always visible) -----

    Text {
        id: clockLabel
        anchors { bottom: parent.bottom; right: parent.right; margins: 16 }
        color: cdeFrameLight; font.pixelSize: 13
        text: Qt.formatDateTime(new Date(), "ddd MMM d, yyyy  h:mm AP")

        Timer {
            interval: 60000; running: true; repeat: true
            onTriggered: clockLabel.text = Qt.formatDateTime(new Date(), "ddd MMM d, yyyy  h:mm AP")
        }
    }

    Text {
        anchors { bottom: parent.bottom; left: parent.left; margins: 16 }
        color: cdeFrameLight; font.pixelSize: 13
        text: "Screen is locked"
    }

    // ----- Authentication flow -----

    function showAndAuth() {
        if (typeof authenticator === "undefined") {
            return
        }
        if (!lockScreenUi.uiVisible) {
            lockScreenUi.uiVisible = true
            authenticator.tryUnlock()
            passwordInput.forceActiveFocus()
        } else if (!lockScreenUi.promptReady && !lockScreenUi.attemptInFlight) {
            // UI still visible but PAM went stale (e.g. suspend/resume) —
            // re-arm the session so respond() will be heard.
            authenticator.tryUnlock()
            passwordInput.forceActiveFocus()
        } else {
            passwordInput.forceActiveFocus()
        }
        fadeoutTimer.restart()
    }

    function doUnlock() {
        if (passwordInput.text.length === 0) {
            return
        }
        if (typeof authenticator === "undefined") {
            return
        }
        lockScreenUi.failMessage = ""
        if (lockScreenUi.promptReady) {
            authenticator.respond(passwordInput.text)
            lockScreenUi.promptReady = false
            lockScreenUi.attemptInFlight = true
        } else {
            // PAM isn't prompting yet — queue and start a session.
            lockScreenUi.pendingPassword = passwordInput.text
            authenticator.tryUnlock()
        }
    }

    Connections {
        target: typeof authenticator !== "undefined" ? authenticator : null
        ignoreUnknownSignals: true
        function onFailed() {
            lockScreenUi.failMessage = "Unlock failed"
            passwordInput.text = ""
            lockScreenUi.pendingPassword = ""
            lockScreenUi.promptReady = false
            lockScreenUi.attemptInFlight = false
            lockScreenUi.hadPrompt = false
            graceLockTimer.restart()
        }
        function onSucceeded() {
            lockScreenUi.attemptInFlight = false
            if (lockScreenUi.hadPrompt) {
                Qt.quit()
            }
        }
        function onInfoMessage(msg) {
            if (msg) {
                lockScreenUi.failMessage = msg
            }
            lockScreenUi.hadPrompt = true
        }
        function onErrorMessage(msg) {
            if (msg) {
                lockScreenUi.failMessage = msg
            }
        }
        function onPrompt(msg) {
            lockScreenUi.hadPrompt = true
            passwordInput.forceActiveFocus()
        }
        function onPromptForSecret(msg) {
            lockScreenUi.promptReady = true
            lockScreenUi.hadPrompt = true
            lockScreenUi.attemptInFlight = false
            passwordInput.forceActiveFocus()
            if (lockScreenUi.pendingPassword.length > 0) {
                authenticator.respond(lockScreenUi.pendingPassword)
                lockScreenUi.pendingPassword = ""
                lockScreenUi.promptReady = false
                lockScreenUi.attemptInFlight = true
            }
        }
    }

    // 3-second throttle after a failed attempt so users can't brute-force.
    Timer {
        id: graceLockTimer
        interval: 3000
        onTriggered: {
            passwordInput.text = ""
            lockScreenUi.failMessage = ""
            if (typeof authenticator !== "undefined") {
                authenticator.tryUnlock()
            }
            passwordInput.forceActiveFocus()
        }
    }

    // Fade the UI out after 15s of inactivity when the password box is empty.
    Timer {
        id: fadeoutTimer
        interval: 15000
        running: lockScreenUi.uiVisible
        onTriggered: {
            if (passwordInput.text.length === 0) {
                lockScreenUi.uiVisible = false
            } else {
                // Password box has text — user is still interacting. Don't hide.
                fadeoutTimer.restart()
            }
        }
    }
}
