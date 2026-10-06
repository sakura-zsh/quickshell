pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import qs.utils
import qs.modules.launcher.services
import Quickshell
import Quickshell.Widgets
import QtQuick
import "DockEntries.js" as DockEntries

Item {
    id: root

    required property var app
    property int iconSize: 48
    property int indicatorGap: 6
    property bool highlighted: false

    signal rightClicked

    readonly property bool isRunning: root._runningCount > 0
    readonly property bool isFocused: {
        const fw = Niri.focusedWindow;
        return !!fw && root.matchesWindow(fw);
    }
    // Windows of this app, in niri's order. Drives the hover preview.
    readonly property var windows: root.matchedWindows()

    readonly property int _runningCount: {
        const wins = Niri.windows;
        if (!wins)
            return 0;
        let n = 0;
        for (let i = 0; i < wins.length; i++) {
            if (root.matchesWindow(wins[i]))
                n++;
        }
        return n;
    }

    // Fixed layout slot — parent Row positions us; visual grow is scale-only
    width: iconSize
    height: iconSize + indicatorGap

    function desktopId(): string {
        return DockEntries.desktopId(root.app);
    }

    function resolveEntry(): var {
        return DockEntries.resolveEntry(root.app, DesktopEntries);
    }

    function matchCandidates(): list<string> {
        return DockEntries.matchCandidates(root.app, DesktopEntries);
    }

    function matchesWindow(w: var): bool {
        return DockEntries.matchesWindow(root.app, w, DesktopEntries);
    }

    function matchedWindows(): list<var> {
        const wins = Niri.windows ?? [];
        const out = [];
        for (let i = 0; i < wins.length; i++) {
            if (root.matchesWindow(wins[i]))
                out.push(wins[i]);
        }
        return out;
    }

    function launchApp(): void {
        const entry = root.resolveEntry();
        if (entry) {
            try {
                Apps.launch(entry);
                return;
            } catch (e) {
                // fall through
            }
            if (entry.command && entry.command.length > 0) {
                Quickshell.execDetached({
                    command: [...entry.command],
                    workingDirectory: entry.workingDirectory || ""
                });
                return;
            }
        }

        const exec = String(root.app?.exec ?? "");
        if (exec)
            Quickshell.execDetached([exec]);
    }

    function activate(): void {
        const matched = root.matchedWindows();
        if (matched.length > 0) {
            const focusedId = String(Niri.focusedWindowId ?? "");
            let idx = -1;
            for (let i = 0; i < matched.length; i++) {
                if (String(matched[i].id) === focusedId) {
                    idx = i;
                    break;
                }
            }
            // If already focused and only one window, still re-focus (bring to attention)
            const next = matched[(idx + 1) % matched.length];
            Niri.focusWindow(next.id);
            return;
        }

        root.launchApp();
    }

    Item {
        id: iconWrap

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.indicatorGap

        width: root.iconSize
        height: root.iconSize

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.92
            height: parent.height * 0.92
            radius: width * 0.28
            color: Qt.alpha(Colours.palette.m3primary, root.isFocused ? 0.16 : (root.highlighted ? 0.10 : 0))
            z: -1
        }

        IconImage {
            id: iconImg

            anchors.centerIn: parent
            // FIXED size forever — critical for performance
            implicitSize: root.iconSize
            asynchronous: true
            source: {
                const entry = root.resolveEntry();
                // The explicitly configured icon wins. Otherwise a pinned entry
                // whose id no longer matches an installed .desktop file (stale id,
                // e.g. renamed package) would push the lookup onto that dead id
                // and end up on the "image-missing" placeholder.
                return Icons.getAppIcon(root.app?.icon || entry?.icon || root.desktopId() || "", "image-missing");
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: Appearance.rounding.small
            color: "transparent"
            border.width: root.isFocused ? 1.5 : 0
            border.color: Qt.alpha(Colours.palette.m3primary, 0.55)
            opacity: root.isFocused ? 1 : 0
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 3
        opacity: root.isRunning ? 1 : 0
        z: 2

        Repeater {
            model: root.isRunning ? Math.min(root._runningCount, 3) : 0

            Rectangle {
                required property int index
                width: root.isFocused ? 5 : 4
                height: width
                radius: width / 2
                color: root.isFocused ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }
        }
    }

    MouseArea {
        id: mouse

        z: 100
        anchors.fill: parent
        anchors.topMargin: -10
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        preventStealing: true

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked();
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                root.launchApp();
                return;
            }
            root.activate();
        }
    }
}
