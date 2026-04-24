/*
 * CDE Lock Screen entry point.
 *
 * kscreenlocker_greet loads this as the `lockscreenmainscript` and binds
 * magic properties and signals to the root Item. It writes `viewVisible`
 * when the greeter is on-screen, writes `locked` / `suspendTo*Supported`,
 * and connects to `suspendToRam()` / `suspendToDisk()` / `clearPassword()`.
 *
 * Our job is to forward these to the CDE UI below and keep the root
 * stable so the greeter never silently falls back to Breeze.
 */

import QtQuick 2.15

Item {
    id: root

    // Magic properties kscreenlocker writes to
    property bool viewVisible: false
    property bool suspendToRamSupported: false
    property bool suspendToDiskSupported: false
    property bool locked: false

    // Magic signals kscreenlocker connects to
    signal suspendToDisk()
    signal suspendToRam()
    signal clearPassword()

    // Ensure RTL locales flip correctly (matches Breeze)
    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    implicitWidth: 800
    implicitHeight: 600

    LockScreenUi {
        id: ui
        anchors.fill: parent
        lockView: root
    }

    // Propagate kscreenlocker's clearPassword() to the UI. Emitted after
    // resume-from-suspend and similar, so the password field is always
    // empty when the user comes back.
    onClearPassword: ui.clearPassword()

    // When kscreenlocker writes viewVisible=false (screen going dark), stop
    // any UI-side timers and clear state so we're fresh on the next wake.
    onViewVisibleChanged: {
        if (!viewVisible) {
            ui.onViewHidden()
        } else {
            ui.onViewShown()
        }
    }
}
