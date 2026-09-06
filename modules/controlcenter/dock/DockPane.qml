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

    // Dock
    property bool enabled: Config.dock.enabled ?? true
    property bool showOnHover: Config.dock.showOnHover ?? false
    property string position: Config.dock.position ?? "center"
    property int bottomMargin: Config.dock.bottomMargin ?? 10
    property bool showTooltip: Config.dock.showTooltip ?? true
    property bool showSeparator: Config.dock.showSeparator ?? true
    property bool showDynamicApps: Config.dock.showDynamicApps ?? true
    property int settleDuration: Config.dock.settleDuration ?? 160

    // Sizes
    property int iconSize: Config.dock.sizes.iconSize ?? 48
    property int iconGap: Config.dock.sizes.iconGap ?? 14
    property int hPad: Config.dock.sizes.hPad ?? 16
    property int vPad: Config.dock.sizes.vPad ?? 10
    property int indicatorGap: Config.dock.sizes.indicatorGap ?? 6

    // Media bar (desktop lyrics)
    property bool mediaEnabled: Config.dock.media.enabled ?? true
    property bool mediaAutoHide: Config.dock.media.autoHide ?? true
    property bool mediaCompact: Config.dock.media.compact ?? false
    property bool mediaShowControls: Config.dock.media.showControls ?? true
    property bool mediaShowSecondary: Config.dock.media.showSecondary ?? true
    property int mediaWidth: Config.dock.media.width ?? 420
    property int mediaRightMargin: Config.dock.media.rightMargin ?? 12
    property int mediaBottomMargin: Config.dock.media.bottomMargin ?? 10

    // Visualiser
    property bool vizEnabled: Config.dock.visualiser.enabled ?? true
    property bool vizAutoHide: Config.dock.visualiser.autoHide ?? true
    property int vizBarWidth: Config.dock.visualiser.barWidth ?? 4
    property int vizBarGap: Config.dock.visualiser.barGap ?? 4
    property int vizBarHeight: Config.dock.visualiser.barHeight ?? 48
    property int vizMinBars: Config.dock.visualiser.minBarCount ?? 14
    property int vizMaxBars: Config.dock.visualiser.maxBarCount ?? 96
    property int vizWidth: Config.dock.visualiser.width ?? 0
    property real vizAutoWidthDivisor: Config.dock.visualiser.autoWidthDivisor ?? 5.5
    property int vizLeftMargin: Config.dock.visualiser.leftMargin ?? 10
    property int vizBottomMargin: Config.dock.visualiser.bottomMargin ?? 10
    property int vizAnimDuration: Config.dock.visualiser.animDuration ?? 90

    property string searchText: ""

    anchors.fill: parent

    Component.onCompleted: {
        if (Config.initialLoadComplete) {
            root.syncEntriesFromConfig();
        }
    }

    Connections {
        target: Config
        function onConfigLoaded() {
            root.syncEntriesFromConfig();
        }
    }

    property bool _entriesSynced: false

    // The settings panel can be opened before the config file has finished
    // loading. In that case Config.dock.pinnedApps still holds the schema
    // defaults, so syncing early would overwrite the user's real list on the
    // next save. Only sync once the config is actually loaded.
    function syncEntriesFromConfig(): void {
        if (root._entriesSynced)
            return;
        root._entriesSynced = true;

        entriesModel.clear();
        const apps = Config.dock.pinnedApps ?? [];
        for (let i = 0; i < apps.length; i++) {
            const app = apps[i];
            entriesModel.append({
                id: app.id,
                exec: app.exec ?? "",
                icon: app.icon ?? "",
                match: (app.match ?? []).join("|"),
                name: app.name ?? "",
                enabled: app.enabled !== false
            });
        }
    }

    function resolveAppName(entry: var): string {
        if (entry?.name)
            return entry.name;
        const id = String(entry?.id ?? "").replace(/\.desktop$/i, "");
        const resolved = DesktopEntries.byId(id)
            || DesktopEntries.heuristicLookup(id)
            || DesktopEntries.heuristicLookup(String(entry?.exec ?? ""));
        return resolved?.name || id || String(entry?.exec ?? "");
    }

    readonly property var searchResults: root.computeSearchResults()

    function computeSearchResults(): var {
        const q = root.searchText.trim().toLowerCase();
        if (!q)
            return [];

        const values = DesktopEntries.applications.values;
        const existing = new Set();
        for (let i = 0; i < entriesModel.count; i++) {
            existing.add(String(entriesModel.get(i).id).toLowerCase());
        }

        const out = [];
        for (let i = 0; i < values.length && out.length < 8; i++) {
            const e = values[i];
            if (!e)
                continue;
            if (existing.has(String(e.id ?? "").toLowerCase()))
                continue;

            const hay = String(e.name ?? "").toLowerCase()
                + " " + String(e.id ?? "").toLowerCase()
                + " " + String(e.genericName ?? "").toLowerCase()
                + " " + String(e.comment ?? "").toLowerCase();
            if (hay.includes(q))
                out.push(e);
        }
        return out;
    }

    function addApp(entry: var): void {
        if (!entry || !entry.id) {
            console.warn("[DockPane] addApp: invalid entry");
            return;
        }
        const exec = (entry?.command && entry.command.length > 0)
            ? entry.command[0]
            : (entry?.execString ?? entry?.id ?? "");
        entriesModel.append({
            id: entry?.id ?? exec,
            exec: exec,
            icon: entry?.icon ?? entry?.id ?? exec,
            match: [entry?.id, entry?.startupClass].filter(v => !!v).join("|"),
            name: entry?.name ?? "",
            enabled: true
        });
        root.searchText = "";
        root.saveConfig();
    }

    function removeEntry(index: int): void {
        entriesModel.remove(index);
        root.saveConfig();
    }

    function moveEntry(index: int, delta: int): void {
        const target = index + delta;
        if (index < 0 || target < 0 || target >= entriesModel.count)
            return;

        // ListModel.get() returns live references to internal objects and
        // set() mutates them in place, so swapping two items via get/set
        // corrupts the model (duplicate entries). Rebuild instead.
        const items = [];
        for (let i = 0; i < entriesModel.count; i++) {
            const e = entriesModel.get(i);
            items.push({
                id: e.id,
                exec: e.exec,
                icon: e.icon,
                match: e.match,
                name: e.name,
                enabled: e.enabled
            });
        }
        const tmp = items[index];
        items[index] = items[target];
        items[target] = tmp;
        entriesModel.clear();
        for (let i = 0; i < items.length; i++)
            entriesModel.append(items[i]);
        root.saveConfig();
    }

    // NOTE: do not type these parameters. QML gives untyped `int`/`bool`
    // parameters default values (0 / false) when omitted, which silently
    // disabled the first pinned app on every add/remove/move.
    function saveConfig(entryIndex, entryEnabled) {
        Config.dock.enabled = root.enabled;
        Config.dock.showOnHover = root.showOnHover;
        Config.dock.position = root.position;
        Config.dock.bottomMargin = root.bottomMargin;
        Config.dock.showTooltip = root.showTooltip;
        Config.dock.showSeparator = root.showSeparator;
        Config.dock.showDynamicApps = root.showDynamicApps;
        Config.dock.settleDuration = root.settleDuration;

        Config.dock.sizes.iconSize = root.iconSize;
        Config.dock.sizes.iconGap = root.iconGap;
        Config.dock.sizes.hPad = root.hPad;
        Config.dock.sizes.vPad = root.vPad;
        Config.dock.sizes.indicatorGap = root.indicatorGap;

        Config.dock.media.enabled = root.mediaEnabled;
        Config.dock.media.autoHide = root.mediaAutoHide;
        Config.dock.media.compact = root.mediaCompact;
        Config.dock.media.showControls = root.mediaShowControls;
        Config.dock.media.showSecondary = root.mediaShowSecondary;
        Config.dock.media.width = root.mediaWidth;
        Config.dock.media.rightMargin = root.mediaRightMargin;
        Config.dock.media.bottomMargin = root.mediaBottomMargin;

        Config.dock.visualiser.enabled = root.vizEnabled;
        Config.dock.visualiser.autoHide = root.vizAutoHide;
        Config.dock.visualiser.barWidth = root.vizBarWidth;
        Config.dock.visualiser.barGap = root.vizBarGap;
        Config.dock.visualiser.barHeight = root.vizBarHeight;
        Config.dock.visualiser.minBarCount = root.vizMinBars;
        Config.dock.visualiser.maxBarCount = root.vizMaxBars;
        Config.dock.visualiser.width = root.vizWidth;
        Config.dock.visualiser.autoWidthDivisor = root.vizAutoWidthDivisor;
        Config.dock.visualiser.leftMargin = root.vizLeftMargin;
        Config.dock.visualiser.bottomMargin = root.vizBottomMargin;
        Config.dock.visualiser.animDuration = root.vizAnimDuration;

        const apps = [];
        for (let i = 0; i < entriesModel.count; i++) {
            const entry = entriesModel.get(i);
            let enabled = entry.enabled;
            if (entryIndex !== undefined && i === entryIndex) {
                enabled = entryEnabled;
            }
            apps.push({
                id: entry.id,
                exec: entry.exec,
                icon: entry.icon,
                match: entry.match ? entry.match.split("|").filter(v => v.length > 0) : [],
                enabled: enabled
            });
        }
        Config.dock.pinnedApps = apps;
        Config.markDirty("dock");
    }

    ListModel {
        id: entriesModel
    }

    // Debug helpers (no production impact)
    readonly property int entryInfoCount: entriesModel.count
    function entryInfo(i: int): string {
        if (i < 0 || i >= entriesModel.count)
            return "null";
        const e = entriesModel.get(i);
        return `${e?.id ?? "?"}:${e?.enabled ?? "?"}`;
    }

    ClippingRectangle {
        id: dockClippingRect
        anchors.fill: parent
        anchors.margins: Appearance.padding.md
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.md

        radius: dockBorder.innerRadius
        color: "transparent"

        Loader {
            id: dockLoader

            anchors.fill: parent
            anchors.margins: Appearance.padding.xl + Appearance.padding.md
            anchors.leftMargin: Appearance.padding.xl
            anchors.rightMargin: Appearance.padding.xl

            sourceComponent: dockContentComponent
        }
    }

    InnerBorder {
        id: dockBorder
        leftThickness: 0
        rightThickness: Appearance.padding.md
    }

    Component {
        id: dockContentComponent

        StyledFlickable {
            id: dockFlickable
            flickableDirection: Flickable.VerticalFlick
            contentHeight: dockLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: dockFlickable
            }

            ColumnLayout {
                id: dockLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                spacing: Appearance.spacing.lg

                RowLayout {
                    spacing: Appearance.spacing.md

                    StyledText {
                        text: qsTr("Dock栏")
                        font.pointSize: Appearance.font.size.titleMedium
                        font.weight: 500
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        text: qsTr("常规设置")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    SwitchRow {
                        label: qsTr("已启用")
                        checked: root.enabled
                        onToggled: checked => {
                            root.enabled = checked;
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

                    SplitButtonRow {
                        label: qsTr("位置")
                        enabled: root.enabled

                        menuItems: [
                            MenuItem {
                                text: qsTr("左")
                                icon: "align_horizontal_left"
                                property string val: "left"
                            },
                            MenuItem {
                                text: qsTr("居中")
                                icon: "align_horizontal_center"
                                property string val: "center"
                            },
                            MenuItem {
                                text: qsTr("右")
                                icon: "align_horizontal_right"
                                property string val: "right"
                            }
                        ]

                        Component.onCompleted: {
                            for (let i = 0; i < menuItems.length; i++) {
                                if (menuItems[i].val === root.position)
                                    active = menuItems[i];
                            }
                        }

                        onSelected: item => {
                            root.position = item.val;
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("底部边距")
                        value: root.bottomMargin
                        from: 0
                        to: 80
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 80 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.bottomMargin = Math.round(newValue);
                            root.saveConfig();
                        }
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        text: qsTr("置顶应用")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("固定显示在 Dock 中的应用，取消勾选后从 Dock 隐藏")
                        font.pointSize: Appearance.font.size.labelMedium
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                    }

                    StyledInputField {
                        id: pinnedSearchField

                        Layout.fillWidth: true
                        placeholderText: qsTr("搜索并添加应用…")
                        horizontalAlignment: Text.AlignLeft
                        onTextEdited: root.searchText = text
                    }

                    Repeater {
                        model: root.searchResults

                        delegate: StyledRect {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: row.implicitHeight + Appearance.padding.sm * 2
                            radius: Appearance.rounding.small
                            color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                            RowLayout {
                                id: row

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: Appearance.padding.sm
                                spacing: Appearance.spacing.sm

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData?.name ?? modelData?.id ?? ""
                                    font.pointSize: Appearance.font.size.bodySmall
                                    elide: Text.ElideRight
                                }

                                IconButton {
                                    icon: "add"
                                    type: IconButton.Text
                                    onClicked: {
                                        root.addApp(modelData);
                                        pinnedSearchField.text = "";
                                    }
                                }
                            }

                            MouseArea {
                                z: -1
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.addApp(modelData);
                                    pinnedSearchField.text = "";
                                }
                            }
                        }
                    }

                    Repeater {
                        model: entriesModel

                        delegate: RowLayout {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            spacing: Appearance.spacing.sm

                            SwitchRow {
                                Layout.fillWidth: true

                                label: root.resolveAppName(modelData)
                                checked: modelData.enabled
                                onToggled: checked => {
                                    entriesModel.setProperty(index, "enabled", checked);
                                    root.saveConfig(index, checked);
                                }
                            }

                            IconButton {
                                icon: "arrow_upward"
                                type: IconButton.Text
                                disabled: index === 0
                                onClicked: root.moveEntry(index, -1)
                            }

                            IconButton {
                                icon: "arrow_downward"
                                type: IconButton.Text
                                disabled: index === entriesModel.count - 1
                                onClicked: root.moveEntry(index, 1)
                            }

                            IconButton {
                                icon: "close"
                                type: IconButton.Text
                                onClicked: root.removeEntry(index)
                            }
                        }
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        text: qsTr("显示")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    SwitchRow {
                        label: qsTr("悬停提示条")
                        checked: root.showTooltip
                        onToggled: checked => {
                            root.showTooltip = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        label: qsTr("显示分隔符")
                        checked: root.showSeparator
                        onToggled: checked => {
                            root.showSeparator = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        label: qsTr("显示运行中的应用")
                        checked: root.showDynamicApps
                        onToggled: checked => {
                            root.showDynamicApps = checked;
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("回缩动画时长")
                        value: root.settleDuration
                        from: 0
                        to: 600
                        suffix: "ms"
                        validator: IntValidator { bottom: 0; top: 600 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.settleDuration = Math.round(newValue);
                            root.saveConfig();
                        }
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        text: qsTr("尺寸")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("图标大小")
                        value: root.iconSize
                        from: 28
                        to: 72
                        suffix: "px"
                        validator: IntValidator { bottom: 28; top: 72 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.iconSize = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("图标间距")
                        value: root.iconGap
                        from: 0
                        to: 40
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 40 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.iconGap = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("横向内边距")
                        value: root.hPad
                        from: 0
                        to: 48
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 48 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.hPad = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("纵向内边距")
                        value: root.vPad
                        from: 0
                        to: 32
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 32 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.vPad = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("指示点间距")
                        value: root.indicatorGap
                        from: 0
                        to: 20
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 20 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.indicatorGap = Math.round(newValue);
                            root.saveConfig();
                        }
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        text: qsTr("媒体栏（桌面歌词）")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    SwitchRow {
                        label: qsTr("已启用")
                        checked: root.mediaEnabled
                        onToggled: checked => {
                            root.mediaEnabled = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        label: qsTr("无媒体时自动隐藏")
                        checked: root.mediaAutoHide
                        onToggled: checked => {
                            root.mediaAutoHide = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        label: qsTr("紧凑模式")
                        checked: root.mediaCompact
                        onToggled: checked => {
                            root.mediaCompact = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        label: qsTr("显示控制按钮")
                        checked: root.mediaShowControls
                        onToggled: checked => {
                            root.mediaShowControls = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        label: qsTr("显示副信息")
                        checked: root.mediaShowSecondary
                        onToggled: checked => {
                            root.mediaShowSecondary = checked;
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("宽度")
                        value: root.mediaWidth
                        from: 240
                        to: 720
                        suffix: "px"
                        validator: IntValidator { bottom: 240; top: 720 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.mediaWidth = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("右侧边距")
                        value: root.mediaRightMargin
                        from: 0
                        to: 80
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 80 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.mediaRightMargin = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("底部边距")
                        value: root.mediaBottomMargin
                        from: 0
                        to: 80
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 80 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.mediaBottomMargin = Math.round(newValue);
                            root.saveConfig();
                        }
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        text: qsTr("音频可视化")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    SwitchRow {
                        label: qsTr("已启用")
                        checked: root.vizEnabled
                        onToggled: checked => {
                            root.vizEnabled = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        label: qsTr("无媒体时自动隐藏")
                        checked: root.vizAutoHide
                        onToggled: checked => {
                            root.vizAutoHide = checked;
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("条宽")
                        value: root.vizBarWidth
                        from: 2
                        to: 12
                        suffix: "px"
                        validator: IntValidator { bottom: 2; top: 12 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.vizBarWidth = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("条间距")
                        value: root.vizBarGap
                        from: 0
                        to: 16
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 16 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.vizBarGap = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("条高")
                        value: root.vizBarHeight
                        from: 16
                        to: 160
                        suffix: "px"
                        validator: IntValidator { bottom: 16; top: 160 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.vizBarHeight = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("宽度(0=自动)")
                        value: root.vizWidth
                        from: 0
                        to: 800
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 800 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.vizWidth = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("左边距")
                        value: root.vizLeftMargin
                        from: 0
                        to: 80
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 80 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.vizLeftMargin = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("底部边距")
                        value: root.vizBottomMargin
                        from: 0
                        to: 80
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 80 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.vizBottomMargin = Math.round(newValue);
                            root.saveConfig();
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("动画时长")
                        value: root.vizAnimDuration
                        from: 0
                        to: 300
                        suffix: "ms"
                        validator: IntValidator { bottom: 0; top: 300 }
                        formatValueFunction: (val) => Math.round(val).toString()
                        parseValueFunction: (text) => parseInt(text)

                        onValueModified: (newValue) => {
                            root.vizAnimDuration = Math.round(newValue);
                            root.saveConfig();
                        }
                    }
                }
            }
        }
    }
}
