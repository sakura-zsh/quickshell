pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.config
import qs.utils
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DeviceDetails {
    id: root

    required property Session session
    readonly property var vpnProvider: root.session.vpn.active
    readonly property bool providerEnabled: {
        if (!vpnProvider || vpnProvider.index === undefined)
            return false;
        const provider = Config.utilities.vpn.provider[vpnProvider.index];
        return provider && typeof provider === "object" && provider.enabled === true;
    }

    device: vpnProvider

    headerComponent: Component {
        ConnectionHeader {
            icon: "vpn_key"
            title: root.vpnProvider?.displayName ?? qsTr("未知")
        }
    }

    sections: [
        Component {
            ColumnLayout {
                spacing: Appearance.spacing.lg

                SectionHeader {
                    title: qsTr("连接状态")
                    description: qsTr("VPN 连接设置")
                }

                SectionContainer {
                    ToggleRow {
                        label: qsTr("启用此提供商")
                        checked: root.providerEnabled
                        toggle.onToggled: {
                            if (!root.vpnProvider)
                                return;
                            const providers = [];
                            const index = root.vpnProvider.index;

                            // Copy providers and update enabled state
                            for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                                const p = Config.utilities.vpn.provider[i];
                                if (typeof p === "object") {
                                    const newProvider = {
                                        name: p.name,
                                        displayName: p.displayName,
                                        interface: p.interface
                                    };

                                    if (checked) {
                                        // Enable this one, disable others
                                        newProvider.enabled = (i === index);
                                    } else {
                                        // Just disable this one
                                        newProvider.enabled = (i === index) ? false : (p.enabled !== false);
                                    }

                                    providers.push(newProvider);
                                } else {
                                    providers.push(p);
                                }
                            }

                            Config.utilities.vpn.provider = providers;
                            Config.markDirty("utilities");
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Appearance.spacing.lg
                        spacing: Appearance.spacing.lg

                        TextButton {
                            Layout.fillWidth: true
                            Layout.minimumHeight: Appearance.font.size.bodyMedium + Appearance.padding.md * 2
                            visible: root.providerEnabled
                            enabled: !VPN.connecting
                            inactiveColour: Colours.palette.m3primaryContainer
                            inactiveOnColour: Colours.palette.m3onPrimaryContainer
                            text: VPN.connected ? qsTr("断开连接") : qsTr("连接")

                            onClicked: {
                                VPN.toggle();
                            }
                        }

                        TextButton {
                            Layout.fillWidth: true
                            text: qsTr("编辑提供商")
                            inactiveColour: Colours.palette.m3secondaryContainer
                            inactiveOnColour: Colours.palette.m3onSecondaryContainer

                            onClicked: {
                                editVpnDialog.editIndex = root.vpnProvider.index;
                                editVpnDialog.providerName = root.vpnProvider.name;
                                editVpnDialog.displayName = root.vpnProvider.displayName;
                                editVpnDialog.interfaceName = root.vpnProvider.interface;
                                editVpnDialog.open();
                            }
                        }

                        TextButton {
                            Layout.fillWidth: true
                            text: qsTr("删除提供商")
                            inactiveColour: Colours.palette.m3errorContainer
                            inactiveOnColour: Colours.palette.m3onErrorContainer

                            onClicked: {
                                const providers = [];
                                for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                                    if (i !== root.vpnProvider.index) {
                                        providers.push(Config.utilities.vpn.provider[i]);
                                    }
                                }
                                Config.utilities.vpn.provider = providers;
                                Config.markDirty("utilities");
                                root.session.vpn.active = null;
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
                    title: qsTr("提供商详情")
                    description: qsTr("VPN 提供商信息")
                }

                SectionContainer {
                    contentSpacing: Appearance.spacing.sm / 2

                    PropertyRow {
                        label: qsTr("提供商")
                        value: root.vpnProvider?.name ?? qsTr("未知")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("显示名称")
                        value: root.vpnProvider?.displayName ?? qsTr("未知")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("接口")
                        value: root.vpnProvider?.interface || qsTr("N/A")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("状态")
                        value: {
                            if (!root.providerEnabled)
                                return qsTr("已禁用");
                            if (VPN.connecting)
                                return qsTr("正在连接…");
                            if (VPN.connected)
                                return qsTr("已连接");
                            return qsTr("已启用（未连接）");
                        }
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("已启用")
                        value: root.providerEnabled ? qsTr("是") : qsTr("否")
                    }
                }
            }
        }
    ]

    // Edit VPN Dialog
    Popup {
        id: editVpnDialog

        property int editIndex: -1
        property string providerName: ""
        property string displayName: ""
        property string interfaceName: ""

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(400, parent.width - Appearance.padding.xl * 2)
        padding: Appearance.padding.xl * 1.5

        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        opacity: 0
        scale: 0.7

        enter: Transition {
            Anim {
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
            Anim {
                property: "scale"
                from: 0.7
                to: 1
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
        }

        exit: Transition {
            Anim {
                property: "opacity"
                from: 1
                to: 0
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
            Anim {
                property: "scale"
                from: 1
                to: 0.7
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
        }

        function closeWithAnimation(): void {
            close();
        }

        Overlay.modal: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.4 * editVpnDialog.opacity)
        }

        background: StyledRect {
            color: Colours.palette.m3surfaceContainerHigh
            radius: Appearance.rounding.large

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                level: 3
                z: -1
            }
        }

        contentItem: ColumnLayout {
            spacing: Appearance.spacing.lg

            StyledText {
                text: qsTr("编辑 VPN 提供商")
                font.pointSize: Appearance.font.size.titleMedium
                font.weight: 500
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.md / 2

                StyledText {
                    text: qsTr("显示名称")
                    font.pointSize: Appearance.font.size.labelLarge
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    color: displayNameField.activeFocus ? Colours.layer(Colours.palette.m3surfaceContainer, 3) : Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    radius: Appearance.rounding.small
                    border.width: 1
                    border.color: displayNameField.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.3)

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on border.color {
                        CAnim {}
                    }

                    StyledTextField {
                        id: displayNameField
                        anchors.centerIn: parent
                        width: parent.width - Appearance.padding.md
                        horizontalAlignment: TextInput.AlignLeft
                        text: editVpnDialog.displayName
                        onTextChanged: editVpnDialog.displayName = text
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.md / 2

                StyledText {
                    text: qsTr("接口（例如 wg0、torguard）")
                    font.pointSize: Appearance.font.size.labelLarge
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    color: interfaceNameField.activeFocus ? Colours.layer(Colours.palette.m3surfaceContainer, 3) : Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    radius: Appearance.rounding.small
                    border.width: 1
                    border.color: interfaceNameField.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.3)

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on border.color {
                        CAnim {}
                    }

                    StyledTextField {
                        id: interfaceNameField
                        anchors.centerIn: parent
                        width: parent.width - Appearance.padding.md
                        horizontalAlignment: TextInput.AlignLeft
                        text: editVpnDialog.interfaceName
                        onTextChanged: editVpnDialog.interfaceName = text
                    }
                }
            }

            RowLayout {
                Layout.topMargin: Appearance.spacing.lg
                Layout.fillWidth: true
                spacing: Appearance.spacing.lg

                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("取消")
                    inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                    inactiveOnColour: Colours.palette.m3onSurface
                    onClicked: editVpnDialog.closeWithAnimation()
                }

                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("保存")
                    enabled: editVpnDialog.interfaceName.length > 0
                    inactiveColour: Colours.palette.m3primaryContainer
                    inactiveOnColour: Colours.palette.m3onPrimaryContainer

                    onClicked: {
                        const providers = [];
                        const oldProvider = Config.utilities.vpn.provider[editVpnDialog.editIndex];
                        const wasEnabled = typeof oldProvider === "object" ? (oldProvider.enabled !== false) : true;

                        for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                            if (i === editVpnDialog.editIndex) {
                                providers.push({
                                    name: editVpnDialog.providerName,
                                    displayName: editVpnDialog.displayName || editVpnDialog.interfaceName,
                                    interface: editVpnDialog.interfaceName,
                                    enabled: wasEnabled
                                });
                            } else {
                                providers.push(Config.utilities.vpn.provider[i]);
                            }
                        }

                        Config.utilities.vpn.provider = providers;
                        Config.markDirty("utilities");
                        editVpnDialog.closeWithAnimation();
                    }
                }
            }
        }
    }
}
