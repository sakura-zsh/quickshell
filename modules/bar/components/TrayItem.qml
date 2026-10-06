pragma ComponentBehavior: Bound

import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Quickshell.Services.SystemTray
import QtQuick

MouseArea {
    id: root

    required property SystemTrayItem modelData

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    // Grown with the bar: this comes from a font token, not from innerWidth.
    readonly property int trayIconSize: Math.round(Appearance.font.size.small * 2 * Config.bar.sizes.iconScale)

    implicitWidth: root.trayIconSize
    implicitHeight: root.trayIconSize

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            modelData.activate();
        else
            modelData.secondaryActivate();
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon, Config.bar.tray.iconSubs)
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}