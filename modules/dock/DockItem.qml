pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import qs.utils
import qs.modules.launcher.services
import Quickshell
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    required property var app
    property int iconSize: 48
    property int indicatorGap: 6
    property bool highlighted: false

    readonly property bool isRunning: root._runningCount > 0
    readonly property bool isFocused: {
        const fw = Niri.focusedWindow;
        return !!fw && root.matchesWindow(fw);
    }

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
        return String(root.app?.id ?? "").replace(/\.desktop$/i, "");
    }

    function resolveEntry(): var {
        const id = root.desktopId();
        const exec = String(root.app?.exec ?? "");
        return DesktopEntries.byId(id)
            || DesktopEntries.heuristicLookup(id)
            || DesktopEntries.heuristicLookup(exec)
            || null;
    }

    function matchCandidates(): list<string> {
        const out = [];
        function add(v) {
            const s = String(v ?? "").trim().toLowerCase();
            if (!s)
                return;
            if (out.indexOf(s) === -1)
                out.push(s);
        }

        const id = root.desktopId();
        add(id);
        add(root.app?.exec);
        add(root.app?.icon);

        const extras = root.app?.match ?? [];
        for (let i = 0; i < extras.length; i++)
            add(extras[i]);

        const entry = root.resolveEntry();
        if (entry) {
            add(entry.id);
            add(entry.startupClass);
            add(entry.icon);
        }

        return out;
    }

    function matchesWindow(w: var): bool {
        const appId = String(w?.app_id ?? "").toLowerCase();
        if (!appId)
            return false;

        const candidates = root.matchCandidates();
        for (let i = 0; i < candidates.length; i++) {
            if (appId === candidates[i])
                return true;
        }

        for (let i = 0; i < candidates.length; i++) {
            const c = candidates[i];
            if (!c || c.length < 3)
                continue;
            if (appId.endsWith("." + c) || c.endsWith("." + appId))
                return true;
            if (c.length >= 4 && (appId.includes(c) || c.includes(appId)))
                return true;
        }

        return false;
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
                return Icons.getAppIcon(entry?.icon || root.desktopId() || root.app?.icon || "", "image-missing");
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
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.launchApp();
                return;
            }
            root.activate();
        }
    }
}
