pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property Session session

    spacing: Appearance.spacing.lg

    SettingsHeader {
        icon: "router"
        title: qsTr("网络设置")
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.xxl
        title: qsTr("以太网")
        description: qsTr("以太网设备信息")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.sm / 2

        PropertyRow {
            label: qsTr("设备总数")
            value: qsTr("%1").arg(Nmcli.ethernetDevices ? Nmcli.ethernetDevices.length : 0)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("已连接的设备")
            value: qsTr("%1").arg(Nmcli.ethernetDevices ? Nmcli.ethernetDevices.filter(d => d.connected).length : 0)
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.xxl
        title: qsTr("无线")
        description: qsTr("WiFi 网络设置")
    }

    SectionContainer {
        ToggleRow {
            label: qsTr("WiFi 已启用")
            checked: Nmcli.wifiEnabled
            toggle.onToggled: {
                Nmcli.enableWifi(checked);
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.xxl
        title: qsTr("VPN")
        description: qsTr("VPN 提供商设置")
        visible: Config.utilities.vpn.enabled || Config.utilities.vpn.provider.length > 0
    }

    SectionContainer {
        visible: Config.utilities.vpn.enabled || Config.utilities.vpn.provider.length > 0

        ToggleRow {
            label: qsTr("VPN 已启用")
            checked: Config.utilities.vpn.enabled
            toggle.onToggled: {
                Config.utilities.vpn.enabled = checked;
                Config.markDirty("utilities");
            }
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("提供商")
            value: qsTr("%1").arg(Config.utilities.vpn.provider.length)
        }

        TextButton {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.lg
            Layout.minimumHeight: Appearance.font.size.bodyMedium + Appearance.padding.md * 2
            text: qsTr("⚙ 管理 VPN 提供商")
            inactiveColour: Colours.palette.m3secondaryContainer
            inactiveOnColour: Colours.palette.m3onSecondaryContainer

            onClicked: {
                vpnSettingsDialog.open();
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.xxl
        title: qsTr("当前连接")
        description: qsTr("当前网络连接信息")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.sm / 2

        PropertyRow {
            label: qsTr("网络")
            value: Nmcli.active ? Nmcli.active.ssid : (Nmcli.activeEthernet ? Nmcli.activeEthernet.interface : qsTr("未连接"))
        }

        PropertyRow {
            showTopMargin: true
            visible: Nmcli.active !== null
            label: qsTr("信号强度")
            value: Nmcli.active ? qsTr("%1%").arg(Nmcli.active.strength) : qsTr("N/A")
        }

        PropertyRow {
            showTopMargin: true
            visible: Nmcli.active !== null
            label: qsTr("安全")
            value: Nmcli.active ? (Nmcli.active.isSecure ? qsTr("已加密") : qsTr("打开")) : qsTr("N/A")
        }

        PropertyRow {
            showTopMargin: true
            visible: Nmcli.active !== null
            label: qsTr("频率")
            value: Nmcli.active ? qsTr("%1 MHz").arg(Nmcli.active.frequency) : qsTr("N/A")
        }
    }

    Popup {
        id: vpnSettingsDialog

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(600, parent.width - Appearance.padding.xl * 2)
        height: Math.min(700, parent.height - Appearance.padding.xl * 2)

        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: StyledRect {
            color: Colours.palette.m3surface
            radius: Appearance.rounding.large
        }

        StyledFlickable {
            anchors.fill: parent
            anchors.margins: Appearance.padding.xl * 1.5
            flickableDirection: Flickable.VerticalFlick
            contentHeight: vpnSettingsContent.height
            clip: true

            VpnSettings {
                id: vpnSettingsContent

                anchors.left: parent.left
                anchors.right: parent.right
                session: root.session
            }
        }
    }
}
