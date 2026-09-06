pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

Item {
    id: root

    readonly property int iconSize: Config.dock.sizes.iconSize ?? 48
    readonly property int iconGap: Config.dock.sizes.iconGap ?? 14
    readonly property int hPad: Config.dock.sizes.hPad ?? 16
    readonly property int vPad: Config.dock.sizes.vPad ?? 10
    readonly property int indicatorGap: Config.dock.sizes.indicatorGap ?? 6
    readonly property bool showSeparator: Config.dock.showSeparator ?? true
    readonly property bool showDynamicApps: Config.dock.showDynamicApps ?? true
    readonly property int baseHeight: iconSize + vPad * 2 + indicatorGap

    // Hover in stable root coordinates (must NOT depend on scaled layout)
    property real mouseRootX: hoverHandler.hovered ? hoverHandler.point.position.x : -1
    property bool dockHovered: hoverHandler.hovered
    property int hoveredIndex: -1

    // Visible pill — used by the wrapper as the window input mask
    readonly property Item clickTarget: pill

    onMouseRootXChanged: root.updateHoveredIndex()
    onDockHoveredChanged: {
        if (dockHovered) {
            root.updateHoveredIndex();
        } else {
            hoveredIndex = -1;
        }
    }

    // Pinned launcher apps come from Config (toggleable in the settings panel).
    readonly property var pinnedApps: {
        const all = Config.dock.pinnedApps ?? [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            if (all[i].enabled !== false)
                out.push(all[i]);
        }
        return out;
    }

    // All pinned apps, including disabled ones. Disabled apps are intentionally
    // hidden from the dock entirely — including the "running apps" section.
    readonly property var allPinnedApps: Config.dock.pinnedApps ?? []

    readonly property var dynamicApps: {
        const wins = Niri.windows ?? [];
        const seen = ({});
        const out = [];

        for (let i = 0; i < wins.length; i++) {
            const appId = String(wins[i]?.app_id ?? "");
            if (!appId)
                continue;

            const key = appId.toLowerCase();
            if (seen[key])
                continue;
            seen[key] = true;

            let isPinned = false;
            for (let p = 0; p < root.allPinnedApps.length; p++) {
                if (root.appMatchesId(root.allPinnedApps[p], appId)) {
                    isPinned = true;
                    break;
                }
            }
            if (isPinned)
                continue;

            if (root.isIgnoredApp(appId))
                continue;

            const entry = DesktopEntries.byId(appId)
                || DesktopEntries.heuristicLookup(appId)
                || DesktopEntries.heuristicLookup(appId.split(".").pop());

            out.push({
                id: entry?.id || appId,
                exec: (entry?.command && entry.command.length > 0) ? entry.command[0] : appId,
                icon: entry?.icon || appId,
                name: entry?.name || appId,
                match: [appId, entry?.id, entry?.startupClass].filter(v => !!v),
                dynamic: true
            });
        }

        return out;
    }

    readonly property var dockModel: {
        const items = [];
        for (let i = 0; i < root.pinnedApps.length; i++) {
            const a = root.pinnedApps[i];
            items.push({
                id: a.id,
                exec: a.exec,
                icon: a.icon,
                match: a.match,
                dynamic: false,
                separator: false,
                name: root.resolveName(a)
            });
        }
        if (root.showDynamicApps && root.dynamicApps.length > 0) {
            if (root.showSeparator) {
                items.push({
                    separator: true,
                    dynamic: false,
                    id: "__separator__"
                });
            }
            for (let j = 0; j < root.dynamicApps.length; j++)
                items.push(root.dynamicApps[j]);
        }
        return items;
    }

    // Fixed unscaled content width — pill size never depends on magnification
    readonly property real baseContentWidth: {
        let w = 0;
        const model = root.dockModel;
        for (let i = 0; i < model.length; i++) {
            if (i > 0)
                w += root.iconGap;
            w += model[i]?.separator ? 10 : root.iconSize;
        }
        return w;
    }

    implicitWidth: pill.implicitWidth
    // Extra headroom so the hover tooltip is not clipped
    implicitHeight: baseHeight + 44

    function resolveName(app: var): string {
        if (app?.name)
            return String(app.name);
        const id = String(app?.id ?? "").replace(/\.desktop$/i, "");
        const entry = DesktopEntries.byId(id)
            || DesktopEntries.heuristicLookup(id)
            || DesktopEntries.heuristicLookup(String(app?.exec ?? ""));
        return entry?.name || id || String(app?.exec ?? "App");
    }

    function isIgnoredApp(appId: string): bool {
        const id = appId.toLowerCase();
        const ignored = [
            "quickshell",
            "caelestia",
            "unknown",
            "xdg-desktop-portal",
            "polkit",
            "org.freedesktop.impl.portal"
        ];
        for (let i = 0; i < ignored.length; i++) {
            if (id.includes(ignored[i]))
                return true;
        }
        return false;
    }

    function appMatchesId(app: var, appId: string): bool {
        const target = String(appId ?? "").toLowerCase();
        if (!target)
            return false;

        const candidates = [];
        function add(v) {
            const s = String(v ?? "").trim().toLowerCase();
            if (s && candidates.indexOf(s) === -1)
                candidates.push(s);
        }

        add(app?.id);
        add(String(app?.id ?? "").replace(/\.desktop$/i, ""));
        add(app?.exec);
        add(app?.icon);
        const extras = app?.match ?? [];
        for (let i = 0; i < extras.length; i++)
            add(extras[i]);

        const entry = DesktopEntries.byId(String(app?.id ?? "").replace(/\.desktop$/i, ""))
            || DesktopEntries.heuristicLookup(String(app?.id ?? "").replace(/\.desktop$/i, ""));
        if (entry) {
            add(entry.id);
            add(entry.startupClass);
            add(entry.icon);
        }

        for (let i = 0; i < candidates.length; i++) {
            if (target === candidates[i])
                return true;
        }
        return false;
    }

    // Icon centers in ROOT coordinates, using FIXED unscaled layout
    function baseCenterRootX(index: int): real {
        const pillLeft = (root.width - (root.baseContentWidth + root.hPad * 2)) / 2;
        let x = pillLeft + root.hPad;
        for (let i = 0; i < index; i++) {
            const item = root.dockModel[i];
            x += (item?.separator ? 10 : root.iconSize) + root.iconGap;
        }
        const cur = root.dockModel[index];
        if (cur?.separator)
            return x + 5;
        return x + root.iconSize / 2;
    }

    function updateHoveredIndex(): void {
        if (!root.dockHovered || root.mouseRootX < 0) {
            root.hoveredIndex = -1;
            return;
        }
        let best = -1;
        let bestDist = Infinity;
        for (let i = 0; i < root.dockModel.length; i++) {
            if (root.dockModel[i]?.separator)
                continue;
            const d = Math.abs(root.mouseRootX - root.baseCenterRootX(i));
            if (d < bestDist) {
                bestDist = d;
                best = i;
            }
        }
        root.hoveredIndex = bestDist < root.iconSize * 0.85 ? best : -1;
    }

    // Full-dock hover tracking in root space.
    // TakeOverForbidden: do not steal presses from child MouseAreas (clicks).
    HoverHandler {
        id: hoverHandler
        grabPermissions: PointerHandler.TakeOverForbidden
    }

    // Tooltip
    StyledRect {
        id: tooltipBox

        readonly property bool show: (Config.dock.showTooltip ?? true)
            && root.dockHovered
            && root.hoveredIndex >= 0
            && !(root.dockModel[root.hoveredIndex]?.separator)

        x: {
            if (!show || root.hoveredIndex < 0)
                return (root.width - width) / 2;
            return root.baseCenterRootX(root.hoveredIndex) - width / 2;
        }
        anchors.bottom: pill.top
        anchors.bottomMargin: 10

        implicitWidth: tooltipText.implicitWidth + Appearance.padding.md * 2
        implicitHeight: tooltipText.implicitHeight + Appearance.padding.sm * 2
        radius: Appearance.rounding.small
        color: Colours.palette.m3surfaceContainerHighest
        opacity: show ? 1 : 0
        visible: opacity > 0.01
        z: 10

        Behavior on opacity {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        Elevation {
            anchors.fill: parent
            radius: parent.radius
            level: 2
            z: -1
        }

        StyledText {
            id: tooltipText

            anchors.centerIn: parent
            text: {
                if (root.hoveredIndex < 0)
                    return "";
                const item = root.dockModel[root.hoveredIndex];
                if (!item || item.separator)
                    return "";
                return item.name || root.resolveName(item);
            }
            color: Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.labelLarge
        }
    }

    // Frosted glass pill — WIDTH IS FIXED (unscaled), no center-resize feedback
    StyledRect {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        implicitWidth: root.baseContentWidth + root.hPad * 2
        implicitHeight: root.baseHeight

        radius: Appearance.rounding.large
        color: {
            const base = Colours.tPalette.m3surfaceContainer;
            if (Colours.transparency.enabled)
                return Colours.layer(Colours.palette.m3surfaceContainer, 0);
            return Qt.alpha(base, 0.72);
        }
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
        clip: false

        Behavior on color {
            CAnim {}
        }
        Behavior on border.color {
            CAnim {}
        }

        // Glass edge highlight
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: parent.height * 0.45
            radius: parent.radius
            z: 0
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        Row {
            id: row

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.vPad
            spacing: root.iconGap
            z: 1

            Repeater {
                model: root.dockModel

                delegate: Item {
                    id: delegateRoot

                    required property var modelData
                    required property int index

                    readonly property bool isSeparator: !!modelData?.separator

                    // FIXED layout cell — magnification is visual-only via scale
                    width: isSeparator ? 10 : root.iconSize
                    height: root.iconSize + root.indicatorGap

                    Rectangle {
                        visible: delegateRoot.isSeparator
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -root.indicatorGap / 2
                        width: 2
                        height: root.iconSize * 0.55
                        radius: 1
                        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.55)
                    }

                    DockItem {
                        visible: !delegateRoot.isSeparator
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom

                        app: modelData
                        iconSize: root.iconSize
                        indicatorGap: root.indicatorGap
                        highlighted: root.hoveredIndex === index
                    }
                }
            }
        }
    }

    Elevation {
        anchors.fill: pill
        radius: pill.radius
        level: 2
        z: -1
    }
}
