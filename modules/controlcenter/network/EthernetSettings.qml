pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property Session session

    spacing: Appearance.spacing.lg

    SettingsHeader {
        icon: "cable"
        title: qsTr("以太网设置")
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.xxl
        text: qsTr("以太网设备")
        font.pointSize: Appearance.font.size.bodyLarge
        font.weight: 500
    }

    StyledText {
        text: qsTr("可用的以太网设备")
        color: Colours.palette.m3outline
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: ethernetInfo.implicitHeight + Appearance.padding.xl * 2

        radius: Appearance.rounding.normal
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            id: ethernetInfo

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.xl

            spacing: Appearance.spacing.sm / 2

            StyledText {
                text: qsTr("设备总数")
            }

            StyledText {
                text: qsTr("%1").arg(Nmcli.ethernetDevices.length)
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.labelLarge
            }

            StyledText {
                Layout.topMargin: Appearance.spacing.lg
                text: qsTr("已连接的设备")
            }

            StyledText {
                text: qsTr("%1").arg(Nmcli.ethernetDevices.filter(d => d.connected).length)
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.labelLarge
            }
        }
    }
}
