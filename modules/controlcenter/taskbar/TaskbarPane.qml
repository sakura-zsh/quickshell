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
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    property bool clockShowIcon: Config.bar.clock.showIcon ?? true
    property bool clockBackground: Config.bar.clock.background ?? false
    property bool clockShowDate: Config.bar.clock.showDate ?? false
    property bool persistent: Config.bar.persistent ?? true
    property bool showOnHover: Config.bar.showOnHover ?? true
    property int dragThreshold: Config.bar.dragThreshold ?? 20
    property bool showAudio: Config.bar.status.showAudio ?? true
    property bool showMicrophone: Config.bar.status.showMicrophone ?? true
    property bool showKbLayout: Config.bar.status.showKbLayout ?? false
    property bool showNetwork: Config.bar.status.showNetwork ?? true
    property bool showWifi: Config.bar.status.showWifi ?? true
    property bool showBluetooth: Config.bar.status.showBluetooth ?? true
    property bool showBattery: Config.bar.status.showBattery ?? true
    property bool showLockStatus: Config.bar.status.showLockStatus ?? true
    property bool activeWindowCompact: Config.bar.activeWindow.compact ?? false
    property bool activeWindowInverted: Config.bar.activeWindow.inverted ?? false
    property bool trayBackground: Config.bar.tray.background ?? false
    property bool trayCompact: Config.bar.tray.compact ?? false
    property bool trayRecolour: Config.bar.tray.recolour ?? false
    property int workspacesShown: Config.bar.workspaces.shown ?? 5
    property bool workspacesActiveIndicator: Config.bar.workspaces.activeIndicator ?? true
    property bool workspacesOccupiedBg: Config.bar.workspaces.occupiedBg ?? false
    property bool workspacesShowWindows: Config.bar.workspaces.showWindows ?? false
    property bool workspacesPerMonitor: Config.bar.workspaces.perMonitorWorkspaces ?? true
    property bool scrollWorkspaces: Config.bar.scrollActions.workspaces ?? true
    property bool scrollVolume: Config.bar.scrollActions.volume ?? true
    property bool scrollBrightness: Config.bar.scrollActions.brightness ?? true
    property bool popoutTray: Config.bar.popouts.tray ?? true
    property bool popoutStatusIcons: Config.bar.popouts.statusIcons ?? true
    property bool isDistLogo: Config.general.isDistLogo ?? false

    anchors.fill: parent

    Component.onCompleted: {
        if (Config.bar.entries) {
            entriesModel.clear();
            for (let i = 0; i < Config.bar.entries.length; i++) {
                const entry = Config.bar.entries[i];
                entriesModel.append({
                    id: entry.id,
                    enabled: entry.enabled !== false
                });
            }
        }
    }

    function saveConfig(entryIndex, entryEnabled) {
        Config.bar.clock.showIcon = root.clockShowIcon;
        Config.bar.clock.background = root.clockBackground;
        Config.bar.clock.showDate = root.clockShowDate;
        Config.bar.activeWindow.compact = root.activeWindowCompact;
        Config.bar.activeWindow.inverted = root.activeWindowInverted;
        Config.bar.persistent = root.persistent;
        Config.bar.showOnHover = root.showOnHover;
        Config.bar.dragThreshold = root.dragThreshold;
        Config.bar.status.showAudio = root.showAudio;
        Config.bar.status.showMicrophone = root.showMicrophone;
        Config.bar.status.showKbLayout = root.showKbLayout;
        Config.bar.status.showNetwork = root.showNetwork;
        Config.bar.status.showWifi = root.showWifi;
        Config.bar.status.showBluetooth = root.showBluetooth;
        Config.bar.status.showBattery = root.showBattery;
        Config.bar.status.showLockStatus = root.showLockStatus;
        Config.bar.tray.background = root.trayBackground;
        Config.bar.tray.compact = root.trayCompact;
        Config.bar.tray.recolour = root.trayRecolour;
        Config.bar.workspaces.shown = root.workspacesShown;
        Config.bar.workspaces.activeIndicator = root.workspacesActiveIndicator;
        Config.bar.workspaces.occupiedBg = root.workspacesOccupiedBg;
        Config.bar.workspaces.showWindows = root.workspacesShowWindows;
        Config.bar.workspaces.perMonitorWorkspaces = root.workspacesPerMonitor;
        Config.bar.scrollActions.workspaces = root.scrollWorkspaces;
        Config.bar.scrollActions.volume = root.scrollVolume;
        Config.bar.scrollActions.brightness = root.scrollBrightness;
        Config.bar.popouts.tray = root.popoutTray;
        Config.bar.popouts.statusIcons = root.popoutStatusIcons;
        Config.general.isDistLogo = root.isDistLogo;

        const entries = [];
        for (let i = 0; i < entriesModel.count; i++) {
            const entry = entriesModel.get(i);
            let enabled = entry.enabled;
            if (entryIndex !== undefined && i === entryIndex) {
                enabled = entryEnabled;
            }
            entries.push({
                id: entry.id,
                enabled: enabled
            });
        }
        Config.bar.entries = entries;
        Config.markDirty("bar");
    }

    ListModel {
        id: entriesModel
    }

    ClippingRectangle {
        id: taskbarClippingRect
        anchors.fill: parent
        anchors.margins: Appearance.padding.md
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.md

        radius: taskbarBorder.innerRadius
        color: "transparent"

        Loader {
            id: taskbarLoader

            anchors.fill: parent
            anchors.margins: Appearance.padding.xl + Appearance.padding.md
            anchors.leftMargin: Appearance.padding.xl
            anchors.rightMargin: Appearance.padding.xl

            sourceComponent: taskbarContentComponent
        }
    }

    InnerBorder {
        id: taskbarBorder
        leftThickness: 0
        rightThickness: Appearance.padding.md
    }

    Component {
        id: taskbarContentComponent

        StyledFlickable {
            id: sidebarFlickable
            flickableDirection: Flickable.VerticalFlick
            contentHeight: sidebarLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: sidebarFlickable
            }

            ColumnLayout {
                id: sidebarLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                spacing: Appearance.spacing.lg

                RowLayout {
                    spacing: Appearance.spacing.md

                    StyledText {
                        text: qsTr("任务栏")
                        font.pointSize: Appearance.font.size.titleMedium
                        font.weight: 500
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        text: qsTr("状态图标")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    ConnectedButtonGroup {
                        rootItem: root

                        options: [
                            {
                                label: qsTr("扬声器"),
                                propertyName: "showAudio",
                                onToggled: function (checked) {
                                    root.showAudio = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("麦克风"),
                                propertyName: "showMicrophone",
                                onToggled: function (checked) {
                                    root.showMicrophone = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("键盘"),
                                propertyName: "showKbLayout",
                                onToggled: function (checked) {
                                    root.showKbLayout = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("网络"),
                                propertyName: "showNetwork",
                                onToggled: function (checked) {
                                    root.showNetwork = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("WiFi"),
                                propertyName: "showWifi",
                                onToggled: function (checked) {
                                    root.showWifi = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("蓝牙"),
                                propertyName: "showBluetooth",
                                onToggled: function (checked) {
                                    root.showBluetooth = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("电池"),
                                propertyName: "showBattery",
                                onToggled: function (checked) {
                                    root.showBattery = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("大写锁定"),
                                propertyName: "showLockStatus",
                                onToggled: function (checked) {
                                    root.showLockStatus = checked;
                                    root.saveConfig();
                                }
                            }
                        ]
                    }
                }

                RowLayout {
                    id: mainRowLayout
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.lg

                    ColumnLayout {
                        id: leftColumnLayout
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Appearance.spacing.lg

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("图标")
                                font.pointSize: Appearance.font.size.bodyMedium
                            }

                            SwitchRow {
                                label: qsTr("使用发行版徽标")
                                checked: root.isDistLogo
                                onToggled: checked => {
                                    root.isDistLogo = checked;
                                    root.saveConfig();
                                }
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("工作区")
                                font.pointSize: Appearance.font.size.bodyMedium
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: workspacesShownRow.implicitHeight + Appearance.padding.xl * 2
                                radius: Appearance.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                Behavior on implicitHeight {
                                    Anim {}
                                }

                                RowLayout {
                                    id: workspacesShownRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Appearance.padding.xl
                                    spacing: Appearance.spacing.lg

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("显示")
                                    }

                                    CustomSpinBox {
                                        min: 1
                                        max: 20
                                        value: root.workspacesShown
                                        onValueModified: value => {
                                            root.workspacesShown = value;
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: workspacesActiveIndicatorRow.implicitHeight + Appearance.padding.xl * 2
                                radius: Appearance.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                Behavior on implicitHeight {
                                    Anim {}
                                }

                                RowLayout {
                                    id: workspacesActiveIndicatorRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Appearance.padding.xl
                                    spacing: Appearance.spacing.lg

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("活动指示器")
                                    }

                                    StyledSwitch {
                                        checked: root.workspacesActiveIndicator
                                        onToggled: {
                                            root.workspacesActiveIndicator = checked;
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: workspacesOccupiedBgRow.implicitHeight + Appearance.padding.xl * 2
                                radius: Appearance.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                Behavior on implicitHeight {
                                    Anim {}
                                }

                                RowLayout {
                                    id: workspacesOccupiedBgRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Appearance.padding.xl
                                    spacing: Appearance.spacing.lg

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("已占用背景")
                                    }

                                    StyledSwitch {
                                        checked: root.workspacesOccupiedBg
                                        onToggled: {
                                            root.workspacesOccupiedBg = checked;
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: workspacesShowWindowsRow.implicitHeight + Appearance.padding.xl * 2
                                radius: Appearance.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                Behavior on implicitHeight {
                                    Anim {}
                                }

                                RowLayout {
                                    id: workspacesShowWindowsRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Appearance.padding.xl
                                    spacing: Appearance.spacing.lg

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("显示窗口")
                                    }

                                    StyledSwitch {
                                        checked: root.workspacesShowWindows
                                        onToggled: {
                                            root.workspacesShowWindows = checked;
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: workspacesPerMonitorRow.implicitHeight + Appearance.padding.xl * 2
                                radius: Appearance.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                Behavior on implicitHeight {
                                    Anim {}
                                }

                                RowLayout {
                                    id: workspacesPerMonitorRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Appearance.padding.xl
                                    spacing: Appearance.spacing.lg

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("按显示器工作区")
                                    }

                                    StyledSwitch {
                                        checked: root.workspacesPerMonitor
                                        onToggled: {
                                            root.workspacesPerMonitor = checked;
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("滚动操作")
                                font.pointSize: Appearance.font.size.bodyMedium
                            }

                            ConnectedButtonGroup {
                                rootItem: root

                                options: [
                                    {
                                        label: qsTr("工作区"),
                                        propertyName: "scrollWorkspaces",
                                        onToggled: function (checked) {
                                            root.scrollWorkspaces = checked;
                                            root.saveConfig();
                                        }
                                    },
                                    {
                                        label: qsTr("音量"),
                                        propertyName: "scrollVolume",
                                        onToggled: function (checked) {
                                            root.scrollVolume = checked;
                                            root.saveConfig();
                                        }
                                    },
                                    {
                                        label: qsTr("亮度"),
                                        propertyName: "scrollBrightness",
                                        onToggled: function (checked) {
                                            root.scrollBrightness = checked;
                                            root.saveConfig();
                                        }
                                    }
                                ]
                            }
                        }
                    }

                    ColumnLayout {
                        id: middleColumnLayout
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Appearance.spacing.lg

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("时钟")
                                font.pointSize: Appearance.font.size.bodyMedium
                            }
                            
                            SwitchRow {
                                label: qsTr("背景")
                                checked: root.clockBackground
                                onToggled: checked => {
                                    root.clockBackground = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("显示日期")
                                checked: root.clockShowDate
                                onToggled: checked => {
                                    root.clockShowDate = checked;
                                    root.saveConfig();
                                }
                            }


                            SwitchRow {
                                label: qsTr("显示时钟图标")
                                checked: root.clockShowIcon
                                onToggled: checked => {
                                    root.clockShowIcon = checked;
                                    root.saveConfig();
                                }
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("栏行为")
                                font.pointSize: Appearance.font.size.bodyMedium
                            }

                            SwitchRow {
                                label: qsTr("常驻")
                                checked: root.persistent
                                onToggled: checked => {
                                    root.persistent = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("悬停时显示")
                                checked: root.showOnHover
                                onToggled: checked => {
                                    root.showOnHover = checked;
                                    root.saveConfig();
                                }
                            }

                            SectionContainer {
                                contentSpacing: Appearance.spacing.lg

                                SliderInput {
                                    Layout.fillWidth: true

                                    label: qsTr("拖动阈值")
                                    value: root.dragThreshold
                                    from: 0
                                    to: 100
                                    suffix: "px"
                                    validator: IntValidator {
                                        bottom: 0
                                        top: 100
                                    }
                                    formatValueFunction: val => Math.round(val).toString()
                                    parseValueFunction: text => parseInt(text)

                                    onValueModified: newValue => {
                                        root.dragThreshold = Math.round(newValue);
                                        root.saveConfig();
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: rightColumnLayout
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Appearance.spacing.lg

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("弹出面板")
                                font.pointSize: Appearance.font.size.bodyMedium
                            }

                            SwitchRow {
                                label: qsTr("托盘")
                                checked: root.popoutTray
                                onToggled: checked => {
                                    root.popoutTray = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("状态图标")
                                checked: root.popoutStatusIcons
                                onToggled: checked => {
                                    root.popoutStatusIcons = checked;
                                    root.saveConfig();
                                }
                            }
                        }


                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("活动窗口")
                                font.pointSize: Appearance.font.size.normal
                            }

                            SwitchRow {
                                label: qsTr("紧凑")
                                checked: root.activeWindowCompact
                                onToggled: checked => {
                                    root.activeWindowCompact = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("反转")
                                checked: root.activeWindowInverted
                                onToggled: checked => {
                                    root.activeWindowInverted = checked;
                                    root.saveConfig();
                                }
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("托盘设置")
                                font.pointSize: Appearance.font.size.bodyMedium
                            }

                            ConnectedButtonGroup {
                                rootItem: root

                                options: [
                                    {
                                        label: qsTr("背景"),
                                        propertyName: "trayBackground",
                                        onToggled: function (checked) {
                                            root.trayBackground = checked;
                                            root.saveConfig();
                                        }
                                    },
                                    {
                                        label: qsTr("紧凑"),
                                        propertyName: "trayCompact",
                                        onToggled: function (checked) {
                                            root.trayCompact = checked;
                                            root.saveConfig();
                                        }
                                    },
                                    {
                                        label: qsTr("重新着色"),
                                        propertyName: "trayRecolour",
                                        onToggled: function (checked) {
                                            root.trayRecolour = checked;
                                            root.saveConfig();
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    }
}
