pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    anchors.fill: parent

    // ── 当前选中的输出 ──
    property string selectedOutput: DisplayService.outputList.length > 0 ? DisplayService.outputList[0].name : ""

    readonly property var selectedObj: DisplayService.outputs[root.selectedOutput] ?? null
    readonly property bool selectedEnabled: !!root.selectedObj?.logical
    readonly property var selectedLogical: root.selectedObj?.logical ?? null
    readonly property var selectedMode: {
        // 显式依赖 selectedObj，确保 DisplayService 刷新后这个绑定也会重新求值
        void root.selectedObj;
        const modes = DisplayService.getModes(root.selectedOutput);
        for (const m of modes) {
            if (m.current)
                return m;
        }
        return null;
    }

    function currentResolutionLabel(name): string {
        const m = DisplayService.getModes(name).find(m => m.current);
        return m ? `${m.width}×${m.height}` : qsTr("未知");
    }

    // 修改输出缩放会改变 Wayland output 的 scale / DPI。
    // 如果“设置”这个浮动窗口还开着，Quickshell/Qt 会在收到 scale 事件时崩溃，
    // 所以必须先关闭设置窗口再应用缩放。
    function applyScale(scale: real): void {
        const name = root.selectedOutput;
        const current = root.selectedLogical?.scale ?? 1;
        if (Math.abs(current - scale) < 0.001)
            return;

        if (root.session?.root?.close)
            root.session.root.close();
        DisplayService.setScale(name, scale);
    }

    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: Appearance.padding.md
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.md
        color: "transparent"
        radius: Appearance.rounding.normal
        clip: true

        StyledFlickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Appearance.padding.xl + Appearance.padding.md
            anchors.leftMargin: Appearance.padding.xl
            anchors.rightMargin: Appearance.padding.xl

            flickableDirection: Flickable.VerticalFlick
            contentHeight: layout.height
            clip: false

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flick
            }

            ColumnLayout {
                id: layout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.sm

                // ── 标题 ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.md

                    StyledText {
                        text: qsTr("显示器")
                        font.pointSize: Appearance.font.size.titleMedium
                        font.weight: 500
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const total = DisplayService.outputList.length;
                            const on = DisplayService.outputList.filter(o => DisplayService.isEnabled(o.name)).length;
                            return qsTr("%1 台显示器，%2 台已启用").arg(total).arg(on);
                        }
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.bodySmall
                    }
                }

                // ── 输出选择卡片 ──
                RowLayout {
                    spacing: Appearance.spacing.sm
                    Layout.fillWidth: true

                    Repeater {
                        model: DisplayService.outputList

                        delegate: StyledRect {
                            id: chip

                            required property var modelData

                            readonly property bool selected: root.selectedOutput === modelData.name
                            readonly property bool on: DisplayService.isEnabled(modelData.name)

                            Layout.fillWidth: true
                            Layout.maximumWidth: 260
                            implicitHeight: chipCol.implicitHeight + Appearance.padding.md * 2

                            radius: Appearance.rounding.normal
                            color: selected ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainer, 2)

                            StateLayer {
                                color: chip.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                function onClicked(): void {
                                    root.selectedOutput = chip.modelData.name;
                                }
                            }

                            ColumnLayout {
                                id: chipCol

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: Appearance.padding.md
                                spacing: Appearance.spacing.xs

                                RowLayout {
                                    spacing: Appearance.spacing.sm

                                    MaterialIcon {
                                        text: chip.on ? "monitor" : "monitor_off"
                                        color: chip.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Appearance.font.size.bodyLarge
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: chip.modelData.name
                                        color: chip.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                        font.pointSize: Appearance.font.size.bodyMedium
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: {
                                        if (!chip.on)
                                            return qsTr("已禁用");
                                        const m = DisplayService.getModes(chip.modelData.name).find(m => m.current);
                                        if (m) {
                                            const l = chip.modelData.logical;
                                            const scalePart = l && l.scale !== 1 ? qsTr(" · %1%").arg(Math.round(l.scale * 100)) : "";
                                            return `${m.label}${scalePart}`;
                                        }
                                        return qsTr("已启用");
                                    }
                                    color: chip.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Appearance.font.size.labelLarge
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                // ── 电源与 VRR ──
                CollapsibleSection {
                    Layout.fillWidth: true
                    title: qsTr("电源与可变刷新率")
                    description: qsTr("开启 / 关闭选中的显示器；关闭后拔插或重新开启即可恢复")
                    expanded: true
                    showBackground: true

                    ColumnLayout {
                        spacing: Appearance.spacing.sm
                        Layout.fillWidth: true

                        SwitchRow {
                            label: qsTr("启用显示器（%1）").arg(root.selectedOutput)
                            checked: root.selectedEnabled
                            onToggled: checked => {
                                DisplayService.setEnabled(root.selectedOutput, checked);
                            }
                        }

                        SwitchRow {
                            visible: root.selectedObj?.vrr_supported ?? false
                            label: qsTr("可变刷新率 (VRR / FreeSync)")
                            checked: root.selectedObj?.vrr_enabled ?? false
                            enabled: root.selectedEnabled
                            onToggled: checked => {
                                DisplayService.setVrr(root.selectedOutput, checked);
                            }
                        }
                    }
                }

                // ── 分辨率与刷新率 ──
                CollapsibleSection {
                    Layout.fillWidth: true
                    title: qsTr("分辨率与刷新率")
                    description: qsTr("选择显示器支持的分辨率与刷新率组合")
                    expanded: true
                    showBackground: true

                    ColumnLayout {
                        spacing: Appearance.spacing.sm
                        Layout.fillWidth: true

                        SectionContainer {
                            contentSpacing: Appearance.spacing.sm

                            DropdownRow {
                                Layout.fillWidth: true
                                enabled: root.selectedEnabled

                                label: qsTr("分辨率")
                                options: {
                                    const list = DisplayService.getResolutions(root.selectedOutput);
                                    return list.map(r => ({
                                                value: `${r.width}x${r.height}`,
                                                label: r.label + (DisplayService.getModes(root.selectedOutput).some(m => m.width === r.width && m.height === r.height && m.preferred) ? qsTr("（首选）") : "")
                                            }));
                                }
                                currentLabel: root.selectedMode ? `${root.selectedMode.width}×${root.selectedMode.height}` : qsTr("未知")

                                onOptionPicked: option => {
                                    const rates = DisplayService.getRefreshRates(root.selectedOutput, option.value.split("x")[0] * 1, option.value.split("x")[1] * 1);
                                    if (rates.length === 0)
                                        return;
                                    let pick = rates.find(m => m.preferred) ?? rates[0];
                                    DisplayService.setMode(root.selectedOutput, pick.modeStr);
                                }
                            }

                            DropdownRow {
                                Layout.fillWidth: true
                                enabled: root.selectedEnabled && root.selectedMode !== null

                                label: qsTr("刷新率")
                                options: {
                                    if (!root.selectedMode)
                                        return [];
                                    const rates = DisplayService.getRefreshRates(root.selectedOutput, root.selectedMode.width, root.selectedMode.height);
                                    return rates.map(m => ({
                                                value: m.modeStr,
                                                label: `${Number(m.refresh.toFixed(3))}Hz` + (m.preferred ? qsTr("（首选）") : "")
                                            }));
                                }
                                currentLabel: root.selectedMode ? `${Number(root.selectedMode.refresh.toFixed(3))}Hz` : "—"

                                onOptionPicked: option => {
                                    DisplayService.setMode(root.selectedOutput, option.value);
                                }
                            }
                        }
                    }
                }

                // ── 缩放 ──
                CollapsibleSection {
                    Layout.fillWidth: true
                    title: qsTr("界面缩放")
                    description: qsTr("调整 UI 缩放比例，高分屏笔记本建议 125% 或 150%")
                    expanded: true
                    showBackground: true

                    ColumnLayout {
                        spacing: Appearance.spacing.sm
                        Layout.fillWidth: true

                        SectionContainer {
                            contentSpacing: Appearance.spacing.sm

                            RowLayout {
                                spacing: Appearance.spacing.sm
                                Layout.fillWidth: true

                                Repeater {
                                    model: [1, 1.25, 1.5, 2]

                                    delegate: ToggleButton {
                                        required property var modelData

                                        readonly property real scaleVal: modelData
                                        readonly property real currentScale: root.selectedLogical?.scale ?? 1

                                        toggled: Math.abs(currentScale - scaleVal) < 0.001
                                        label: `${Math.round(scaleVal * 100)}%`
                                        enabled: root.selectedEnabled

                                        onClicked: {
                                            root.applyScale(scaleVal);
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                spacing: Appearance.spacing.md
                                Layout.fillWidth: true

                                StyledText {
                                    text: qsTr("自定义")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Appearance.font.size.labelLarge
                                }

                                StyledSlider {
                                    id: scaleSlider

                                    Layout.fillWidth: true
                                    from: 0.5
                                    to: 3
                                    stepSize: 0.05
                                    value: root.selectedLogical?.scale ?? 1
                                    enabled: root.selectedEnabled

                                    onPressedChanged: {
                                        if (!pressed) {
                                            const v = Math.round(value * 20) / 20;
                                            root.applyScale(v);
                                        }
                                    }
                                }

                                StyledText {
                                    text: `${Math.round((root.selectedLogical?.scale ?? 1) * 100)}%`
                                    font.pointSize: Appearance.font.size.labelLarge
                                    Layout.preferredWidth: 60
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }

                // ── 旋转方向 ──
                CollapsibleSection {
                    Layout.fillWidth: true
                    title: qsTr("旋转方向")
                    description: qsTr("竖屏看文档 / 写代码可将显示器旋转 90° 或 270°")
                    expanded: false
                    showBackground: true

                    ColumnLayout {
                        spacing: Appearance.spacing.sm
                        Layout.fillWidth: true

                        SectionContainer {
                            contentSpacing: Appearance.spacing.sm

                            RowLayout {
                                spacing: Appearance.spacing.sm
                                Layout.fillWidth: true

                                Repeater {
                                    model: [{
                                            "value": "normal",
                                            "label": qsTr("正常")
                                        }, {
                                            "value": "90",
                                            "label": qsTr("90°")
                                        }, {
                                            "value": "180",
                                            "label": qsTr("180°")
                                        }, {
                                            "value": "270",
                                            "label": qsTr("270°")
                                        }]

                                    delegate: ToggleButton {
                                        required property var modelData

                                        toggled: DisplayService.getTransform(root.selectedOutput) === modelData.value
                                        label: modelData.label
                                        enabled: root.selectedEnabled

                                        onClicked: {
                                            DisplayService.setTransform(root.selectedOutput, modelData.value);
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                // ── 排列布局 ──
                CollapsibleSection {
                    Layout.fillWidth: true
                    title: qsTr("排列布局")
                    description: qsTr("拖拽屏幕方块调整相对位置，松手后自动吸附对齐；鼠标从对应边缘滑入另一台屏幕")
                    expanded: true
                    showBackground: true

                    ColumnLayout {
                        spacing: Appearance.spacing.sm
                        Layout.fillWidth: true

                        SectionContainer {
                            contentSpacing: Appearance.spacing.sm

                            ArrangeCanvas {
                                Layout.fillWidth: true
                                implicitHeight: 220
                                selectedName: root.selectedOutput
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: DisplayService.outputList.filter(o => DisplayService.isEnabled(o.name)).length <= 1
                                text: qsTr("当前只有一台显示器启用，启用更多显示器后可在此排列相对位置")
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Appearance.font.size.labelLarge
                                wrapMode: Text.Wrap
                            }

                            RowLayout {
                                spacing: Appearance.spacing.sm
                                Layout.fillWidth: true

                                ToggleButton {
                                    toggled: false
                                    icon: "auto_awesome"
                                    label: qsTr("自动排列")
                                    enabled: root.selectedEnabled

                                    onClicked: {
                                        DisplayService.setAutoPosition(root.selectedOutput);
                                    }
                                }

                                ToggleButton {
                                    readonly property bool atOrigin: {
                                        const l = root.selectedLogical;
                                        return l ? (l.x === 0 && l.y === 0) : false;
                                    }

                                    toggled: atOrigin
                                    icon: "star"
                                    label: qsTr("设为主显示器（移至原点）")
                                    enabled: root.selectedEnabled && !atOrigin

                                    onClicked: {
                                        DisplayService.setPosition(root.selectedOutput, 0, 0);
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Niri 没有原生的主显示器概念，位于原点 (0,0) 的屏幕通常被视为主屏幕")
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Appearance.font.size.labelLarge
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 下拉选择行 ──
    component DropdownRow: StyledRect {
        id: dd

        required property string label
        property var options: []
        property string currentLabel: ""
        signal optionPicked(var option)

        property bool expanded: false

        Layout.fillWidth: true
        implicitHeight: ddHeader.implicitHeight + (dd.expanded ? ddOptions.implicitHeight : 0) + Appearance.padding.md * 2
        radius: Appearance.rounding.small
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        clip: true

        Behavior on implicitHeight {
            Anim {}
        }

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding.md
            spacing: 0

            Item {
                id: ddHeader

                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight

                RowLayout {
                    id: headerRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.spacing.sm

                    StyledText {
                        text: dd.label
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.bodySmall
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: dd.currentLabel
                        font.pointSize: Appearance.font.size.bodyMedium
                        font.bold: true
                    }

                    MaterialIcon {
                        text: dd.expanded ? "expand_less" : "expand_more"
                        color: Colours.palette.m3onSurfaceVariant
                        animate: true
                    }
                }

                StateLayer {
                    function onClicked(): void {
                        dd.expanded = !dd.expanded;
                    }
                }
            }

            ColumnLayout {
                id: ddOptions

                visible: dd.expanded
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.xs
                spacing: 0

                Repeater {
                    model: dd.options

                    delegate: StyledRect {
                        id: optRow

                        required property var modelData

                        readonly property bool active: modelData.label === dd.currentLabel

                        Layout.fillWidth: true
                        implicitHeight: optText.implicitHeight + Appearance.padding.sm * 2
                        radius: Appearance.rounding.small
                        color: active ? Colours.palette.m3secondaryContainer : "transparent"

                        StateLayer {
                            color: Colours.palette.m3onSurface
                            function onClicked(): void {
                                dd.optionPicked(optRow.modelData);
                                dd.expanded = false;
                            }
                        }

                        StyledText {
                            id: optText

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Appearance.padding.sm
                            text: optRow.modelData.label
                            color: optRow.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            font.pointSize: Appearance.font.size.bodyMedium
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // ── 排列画布 ──
    component ArrangeCanvas: Item {
        id: canvas

        property string selectedName: ""

        readonly property var items: {
            const list = [];
            for (const o of DisplayService.outputList) {
                const l = DisplayService.getLogical(o.name);
                if (!l)
                    continue;
                list.push({
                    name: o.name,
                    x: l.x,
                    y: l.y,
                    w: l.width,
                    h: l.height
                });
            }
            return list;
        }

        readonly property var bbox: {
            if (canvas.items.length === 0)
                return {
                    x: 0,
                    y: 0,
                    w: 1,
                    h: 1
                };
            let minX = Infinity;
            let minY = Infinity;
            let maxX = -Infinity;
            let maxY = -Infinity;
            for (const it of canvas.items) {
                if (it.x < minX)
                    minX = it.x;
                if (it.y < minY)
                    minY = it.y;
                if (it.x + it.w > maxX)
                    maxX = it.x + it.w;
                if (it.y + it.h > maxY)
                    maxY = it.y + it.h;
            }
            return {
                x: minX,
                y: minY,
                w: maxX - minX,
                h: maxY - minY
            };
        }

        readonly property real factor: canvas.items.length > 0 ? Math.min(canvas.width / canvas.bbox.w, canvas.height / canvas.bbox.h) * 0.85 : 1
        readonly property real offsetX: (canvas.width - canvas.bbox.w * canvas.factor) / 2
        readonly property real offsetY: (canvas.height - canvas.bbox.h * canvas.factor) / 2

        // 吸附算法：拖拽结束后，将目标矩形吸附到最近矩形的最贴近一侧
        function applyPosition(name, lx, ly) {
            const d = canvas.items.find(it => it.name === name);
            if (!d)
                return;
            const others = canvas.items.filter(it => it.name !== name);
            if (others.length === 0) {
                DisplayService.setPosition(name, lx, ly);
                return;
            }
            const dcx = lx + d.w / 2;
            const dcy = ly + d.h / 2;
            let best = null;
            let bestDist = Infinity;
            for (const o of others) {
                const dist = Math.hypot(dcx - (o.x + o.w / 2), dcy - (o.y + o.h / 2));
                if (dist < bestDist) {
                    bestDist = dist;
                    best = o;
                }
            }
            const dx = dcx - (best.x + best.w / 2);
            const dy = dcy - (best.y + best.h / 2);
            let nx;
            let ny;
            if (Math.abs(dx) >= Math.abs(dy)) {
                nx = dx > 0 ? best.x + best.w : best.x - d.w;
                ny = best.y + Math.round((best.h - d.h) / 2);
            } else {
                nx = best.x + Math.round((best.w - d.w) / 2);
                ny = dy > 0 ? best.y + best.h : best.y - d.h;
            }
            DisplayService.setPosition(name, nx, ny);
        }

        Repeater {
            model: canvas.items

            delegate: Item {
                id: slot

                required property var modelData

                readonly property bool selected: modelData.name === canvas.selectedName

                x: (modelData.x - canvas.bbox.x) * canvas.factor + canvas.offsetX
                y: (modelData.y - canvas.bbox.y) * canvas.factor + canvas.offsetY
                width: modelData.w * canvas.factor
                height: modelData.h * canvas.factor

                Rectangle {
                    id: box

                    property real dx: 0
                    property real dy: 0

                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: slot.selected ? Qt.alpha(Colours.palette.m3secondaryContainer, 0.9) : Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.9)
                    border.width: 2
                    border.color: slot.selected ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                    transform: Translate {
                        x: box.dx
                        y: box.dy
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        width: Math.min(parent.width - 8, 260)

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: slot.modelData.name
                            color: slot.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            font.pointSize: Appearance.font.size.bodyMedium
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.maximumWidth: parent.width
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: `${slot.modelData.w}×${slot.modelData.h}`
                            color: slot.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.labelLarge
                            Layout.maximumWidth: parent.width
                        }
                    }

                    MouseArea {
                        id: dragArea

                        property real lastX: 0
                        property real lastY: 0

                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        hoverEnabled: false

                        onPressed: mouse => {
                            lastX = mouse.x;
                            lastY = mouse.y;
                        }

                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            box.dx += mouse.x - lastX;
                            box.dy += mouse.y - lastY;
                            lastX = mouse.x;
                            lastY = mouse.y;
                        }

                        onReleased: {
                            const lx = slot.modelData.x + box.dx / canvas.factor;
                            const ly = slot.modelData.y + box.dy / canvas.factor;
                            box.dx = 0;
                            box.dy = 0;
                            canvas.applyPosition(slot.modelData.name, lx, ly);
                        }
                    }
                }
            }
        }
    }
}
