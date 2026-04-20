/*
 * CDE Login Theme for SDDM
 * Classic window-frame style with beveled edges
 */

import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1024
    height: 768
    color: colors.background

    // CDE Color Palette - centralized
    QtObject {
        id: colors
        readonly property color background: "#5C5F6A"
        readonly property color frame: "#AEB2C3"
        readonly property color frameLight: "#D4D7E2"
        readonly property color frameDark: "#5C5F6A"
        readonly property color titleBar: "#B24D7A"
        readonly property color textLight: "#FFFFFF"
        readonly property color textDark: "#000000"
        readonly property color inputBg: "#FFFFFF"
        readonly property color error: "#CC0000"
    }

    // Layout metrics - centralized
    QtObject {
        id: metrics
        readonly property int windowWidth: 400
        readonly property int windowHeight: 260
        readonly property int border: 6
        readonly property int titleHeight: 26
        readonly property int fieldHeight: 26
        readonly property int labelWidth: 80
        readonly property int fieldGap: 10
        readonly property int rowSpacing: 10
        readonly property int padding: 14
        readonly property int buttonWidth: 80
        readonly property int buttonGap: 12
    }

    TextConstants { id: textConstants }

    Connections {
        target: sddm
        function onLoginFailed() {
            errorMsg.text = textConstants.loginFailed
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
        }
    }

    // CDE-style ComboBox: custom dropdown that dismisses on outside click
    component CdeComboBox: Item {
        id: combo
        property var model
        property int index: 0
        property font font

        Repeater {
            id: _items
            model: combo.model
            Item {
                visible: false
                // SDDM userModel exposes "name" + "realName"; sessionModel exposes "name".
                // Qt.DisplayRole is NOT registered in roleNames(), so model.display is undefined.
                readonly property string displayText: {
                    if (typeof realName !== "undefined" && realName && realName.length > 0) return realName
                    if (typeof name !== "undefined") return name
                    return ""
                }
                readonly property string nameText: (typeof name !== "undefined") ? name : ""
            }
        }

        readonly property string selectedText: {
            var i = index >= 0 ? index : 0
            if (i >= _items.count) return ""
            var item = _items.itemAt(i)
            return item ? item.displayText : ""
        }

        readonly property string selectedName: {
            var i = index >= 0 ? index : 0
            if (i >= _items.count) return ""
            var item = _items.itemAt(i)
            return item ? item.nameText : ""
        }

        Rectangle {
            anchors.fill: parent
            color: colors.inputBg
            Bevel { anchors.fill: parent; raised: false; size: 1 }
            Text {
                anchors { left: parent.left; leftMargin: 4; right: arrowGlyph.left; rightMargin: 2; verticalCenter: parent.verticalCenter }
                text: combo.selectedText
                font: combo.font
                color: colors.textDark
                clip: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                id: arrowGlyph
                text: "\u25BC"
                font.pixelSize: 8
                color: colors.textDark
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (!popup.visible) {
                        var pos = combo.mapToItem(root, 0, combo.height)
                        popup.x = pos.x
                        popup.y = pos.y
                        popup.visible = true
                        backdrop.visible = true
                    }
                }
            }
        }

        // Full-screen backdrop sits above loginWindow (z:0) but below popup (z:200)
        MouseArea {
            id: backdrop
            parent: root
            anchors.fill: parent
            z: 199
            visible: false
            onClicked: {
                popup.visible = false
                backdrop.visible = false
            }
        }

        Rectangle {
            id: popup
            parent: root
            width: combo.width
            height: Math.min(popupList.count, 6) * metrics.fieldHeight + 2
            visible: false
            z: 200
            color: colors.inputBg
            border.color: colors.frameDark
            border.width: 1
            clip: true

            ListView {
                id: popupList
                anchors { fill: parent; margins: 1 }
                model: combo.model
                clip: true
                delegate: Rectangle {
                    width: popup.width - 2
                    height: metrics.fieldHeight
                    color: rowArea.containsMouse ? colors.titleBar : colors.inputBg
                    Text {
                        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                        text: {
                            if (typeof realName !== "undefined" && realName && realName.length > 0) return realName
                            if (typeof name !== "undefined") return name
                            return ""
                        }
                        font: combo.font
                        color: rowArea.containsMouse ? colors.textLight : colors.textDark
                        verticalAlignment: Text.AlignVCenter
                        clip: true
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            combo.index = index
                            popup.visible = false
                            backdrop.visible = false
                        }
                    }
                }
            }
        }
    }

    // Bevel effect component
    component Bevel: Item {
        property bool raised: true
        property int size: 2
        readonly property color light: raised ? colors.frameLight : colors.frameDark
        readonly property color dark: raised ? colors.frameDark : colors.frameLight

        Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: size; color: light }
        Rectangle { anchors { top: parent.top; left: parent.left; bottom: parent.bottom } width: size; color: light }
        Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right } height: size; color: dark }
        Rectangle { anchors { top: parent.top; right: parent.right; bottom: parent.bottom } width: size; color: dark }
    }

    // CDE-style button component
    component CdeButton: Rectangle {
        id: btn
        property alias text: label.text
        property bool canPress: true
        signal clicked()

        width: metrics.buttonWidth
        height: metrics.fieldHeight
        color: area.pressed && canPress ? Qt.darker(colors.frame, 1.1) : colors.frame
        enabled: canPress

        Bevel { anchors.fill: parent; raised: !(area.pressed && canPress); size: 2 }
        Text { id: label; anchors.centerIn: parent; color: colors.textDark; font.pixelSize: 13 }
        MouseArea { id: area; anchors.fill: parent; enabled: btn.canPress; onClicked: btn.clicked() }
    }

    // Main window
    Rectangle {
        id: loginWindow
        width: metrics.windowWidth
        height: metrics.windowHeight
        anchors.centerIn: parent
        color: colors.frame

        Bevel { anchors.fill: parent; raised: true; size: 2 }

        // Title bar
        Rectangle {
            id: titleBar
            x: metrics.border; y: metrics.border
            width: parent.width - metrics.border * 2
            height: metrics.titleHeight
            color: colors.titleBar

            Bevel { anchors.fill: parent; raised: true; size: 1 }
            Text {
                anchors.centerIn: parent
                text: "Login"
                color: colors.textLight
                font { pixelSize: 13; bold: true }
            }
        }

        // Content area
        Rectangle {
            id: content
            x: metrics.border
            y: titleBar.y + titleBar.height + 3
            width: parent.width - metrics.border * 2
            height: parent.height - y - metrics.border
            color: colors.frame

            Bevel { anchors.fill: parent; raised: false; size: 1 }

            // Form layout
            Item {
                id: form
                anchors { fill: parent; margins: metrics.padding }

                readonly property int fieldWidth: width - metrics.labelWidth - metrics.fieldGap
                readonly property int row1Y: 0
                readonly property int row2Y: metrics.fieldHeight + metrics.rowSpacing
                readonly property int row3Y: (metrics.fieldHeight + metrics.rowSpacing) * 2

                // User row
                Text {
                    x: 0; y: form.row1Y; width: metrics.labelWidth; height: metrics.fieldHeight
                    text: "User:"; color: colors.textDark; font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                }
                CdeComboBox {
                    id: userCombo
                    x: metrics.labelWidth + metrics.fieldGap; y: form.row1Y
                    width: form.fieldWidth; height: metrics.fieldHeight
                    model: userModel; index: userModel.lastIndex
                    font.pixelSize: 13
                }

                // Password row
                Text {
                    x: 0; y: form.row2Y; width: metrics.labelWidth; height: metrics.fieldHeight
                    text: "Password:"; color: colors.textDark; font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                }
                Rectangle {
                    x: metrics.labelWidth + metrics.fieldGap; y: form.row2Y
                    width: form.fieldWidth; height: metrics.fieldHeight
                    color: colors.inputBg

                    Bevel { anchors.fill: parent; raised: false; size: 1 }
                    TextInput {
                        id: passwordInput
                        anchors { fill: parent; margins: 5 }
                        echoMode: TextInput.Password
                        font.pixelSize: 13; color: colors.textDark
                        clip: true; focus: true
                        KeyNavigation.backtab: userCombo
                        KeyNavigation.tab: loginBtn
                        Keys.onReturnPressed: doLogin()
                        Keys.onEnterPressed: doLogin()
                    }
                }

                // Session row
                Text {
                    x: 0; y: form.row3Y; width: metrics.labelWidth; height: metrics.fieldHeight
                    text: "Session:"; color: colors.textDark; font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                }
                CdeComboBox {
                    id: sessionCombo
                    x: metrics.labelWidth + metrics.fieldGap; y: form.row3Y
                    width: form.fieldWidth; height: metrics.fieldHeight
                    model: sessionModel; index: sessionModel.lastIndex
                    font.pixelSize: 13
                }

                // Error message
                Text {
                    id: errorMsg
                    x: 0; y: form.row3Y + metrics.fieldHeight + 4
                    width: form.width; height: 16
                    color: colors.error; font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }

                // Buttons
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: form.row3Y + metrics.fieldHeight + 22
                    spacing: metrics.buttonGap

                    CdeButton {
                        id: loginBtn
                        text: "Login"
                        onClicked: doLogin()
                        Keys.onReturnPressed: doLogin()
                        KeyNavigation.backtab: passwordInput
                        KeyNavigation.tab: shutdownBtn.canPress ? shutdownBtn : rebootBtn
                    }
                    CdeButton {
                        id: shutdownBtn
                        text: "Shutdown"
                        canPress: sddm.canPowerOff
                        visible: canPress
                        onClicked: sddm.powerOff()
                        KeyNavigation.backtab: loginBtn
                        KeyNavigation.tab: rebootBtn.canPress ? rebootBtn : userCombo
                    }
                    CdeButton {
                        id: rebootBtn
                        text: "Reboot"
                        canPress: sddm.canReboot
                        visible: canPress
                        onClicked: sddm.reboot()
                        KeyNavigation.backtab: shutdownBtn.canPress ? shutdownBtn : loginBtn
                        KeyNavigation.tab: userCombo
                    }
                }
            }
        }
    }

    // Clock
    Text {
        anchors { bottom: parent.bottom; right: parent.right; margins: 16 }
        color: colors.frameLight; font.pixelSize: 13
        text: Qt.formatDateTime(new Date(), "ddd MMM d, yyyy  h:mm AP")
        Timer { interval: 60000; running: true; repeat: true; onTriggered: parent.text = Qt.formatDateTime(new Date(), "ddd MMM d, yyyy  h:mm AP") }
    }

    // Hostname
    Text {
        anchors { bottom: parent.bottom; left: parent.left; margins: 16 }
        color: colors.frameLight; font.pixelSize: 13
        text: sddm.hostName
    }

    function doLogin() {
        sddm.login(userCombo.selectedName, passwordInput.text, sessionCombo.index)
    }

    Component.onCompleted: passwordInput.forceActiveFocus()
}
