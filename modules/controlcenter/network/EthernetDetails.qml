pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

DeviceDetails {
    id: root

    required property Session session
    readonly property var ethernetDevice: root.session.ethernet.active

    device: ethernetDevice

    Component.onCompleted: {
        if (ethernetDevice && ethernetDevice.interface) {
            Nmcli.getEthernetDeviceDetails(ethernetDevice.interface, () => {});
        }
    }

    onEthernetDeviceChanged: {
        if (ethernetDevice && ethernetDevice.interface) {
            Nmcli.getEthernetDeviceDetails(ethernetDevice.interface, () => {});
        } else {
            Nmcli.ethernetDeviceDetails = null;
        }
    }

    headerComponent: Component {
        ConnectionHeader {
            icon: "cable"
            title: root.ethernetDevice?.interface ?? qsTr("未知")
        }
    }

    sections: [
        Component {
            ColumnLayout {
                spacing: Appearance.spacing.lg

                SectionHeader {
                    title: qsTr("连接状态")
                    description: qsTr("此设备的连接设置")
                }

                SectionContainer {
                    ToggleRow {
                        label: qsTr("已连接")
                        checked: root.ethernetDevice?.connected ?? false
                        toggle.onToggled: {
                            if (checked) {
                                Nmcli.connectEthernet(root.ethernetDevice?.connection || "", root.ethernetDevice?.interface || "", () => {});
                            } else {
                                if (root.ethernetDevice?.connection) {
                                    Nmcli.disconnectEthernet(root.ethernetDevice.connection, () => {});
                                }
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
                    title: qsTr("设备属性")
                    description: qsTr("附加信息")
                }

                SectionContainer {
                    contentSpacing: Appearance.spacing.sm / 2

                    PropertyRow {
                        label: qsTr("接口")
                        value: root.ethernetDevice?.interface ?? qsTr("未知")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("连接")
                        value: root.ethernetDevice?.connection || qsTr("未连接")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("状态")
                        value: root.ethernetDevice?.state ?? qsTr("未知")
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
                        deviceDetails: Nmcli.ethernetDeviceDetails
                    }
                }
            }
        }
    ]
}
