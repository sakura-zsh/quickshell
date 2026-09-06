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
        icon: "wifi"
        title: qsTr("网络设置")
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.xxl
        title: qsTr("WiFi 状态")
        description: qsTr("常规 WiFi 设置")
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
        title: qsTr("网络信息")
        description: qsTr("当前网络连接")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.sm / 2

        PropertyRow {
            label: qsTr("已连接的网络")
            value: Nmcli.active ? Nmcli.active.ssid : qsTr("未连接")
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("信号强度")
            value: Nmcli.active ? qsTr("%1%").arg(Nmcli.active.strength) : qsTr("N/A")
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("安全")
            value: Nmcli.active ? (Nmcli.active.isSecure ? qsTr("已加密") : qsTr("打开")) : qsTr("N/A")
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("频率")
            value: Nmcli.active ? qsTr("%1 MHz").arg(Nmcli.active.frequency) : qsTr("N/A")
        }
    }
}
