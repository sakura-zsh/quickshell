pragma Singleton

// import qs.components.misc
import qs.config
import qs.services
import Caelestia
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: manualActive ?? list.find(p => getIdentity(p) === Config.services.defaultPlayer) ?? list[0] ?? null
    property MprisPlayer manualActive

    function getIdentity(player: MprisPlayer): string {
        const alias = Config.services.playerAliases.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    // ---- dynamic-island media source ----
    // The bar's island owns a whitelist so a background browser tab cannot
    // masquerade as the current media source. The selection lives here, not in
    // the island, because the desktop lyrics band must follow the exact same
    // source — otherwise it would show lyrics for a player the island ignores.
    readonly property var islandWhitelistIds: {
        const out = [];
        const list = Config.bar.clock.islandWhitelist;
        if (list) {
            for (let i = 0; i < list.length; i++)
                out.push(String(list[i]));
        }
        return out;
    }
    readonly property bool islandWhitelistEnabled: Config.bar.clock.islandWhitelistEnabled ?? false
    // True when a whitelist is actually doing the selecting.
    readonly property bool islandWhitelistActive: islandWhitelistEnabled && islandWhitelistIds.length > 0

    // With the whitelist enabled the list *selects* the source, preferring a
    // whitelisted player that is really playing; with it disabled the island
    // falls back to the ordinary active player.
    readonly property MprisPlayer islandSource: {
        if (!islandWhitelistEnabled)
            return active;

        const ids = islandWhitelistIds;
        if (ids.length === 0)
            return null;

        const list = root.list;
        let fallback = null;
        for (let i = 0; i < list.length; i++) {
            const candidate = list[i];
            if (!ids.includes(getIdentity(candidate)))
                continue;
            if (candidate.isPlaying)
                return candidate;
            if (!fallback)
                fallback = candidate;
        }
        return fallback;
    }
    readonly property bool islandSourcePlaying: !!islandSource && !!islandSource.isPlaying

    // ---- blink-proof playback state ----
    // Cider (Electron) drops PlaybackStatus to Stopped for a moment while it
    // swaps tracks, so `islandSourcePlaying` dips on every song change. A
    // surface bound straight to it unmapped and remapped mid-switch: the
    // desktop lyrics band visibly blinked out and back between tracks.
    //
    // `islandSourceSteady` stays true for `islandIdleGrace` ms after playback
    // was last seen, which bridges a track change without keeping the band up
    // forever once playback really stops. It is derived from a timestamp rather
    // than latched, so a config reload during playback still reads "steady"
    // immediately (there is no change signal to initialise a latch from).
    property int islandIdleGrace: 3000
    property double islandLastPlayingAt: 0
    property double islandClockNow: Date.now()
    readonly property bool islandSourceSteady: islandSourcePlaying
        || (islandLastPlayingAt > 0 && islandClockNow - islandLastPlayingAt < islandIdleGrace)

    // Runs while the source plays (keeping the stamp fresh) and while a stopped
    // source is still inside its grace window, so the derived property above
    // re-evaluates and eventually drops.
    Timer {
        interval: 200
        repeat: true
        running: root.islandSourcePlaying || root.islandLastPlayingAt > 0

        onTriggered: {
            const now = Date.now();
            root.islandClockNow = now;
            if (root.islandSourcePlaying)
                root.islandLastPlayingAt = now;
            else if (now - root.islandLastPlayingAt >= root.islandIdleGrace)
                root.islandLastPlayingAt = 0;
        }
    }

    // "Is there media worth reacting to?" Consumers such as the dock audio
    // visualiser should ask this instead of reading Players.active directly:
    // an idle player registered under Config.services.defaultPlayer (e.g. a
    // Spotify sitting in the tray) would otherwise mask a playing Cider, so
    // the visualiser stayed permanently at zero.
    readonly property bool islandSourceHasTrack: String(root.islandSource?.trackTitle ?? "").trim().length > 0
    readonly property bool anyPlaying: {
        const list = root.list;
        for (let i = 0; i < list.length; i++) {
            if (list[i]?.isPlaying)
                return true;
        }
        return false;
    }
    readonly property bool hasAudibleMedia: root.islandSourceHasTrack || root.anyPlaying

    // ---- per-track playback clock ----
    // MPRIS players are not consistent about Position. A well-behaved player
    // resets it to 0 when the track changes, so `position / length` is the track
    // progress. Cider (Electron) instead reports Position as a running total for
    // the whole queue: it never resets between tracks, and `length - position` is
    // what actually remains of the current track. Read raw, that made every
    // readout accumulate down a playlist ("68:06 / 72:34" on a four minute song).
    //
    // The clock lives here, in a singleton alive for the whole session, and
    // deliberately NOT inside the widgets that display it: a widget created when
    // a drawer opens would otherwise start counting from zero every time it is
    // shown, which looks exactly like the bug this clock exists to fix.
    //
    // Per-track state per player, keyed by the player's unique D-Bus name.
    property var trackClocks: ({})

    // Consumers read these plain properties. They are real QML properties, not
    // helper functions over a JS map: a function reading a plain object does not
    // register a binding dependency, so the island would evaluate once while the
    // map was still empty and then sit at 0:00 forever.
    property real activeElapsed: 0
    property real activeDuration: 0
    property real islandElapsed: 0
    property real islandDuration: 0
    readonly property real activeProgress: root.activeDuration > 0 ? Math.max(0, Math.min(1, root.activeElapsed / root.activeDuration)) : 0
    readonly property real islandProgress: root.islandDuration > 0 ? Math.max(0, Math.min(1, root.islandElapsed / root.islandDuration)) : 0

    function _clockKey(p: MprisPlayer): string {
        return p ? String(p.dbusName ?? p.identity ?? "") : "";
    }

    function _clockTrackKey(p: MprisPlayer): string {
        return `${p.trackArtist ?? ""}\u0000${p.trackTitle ?? ""}`;
    }

    function _clockState(p: MprisPlayer): var {
        const key = root._clockKey(p);
        const trackKey = root._clockTrackKey(p);
        let state = root.trackClocks[key];

        if (!state || state.trackKey !== trackKey) {
            const pos = Number(p.position) || 0;
            state = {
                trackKey: trackKey,
                anchor: pos,
                probe: Math.max(0, (Number(p.length) || 0) - pos),
                elapsed: 0,
                lastTick: Date.now()
            };
            state.duration = state.probe;
            root.trackClocks[key] = state;
        }

        return state;
    }

    function _tickClocks(): void {
        const players = root.list;
        const seen = {};

        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (!p)
                continue;

            const key = root._clockKey(p);
            const state = root._clockState(p);
            seen[key] = true;

            const now = Date.now();
            const dt = Math.max(0, (now - state.lastTick) / 1000);
            state.lastTick = now;

            const pos = Number(p.position) || 0;
            const len = Number(p.length) || 0;
            const byPosition = pos - state.anchor;

            if (p.isPlaying)
                state.elapsed += dt;

            // The player's own position wins whenever it has moved ahead of our
            // clock: that is the normal advance as well as a forward seek. A
            // merely late push must not pull the clock back, so only a clear
            // jump backwards counts as a rewind.
            if (byPosition > state.elapsed)
                state.elapsed = byPosition;
            else if (byPosition < state.elapsed - 5)
                state.elapsed = Math.max(0, byPosition);

            // `length - position` is the remaining time of the current track for
            // a queue-level player, and the whole track for one that has just
            // started, so the largest value seen is the track's duration.
            const probe = Math.max(0, len - pos);
            if (probe > state.probe) {
                state.probe = probe;
                state.duration = probe;
            }
        }

        // Forget players that disappeared so the map cannot grow forever.
        const known = Object.keys(root.trackClocks);
        for (let i = 0; i < known.length; i++) {
            if (!seen[known[i]])
                delete root.trackClocks[known[i]];
        }

        // Publish the two surfaces' values as property assignments so every
        // binding that reads them is notified on this tick.
        const active = root.active;
        const activeState = active ? root.trackClocks[root._clockKey(active)] : null;
        root.activeElapsed = activeState ? activeState.elapsed : 0;
        root.activeDuration = activeState ? activeState.duration : 0;

        const island = root.islandSource;
        const islandState = island ? root.trackClocks[root._clockKey(island)] : null;
        root.islandElapsed = islandState ? islandState.elapsed : 0;
        root.islandDuration = islandState ? islandState.duration : 0;
    }

    Timer {
        interval: 250
        repeat: true
        running: root.list.length > 0

        onTriggered: root._tickClocks()
    }

    Connections {
        target: root.active

        function onTrackChanged(): void {
            if (!Config.utilities.toasts.nowPlaying)
                return;
            if (root.active)
                Toaster.toast(qsTr("正在播放"), qsTr("%1 - %2").arg(root.active.trackArtist).arg(root.active.trackTitle), "music_note");
        }
    }

    // Niri does not have global shortcuts yet ;).
    // CustomShortcut {
    //     name: "mediaToggle"
    //     description: "Toggle media playback"
    //     onPressed: {
    //         const active = root.active;
    //         if (active && active.canTogglePlaying)
    //             active.togglePlaying();
    //     }
    // }

    // CustomShortcut {
    //     name: "mediaPrev"
    //     description: "Previous track"
    //     onPressed: {
    //         const active = root.active;
    //         if (active && active.canGoPrevious)
    //             active.previous();
    //     }
    // }

    // CustomShortcut {
    //     name: "mediaNext"
    //     description: "Next track"
    //     onPressed: {
    //         const active = root.active;
    //         if (active && active.canGoNext)
    //             active.next();
    //     }
    // }

    // CustomShortcut {
    //     name: "mediaStop"
    //     description: "Stop media playback"
    //     onPressed: root.active?.stop()
    // }

    IpcHandler {
        target: "mpris"

        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? "Invalid property" : "No active player";
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void {
            const active = root.active;
            if (active?.canPlay)
                active.play();
        }

        function pause(): void {
            const active = root.active;
            if (active?.canPause)
                active.pause();
        }

        function playPause(): void {
            const active = root.active;
            if (active?.canTogglePlaying)
                active.togglePlaying();
        }

        function previous(): void {
            const active = root.active;
            if (active?.canGoPrevious)
                active.previous();
        }

        function next(): void {
            const active = root.active;
            if (active?.canGoNext)
                active.next();
        }

        function stop(): void {
            root.active?.stop();
        }
    }
}
