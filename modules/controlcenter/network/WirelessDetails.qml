pragma ComponentBehavior: Bound

import ".."
import "../components"
import "."
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.config
import qs.utils
import QtQuick
import QtQuick.Layouts

DeviceDetails {
    id: root

    required property Session session
    readonly property var network: root.session.network.active

    device: network

    Component.onCompleted: {
        updateDeviceDetails();
        checkSavedProfile();
    }

    onNetworkChanged: {
        connectionUpdateTimer.stop();
        if (network && network.ssid) {
            connectionUpdateTimer.start();
        }
        updateDeviceDetails();
        checkSavedProfile();
    }

    function checkSavedProfile(): void {
        if (network && network.ssid) {
            Nmcli.loadSavedConnections(() => {});
        }
    }

    Connections {
        target: Nmcli
        function onActiveChanged() {
            updateDeviceDetails();
        }
        function onWirelessDeviceDetailsChanged() {
            if (network && network.ssid) {
                const isActive = network.active || (Nmcli.active && Nmcli.active.ssid === network.ssid);
                if (isActive && Nmcli.wirelessDeviceDetails && Nmcli.wirelessDeviceDetails !== null) {
                    connectionUpdateTimer.stop();
                }
            }
        }
    }

    Timer {
        id: connectionUpdateTimer
        interval: 500
        repeat: true
        running: network && network.ssid
        onTriggered: {
            if (network) {
                const isActive = network.active || (Nmcli.active && Nmcli.active.ssid === network.ssid);
                if (isActive) {
                    if (!Nmcli.wirelessDeviceDetails || Nmcli.wirelessDeviceDetails === null) {
                        Nmcli.getWirelessDeviceDetails("", () => {});
                    } else {
                        connectionUpdateTimer.stop();
                    }
                } else {
                    if (Nmcli.wirelessDeviceDetails !== null) {
                        Nmcli.wirelessDeviceDetails = null;
                    }
                }
            }
        }
    }

    function updateDeviceDetails(): void {
        if (network && network.ssid) {
            const isActive = network.active || (Nmcli.active && Nmcli.active.ssid === network.ssid);
            if (isActive) {
                Nmcli.getWirelessDeviceDetails("");
            } else {
                Nmcli.wirelessDeviceDetails = null;
            }
        } else {
            Nmcli.wirelessDeviceDetails = null;
        }
    }

    headerComponent: Component {
        ConnectionHeader {
            icon: root.network?.isSecure ? "lock" : "wifi"
            title: root.network?.ssid ?? qsTr("未知")
        }
    }

    sections: [
        Component {
            ColumnLayout {
                spacing: Appearance.spacing.lg

                SectionHeader {
                    title: qsTr("连接状态")
                    description: qsTr("此网络的连接设置")
                }

                SectionContainer {
                    ToggleRow {
                        label: qsTr("已连接")
                        checked: root.network?.active ?? false
                        toggle.onToggled: {
                            if (checked) {
                                NetworkConnection.handleConnect(root.network, root.session, null);
                            } else {
                                Nmcli.disconnectFromNetwork();
                            }
                        }
                    }

                    TextButton {
                        Layout.fillWidth: true
                        Layout.topMargin: Appearance.spacing.lg
                        Layout.minimumHeight: Appearance.font.size.bodyMedium + Appearance.padding.md * 2
                        visible: {
                            if (!root.network || !root.network.ssid) {
                                return false;
                            }
                            return Nmcli.hasSavedProfile(root.network.ssid);
                        }
                        inactiveColour: Colours.palette.m3secondaryContainer
                        inactiveOnColour: Colours.palette.m3onSecondaryContainer
                        text: qsTr("忘记网络")

                        onClicked: {
                            if (root.network && root.network.ssid) {
                                if (root.network.active) {
                                    Nmcli.disconnectFromNetwork();
                                }
                                Nmcli.forgetNetwork(root.network.ssid);
                            }
                        }
                    }
                }
            }
        },
        Component {
            ColumnLayout {
                spacing: Appearance.spacing.lg

                SectionHeader {
                    title: qsTr("网络属性")
                    description: qsTr("附加信息")
                }

                SectionContainer {
                    contentSpacing: Appearance.spacing.sm / 2

                    PropertyRow {
                        label: qsTr("SSID")
                        value: root.network?.ssid ?? qsTr("未知")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("BSSID")
                        value: root.network?.bssid ?? qsTr("未知")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("信号强度")
                        value: root.network ? qsTr("%1%").arg(root.network.strength) : qsTr("N/A")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("频率")
                        value: root.network ? qsTr("%1 MHz").arg(root.network.frequency) : qsTr("N/A")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("安全")
                        value: root.network ? (root.network.isSecure ? root.network.security : qsTr("打开")) : qsTr("N/A")
                    }
                }
            }
        },
        Component {
            ColumnLayout {
                spacing: Appearance.spacing.lg

                SectionHeader {
                    title: qsTr("连接信息")
                    description: qsTr("网络连接详情")
                }

                SectionContainer {
                    ConnectionInfoSection {
                        deviceDetails: Nmcli.wirelessDeviceDetails
                    }
                }
            }
        }
    ]
}
