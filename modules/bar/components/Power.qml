import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities

    implicitWidth: icon.implicitHeight + Appearance.padding.xs * 2
    implicitHeight: icon.implicitHeight

    StateLayer {
        // Cursed workaround to make the height larger than the parent
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Appearance.padding.xs * 2

        radius: Appearance.rounding.full

        function onClicked(): void {
            root.visibilities.session = !root.visibilities.session;
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -1

        text: "power_settings_new"
        color: Colours.palette.m3error
        font.bold: true
        // Follows the bar's thickness; the font token alone does not.
        font.pointSize: Math.round(Appearance.font.size.bodyMedium * Config.bar.sizes.iconScale)
    }
}
