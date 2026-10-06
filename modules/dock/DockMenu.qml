pragma ComponentBehavior: Bound

import qs.components
import qs.config
import qs.modules.launcher.services
import qs.services
import Quickshell
import QtQuick
import "DockEntries.js" as DockEntries

// Right-click menu for one dock entry: open, pin, per-window focus/close.
StyledRect {
    id: root

    property var app: null
    property var windows: []
    property int maxWindows: 6

    readonly property bool hovered: hoverHandler.hovered
    readonly property var entry: DockEntries.resolveEntry(root.app, DesktopEntries)
    readonly property string appName: {
        if (root.app && root.app.name)
            return String(root.app.name);
        if (root.entry && root.entry.name)
            return String(root.entry.name);
        return String(root.app && root.app.id ? root.app.id : "");
    }
    readonly property bool pinned: {
        const list = Config.dock.pinnedApps ?? [];
        for (let i = 0; i < list.length; i++) {
            if (DockEntries.sameApp(list[i], root.app, DesktopEntries))
                return true;
        }
        return false;
    }
    readonly property int bodyWidth: 260
    readonly property var rows: root.buildRows()

    signal dismissed

    function buildRows(): var {
        const out = [];
        const wins = root.windows ?? [];
        const focusedId = String(Niri.focusedWindowId ?? "");
        const shown = Math.min(wins.length, root.maxWindows);

        for (let i = 0; i < shown; i++) {
            const win = wins[i];
            out.push({
                kind: "window",
                key: `window-${win?.id ?? i}`,
                text: String(win?.title ?? root.appName),
                icon: String(win?.id ?? "") === focusedId ? "check" : "",
                window: win
            });
        }

        if (wins.length > shown) {
            out.push({
                kind: "text",
                key: "more",
                text: qsTr("还有 %1 个窗口").arg(wins.length - shown),
                icon: ""
            });
        }

        if (wins.length > 0)
            out.push({
                kind: "separator",
                key: "sep",
                text: "",
                icon: ""
            });

        out.push({
            kind: "action",
            key: "launch",
            action: "launch",
            text: qsTr("打开应用"),
            icon: "open_in_new"
        });
        out.push({
            kind: "action",
            key: "pin",
            action: root.pinned ? "unpin" : "pin",
            text: root.pinned ? qsTr("从 Dock 移除") : qsTr("固定到 Dock"),
            icon: root.pinned ? "keep_off" : "keep"
        });

        if (wins.length > 1) {
            out.push({
                kind: "action",
                key: "closeAll",
                action: "closeAll",
                text: qsTr("关闭全部窗口 (%1)").arg(wins.length),
                icon: "close"
            });
        }

        return out;
    }

    function activateRow(row: var): void {
        if (!row)
            return;

        if (row.kind === "window") {
            if (row.window)
                Niri.focusWindow(row.window.id);
            root.dismissed();
            return;
        }

        switch (row.action) {
        case "launch":
            root.launch();
            break;
        case "pin":
            root.pin();
            break;
        case "unpin":
            root.unpin();
            break;
        case "closeAll":
            root.closeAll();
            break;
        default:
            break;
        }

        root.dismissed();
    }

    function launch(): void {
        if (root.entry) {
            try {
                Apps.launch(root.entry);
                return;
            } catch (e) {
                // fall through to the raw exec line
            }
            if (root.entry.command && root.entry.command.length > 0) {
                Quickshell.execDetached({
                    command: [...root.entry.command],
                    workingDirectory: root.entry.workingDirectory || ""
                });
                return;
            }
        }

        const exec = String(root.app?.exec ?? "");
        if (exec)
            Quickshell.execDetached([exec]);
    }

    function pin(): void {
        const list = (Config.dock.pinnedApps ?? []).slice();
        for (let i = 0; i < list.length; i++) {
            if (DockEntries.sameApp(list[i], root.app, DesktopEntries))
                return;
        }

        list.push({
            id: String(root.app?.id ?? ""),
            exec: String(root.app?.exec ?? ""),
            icon: String(root.app?.icon ?? ""),
            match: (root.app?.match ?? []).slice(),
            enabled: true
        });

        Config.dock.pinnedApps = list;
        Config.markDirty("dock");
    }

    function unpin(): void {
        const list = Config.dock.pinnedApps ?? [];
        const kept = [];
        for (let i = 0; i < list.length; i++) {
            if (!DockEntries.sameApp(list[i], root.app, DesktopEntries))
                kept.push(list[i]);
        }

        Config.dock.pinnedApps = kept;
        Config.markDirty("dock");
    }

    function closeAll(): void {
        const wins = root.windows ?? [];
        for (let i = 0; i < wins.length; i++) {
            if (wins[i]?.id !== undefined)
                Niri.closeWindow(wins[i].id);
        }
    }

    implicitWidth: root.bodyWidth
    implicitHeight: column.implicitHeight + Appearance.padding.sm * 2

    radius: Appearance.rounding.normal
    color: Colours.transparency.enabled ? Colours.layer(Colours.palette.m3surfaceContainer, 3) : Qt.alpha(Colours.tPalette.m3surfaceContainer, 0.94)
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

    HoverHandler {
        id: hoverHandler
        grabPermissions: PointerHandler.TakeOverForbidden
    }

    onVisibleChanged: {
        if (root.visible)
            enterAnim.restart();
    }

    SequentialAnimation {
        id: enterAnim

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: 110
            easing.type: Easing.OutCubic
        }
    }

    Column {
        id: column

        anchors.centerIn: parent
        width: root.bodyWidth - Appearance.padding.sm * 2
        spacing: 0

        Repeater {
            model: root.rows

            MenuRow {}
        }
    }

    component MenuRow: StyledRect {
        id: rowItem

        required property var modelData

        readonly property bool isSeparator: rowItem.modelData?.kind === "separator"
        readonly property bool interactive: !rowItem.isSeparator && rowItem.modelData?.kind !== "text"
        readonly property bool closeHovered: closeGlyph.hovered
        readonly property bool isWindowRow: rowItem.modelData?.kind === "window"

        width: column.width
        height: rowItem.isSeparator ? 9 : 32
        radius: Appearance.rounding.small / 2
        color: rowItem.interactive && (rowHover.hovered || rowItem.closeHovered) ? Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.14) : "transparent"

        HoverHandler {
            id: rowHover
            enabled: rowItem.interactive
            grabPermissions: PointerHandler.TakeOverForbidden
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Appearance.padding.sm
            anchors.rightMargin: Appearance.padding.sm
            visible: rowItem.isSeparator
            height: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)
        }

        MaterialIcon {
            id: rowIcon

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.sm
            anchors.verticalCenter: parent.verticalCenter
            visible: !rowItem.isSeparator && text.length > 0
            text: String(rowItem.modelData?.icon ?? "")
            font.pointSize: Appearance.font.size.bodyMedium
            color: rowItem.isWindowRow ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            anchors.left: rowIcon.visible ? rowIcon.right : parent.left
            anchors.leftMargin: rowIcon.visible ? Appearance.spacing.sm : Appearance.padding.sm
            anchors.right: parent.right
            anchors.rightMargin: rowItem.isWindowRow ? 28 : Appearance.padding.sm
            anchors.verticalCenter: parent.verticalCenter
            visible: !rowItem.isSeparator
            text: String(rowItem.modelData?.text ?? "")
            elide: Text.ElideRight
            font.pointSize: Appearance.font.size.bodySmall
            color: rowItem.modelData?.kind === "text" ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
        }

        StateLayer {
            anchors.fill: parent
            radius: parent.radius
            disabled: !rowItem.interactive
            onClicked: root.activateRow(rowItem.modelData)
        }

        // Per-window close, on top of the row's own click surface.
        StyledRect {
            id: closeGlyph

            readonly property bool hovered: closeHover.hovered

            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: width / 2
            visible: rowItem.isWindowRow && (rowHover.hovered || closeHover.hovered)
            color: closeHover.hovered ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : "transparent"
            z: 2

            HoverHandler {
                id: closeHover
                grabPermissions: PointerHandler.TakeOverForbidden
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "close"
                font.pointSize: Appearance.font.size.labelLarge
                color: Colours.palette.m3onSurfaceVariant
            }

            StateLayer {
                radius: parent.radius
                onClicked: {
                    if (rowItem.modelData?.window)
                        Niri.closeWindow(rowItem.modelData.window.id);
                }
            }
        }
    }
}
