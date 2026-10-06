pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.modules.launcher.services
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick
import "DockEntries.js" as DockEntries

Item {
    id: root

    readonly property int iconSize: Config.dock.sizes.iconSize ?? 48
    readonly property int iconGap: Config.dock.sizes.iconGap ?? 14
    readonly property int hPad: Config.dock.sizes.hPad ?? 16
    readonly property int vPad: Config.dock.sizes.vPad ?? 10
    readonly property int indicatorGap: Config.dock.sizes.indicatorGap ?? 6
    readonly property bool showSeparator: Config.dock.showSeparator ?? true
    readonly property bool showDynamicApps: Config.dock.showDynamicApps ?? true
    readonly property bool showThumbnails: Config.dock.showThumbnails ?? true
    readonly property bool showContextMenu: Config.dock.contextMenu ?? true
    readonly property int previewDelay: Config.dock.previewDelay ?? 320
    // Pill height, shared with the desktop lyrics band (Config.dock.sizes.barHeight).
    readonly property int baseHeight: Config.dock.sizes.barHeight

    // Space kept above the pill for the hover preview / context menu. Reserved
    // up front so opening a popup never resizes the layer surface — a resize
    // resets pointer state and would close the popup immediately.
    readonly property int popupHeadroom: 360

    // Hover in stable root coordinates (must NOT depend on scaled layout)
    property real mouseRootX: hoverHandler.hovered ? hoverHandler.point.position.x : -1
    property bool dockHovered: hoverHandler.hovered
    property int hoveredIndex: -1

    // Pointer inside the visible pill itself (the popup has its own hit area).
    readonly property bool pillHovered: hoverHandler.hovered && hoverHandler.point.position.x >= pill.x
        && hoverHandler.point.position.x <= pill.x + pill.width && hoverHandler.point.position.y >= pill.y

    // Visible pill — used by the wrapper as the window input mask
    readonly property Item clickTarget: pill

    // The dock item is only as wide as the pill; popups may be wider, so they
    // are clamped against the layer surface instead. `root.width` is read so
    // the binding refreshes whenever the dock's own layout moves us.
    readonly property real sceneLeft: root.width >= 0 ? root.mapToItem(null, 0, 0).x : 0
    readonly property real surfaceWidth: root.parent ? root.parent.width : root.width

    function popupX(popupWidth: real, anchorX: real): real {
        const minX = 8 - root.sceneLeft;
        const maxX = Math.max(minX, root.surfaceWidth - popupWidth - 8 - root.sceneLeft);
        return Math.max(minX, Math.min(maxX, anchorX - popupWidth / 2));
    }

    // ---- hover preview / context menu state ----
    property int popupIndex: -1
    property bool popupIsMenu: false
    readonly property bool popupOpen: root.popupIndex >= 0
    readonly property var popupApp: root.popupOpen ? root.dockModel[root.popupIndex] : null
    readonly property var popupWindows: root.popupOpen ? root.windowsFor(root.popupIndex) : []
    readonly property bool popupHovered: (preview.visible && preview.hovered) || (menu.visible && menu.hovered)
    // Item the wrapper mask must include so the popup receives clicks.
    readonly property Item popupInputItem: root.popupOpen ? (root.popupIsMenu ? menu : preview) : null

    function windowsFor(index: int): var {
        const delegate = iconRepeater.itemAt(index);
        return delegate ? delegate.appWindows : [];
    }

    function openPreview(index: int): void {
        if (index < 0 || index >= root.dockModel.length || root.dockModel[index]?.separator)
            return;
        if (root.windowsFor(index).length === 0) {
            root.scheduleClose();
            return;
        }
        root.popupIsMenu = false;
        root.popupIndex = index;
    }

    function openMenu(index: int): void {
        if (!root.showContextMenu || index < 0 || index >= root.dockModel.length || root.dockModel[index]?.separator)
            return;
        previewTimer.stop();
        closeTimer.stop();
        root.popupIsMenu = true;
        root.popupIndex = index;
    }

    function closePopup(): void {
        root.popupIndex = -1;
        root.popupIsMenu = false;
        previewTimer.stop();
    }

    function scheduleClose(): void {
        if (!root.popupOpen)
            return;
        closeTimer.restart();
    }

    function launchIndex(index: int): void {
        const app = root.dockModel[index];
        if (!app)
            return;

        const entry = DockEntries.resolveEntry(app, DesktopEntries);
        if (entry) {
            try {
                Apps.launch(entry);
                return;
            } catch (e) {
                // fall through to the raw exec line
            }
            if (entry.command && entry.command.length > 0) {
                Quickshell.execDetached({
                    command: [...entry.command],
                    workingDirectory: entry.workingDirectory || ""
                });
                return;
            }
        }

        const exec = String(app.exec ?? "");
        if (exec)
            Quickshell.execDetached([exec]);
    }

    onMouseRootXChanged: {
        if (root.pillHovered)
            root.updateHoveredIndex();
    }
    onDockHoveredChanged: {
        if (dockHovered) {
            root.updateHoveredIndex();
        } else {
            hoveredIndex = -1;
        }
    }
    onPillHoveredChanged: {
        if (root.pillHovered) {
            closeTimer.stop();
            root.updateHoveredIndex();
        } else {
            root.scheduleClose();
        }
    }
    onHoveredIndexChanged: {
        // An open menu stays put until it is dismissed or another icon is
        // right-clicked.
        if (root.popupIsMenu)
            return;
        if (root.hoveredIndex < 0) {
            root.scheduleClose();
            return;
        }
        closeTimer.stop();
        if (root.popupOpen && root.popupIndex === root.hoveredIndex)
            return;
        previewTimer.restart();
    }
    onPopupHoveredChanged: {
        if (root.popupHovered)
            closeTimer.stop();
        else
            root.scheduleClose();
    }

    Timer {
        id: previewTimer

        interval: root.previewDelay
        onTriggered: {
            if (root.pillHovered && root.hoveredIndex >= 0 && !root.popupIsMenu)
                root.openPreview(root.hoveredIndex);
        }
    }

    Timer {
        id: closeTimer

        interval: 220
        onTriggered: {
            if (!root.pillHovered && !root.popupHovered)
                root.closePopup();
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
    // Extra headroom so the hover tooltip and the popup are not clipped
    implicitHeight: baseHeight + 44 + root.popupHeadroom

    function resolveName(app: var): string {
        if (app?.name)
            return String(app.name);
        const id = String(app?.id ?? "").replace(/\.desktop$/i, "");
        const entry = DockEntries.resolveEntry(app, DesktopEntries);
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
        return DockEntries.matchesAppId(app, appId, DesktopEntries);
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
            && !root.popupOpen
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
                id: iconRepeater

                model: root.dockModel

                delegate: Item {
                    id: delegateRoot

                    required property var modelData
                    required property int index

                    readonly property bool isSeparator: !!modelData?.separator
                    // Read by the preview / menu through Dock.windowsFor()
                    readonly property var appWindows: item.windows

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
                        id: item

                        visible: !delegateRoot.isSeparator
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom

                        app: modelData
                        iconSize: root.iconSize
                        indicatorGap: root.indicatorGap
                        highlighted: root.hoveredIndex === index

                        onRightClicked: root.openMenu(delegateRoot.index)
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

    // ---- hover preview ----
    DockPreviewPopup {
        id: preview

        readonly property real anchorX: root.popupIndex >= 0 ? root.baseCenterRootX(root.popupIndex) : root.width / 2

        visible: root.popupOpen && !root.popupIsMenu && (root.showThumbnails || root.popupWindows.length === 0)
        app: root.popupApp
        windows: root.popupWindows
        iconSize: root.iconSize
        x: root.popupX(width, anchorX)
        y: pill.y - height - 10
        z: 30

        onWindowActivated: win => {
            if (win)
                Niri.focusWindow(win.id);
            root.closePopup();
        }
        onWindowClosed: win => {
            if (win)
                Niri.closeWindow(win.id);
        }
        onCloseAllRequested: {
            const wins = root.popupWindows;
            for (let i = 0; i < wins.length; i++) {
                if (wins[i]?.id !== undefined)
                    Niri.closeWindow(wins[i].id);
            }
            root.closePopup();
        }
        onLaunchRequested: {
            root.launchIndex(root.popupIndex);
            root.closePopup();
        }
        onDismissed: root.closePopup()
    }

    // ---- right-click menu ----
    DockMenu {
        id: menu

        readonly property real anchorX: root.popupIndex >= 0 ? root.baseCenterRootX(root.popupIndex) : root.width / 2

        visible: root.popupOpen && root.popupIsMenu
        app: root.popupApp
        windows: root.popupWindows
        x: Math.max(8, Math.min(root.width - width - 8, anchorX - width / 2))
        y: pill.y - height - 10
        z: 30

        onDismissed: root.closePopup()
    }
}
