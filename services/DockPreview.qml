pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Window thumbnails for the dock's hover preview.
//
// niri has no live window-capture protocol, so pixels come from
// `niri msg action screenshot-window` through scripts/dock/window_thumbs.sh,
// cached per window id. Consumers read `thumb(id)` and re-evaluate their
// binding whenever `revision` changes.
Singleton {
    id: root

    readonly property string cacheDir: `${Paths.cache}/dock-thumbs`
    readonly property bool available: Niri.niriAvailable

    // Bumped whenever new captures landed; bind to this before calling thumb().
    readonly property int revision: root._revision

    // How long a capture is considered fresh before a refresh re-runs it.
    readonly property int ttl: 2500

    readonly property string script: `${Quickshell.shellDir}/scripts/dock/window_thumbs.sh`

    property int _revision: 0
    property var _stamps: ({})
    property var _queued: []
    property bool _busy: false

    function thumb(id: var): string {
        const key = String(id ?? "");
        if (!key || !root._stamps[key])
            return "";
        return `file://${root.cacheDir}/${key}.png?${root._stamps[key]}`;
    }

    function captured(id: var): bool {
        return !!root._stamps[String(id ?? "")];
    }

    // Queue captures for the given window ids. `force` re-captures even when a
    // fresh thumbnail is already cached.
    function request(ids: var, force: bool): void {
        if (!root.available || !ids)
            return;

        const now = Date.now();
        const batch = [];
        for (let i = 0; i < ids.length; i++) {
            const key = String(ids[i] ?? "");
            if (!key || key === "undefined" || root._queued.indexOf(key) !== -1)
                continue;
            if (!force && root._stamps[key] && now - root._stamps[key] < root.ttl)
                continue;
            batch.push(key);
        }

        if (batch.length === 0)
            return;

        root._queued = root._queued.concat(batch);
        root.pump();
    }

    // niri announces every screenshot it takes on the desktop bus
    // ("Screenshot captured"), and its screenshot action is the only way to
    // get window pixels here. Those announcements are our own captures, so
    // Notifs swallows them while a batch is running and shortly after.
    readonly property bool suppressScreenshotNotifications: root._busy || quiet.running

    Timer {
        id: quiet

        interval: 4000
    }

    function pump(): void {
        if (root._busy || !root.available || root._queued.length === 0)
            return;

        // One script run per batch: the clipboard save/restore it performs
        // would otherwise be repeated for every single capture.
        const batch = root._queued.slice(0, 8);
        root._queued = root._queued.slice(batch.length);

        root._busy = true;
        quiet.restart();
        capture.command = ["bash", root.script, root.cacheDir].concat(batch);
        capture.running = true;
    }

    Process {
        id: capture

        running: false

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                const now = Date.now();
                let changed = false;
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const key = lines[i].trim();
                    if (!key)
                        continue;
                    root._stamps[key] = now;
                    changed = true;
                }
                if (changed)
                    root._revision++;
            }
        }

        onExited: {
            root._busy = false;
            // Deliveries can land after the process is gone; keep the guard up.
            quiet.restart();
            Qt.callLater(root.pump);
        }
    }
}
