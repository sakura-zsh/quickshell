pragma Singleton

import qs.config
import Caelestia
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // --- Live player selection (prefer playing) ---
    readonly property MprisPlayer livePlayer: {
        const list = Players.list;
        if (!list || list.length === 0)
            return null;
        for (let i = 0; i < list.length; i++) {
            if (list[i]?.isPlaying)
                return list[i];
        }
        if (Players.active)
            return Players.active;
        for (let j = 0; j < list.length; j++) {
            if (String(list[j]?.trackTitle || "").trim())
                return list[j];
        }
        return list[0] ?? null;
    }

    // Sticky player/track — don't blank UI when MPRIS briefly clears metadata
    property MprisPlayer player: null
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string trackKey: ""
    property real length: 0

    readonly property bool hasPlayer: !!livePlayer || !!player
    readonly property bool isPlaying: livePlayer?.isPlaying ?? player?.isPlaying ?? false
    readonly property real position: {
        const p = livePlayer ?? player;
        if (!p)
            return 0;
        // Quickshell MprisPlayer exposes seconds (same as dashboard Media)
        const pos = Number(p.position) || 0;
        const len = Number(p.length) || 0;
        // Only convert if values look like raw MPRIS microseconds
        if (len > 10000 && pos >= 0)
            return pos / 1000000;
        return Math.max(0, pos);
    }

    property string status: "idle"
    property string statusMessage: ""
    property var lines: []
    property bool isSynced: false
    property string plainText: ""
    property int currentIndex: -1

    readonly property string currentLine: {
        if (isSynced && lines.length > 0) {
            let i = currentIndex;
            if (i < 0)
                i = 0;
            // Walk back if current slot is blank
            while (i >= 0) {
                const t = String(lines[i]?.text ?? "").trim();
                if (t)
                    return t;
                i--;
            }
            // Walk forward
            for (let j = Math.max(currentIndex, 0); j < lines.length; j++) {
                const t2 = String(lines[j]?.text ?? "").trim();
                if (t2)
                    return t2;
            }
            return "";
        }
        if (plainText)
            return plainText.split("\n").filter(l => l.trim().length > 0).slice(0, 2).join("  ·  ");
        return "";
    }

    readonly property string previousLine: (!isSynced || currentIndex <= 0) ? "" : (lines[currentIndex - 1]?.text ?? "")
    readonly property string nextLine: (!isSynced || currentIndex < 0 || currentIndex + 1 >= lines.length) ? "" : (lines[currentIndex + 1]?.text ?? "")

    readonly property string displayPrimary: {
        if (!trackTitle && !hasPlayer)
            return "";
        if (!trackTitle)
            return qsTr("等待曲目信息…");
        if (status === "loading")
            return qsTr("加载歌词…");
        if (status === "error")
            return statusMessage || qsTr("歌词获取失败");
        if (status === "empty")
            return qsTr("暂无歌词");
        if (currentLine)
            return currentLine;
        if (isSynced && lines.length > 0)
            return lines[0].text;
        return trackTitle;
    }

    readonly property string displaySecondary: {
        if (trackArtist && trackTitle)
            return `${trackArtist} — ${trackTitle}`;
        return trackArtist || trackTitle || "";
    }

    // Stay visible while we have sticky track info (survives MPRIS blips)
    readonly property bool visible: {
        if (Config.services.desktopLyrics === false)
            return false;
        return trackTitle.length > 0;
    }

    property var _cache: ({})
    property string _fetchKey: ""
    property int _fetchGen: 0
    property string _pendingKey: ""

    Component.onCompleted: {
        console.log("Lyrics: ready desktopLyrics=", Config.services.desktopLyrics);
        root.syncFromLive();
    }

    // Poll player metadata — Cider/chromium often emits incomplete intermediate states
    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: root.syncFromLive()
    }

    Timer {
        interval: 250
        running: root.visible && root.isPlaying && root.isSynced
        repeat: true
        onTriggered: {
            const p = root.livePlayer ?? root.player;
            if (p)
                p.positionChanged();
            root.updateCurrentIndex();
        }
    }

    // Debounce fetch so intermediate empty titles don't cancel lyrics
    Timer {
        id: fetchDebounce
        interval: 350
        onTriggered: root.fetchForCurrentTrack()
    }

    Connections {
        target: root.livePlayer
        enabled: !!root.livePlayer
        ignoreUnknownSignals: true
        function onTrackChanged(): void { root.syncFromLive(); }
        function onTrackTitleChanged(): void { root.syncFromLive(); }
        function onTrackArtistChanged(): void { root.syncFromLive(); }
        function onPositionChanged(): void { root.updateCurrentIndex(); }
    }

    onLivePlayerChanged: root.syncFromLive()

    function syncFromLive(): void {
        const p = root.livePlayer;
        if (!p)
            return;

        const title = String(p.trackTitle || "").trim();
        const artist = String(p.trackArtist || "").trim();
        const album = String(p.trackAlbum || "").trim();
        let len = p.length || 0;
        if (len > 100000)
            len = len / 1000000;
        if (len < 0)
            len = 0;

        // Ignore incomplete blips (artist without title or fully empty)
        if (!title)
            return;

        root.player = p;
        root.trackTitle = title;
        root.trackArtist = artist;
        root.trackAlbum = album;
        root.length = len;

        const key = artist + "\n" + title;
        if (key !== root.trackKey) {
            root.trackKey = key;
            root._pendingKey = key;
            fetchDebounce.restart();
        }
    }

    function updateCurrentIndex(): void {
        if (!isSynced || lines.length === 0) {
            if (currentIndex !== -1)
                currentIndex = -1;
            return;
        }
        const t = position + 0.08;
        let idx = -1;
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].time <= t)
                idx = i;
            else
                break;
        }
        if (idx !== currentIndex)
            currentIndex = idx;
    }

    function fetchForCurrentTrack(): void {
        if (Config.services.desktopLyrics === false)
            return;

        const title = root.trackTitle;
        const artist = root.trackArtist;
        const key = root.trackKey;
        if (!title || !key)
            return;

        const cached = _cache[key];
        if (cached) {
            applyResult(cached);
            return;
        }

        if (_fetchKey === key && status === "loading")
            return;

        status = "loading";
        statusMessage = "";
        // Keep previous lines until new ones arrive (no flicker to empty)
        _fetchKey = key;
        const gen = ++_fetchGen;

        console.log("Lyrics: fetch", JSON.stringify(artist), JSON.stringify(title), "len=", root.length);

        const duration = (root.length > 1 && root.length < 100000) ? Math.round(root.length) : 0;

        const finishSearch = () => root.searchLyrics(title, artist, key, gen);

        if (duration > 0) {
            const getUrl = "https://lrclib.net/api/get?"
                + "artist_name=" + encodeURIComponent(artist || " ")
                + "&track_name=" + encodeURIComponent(title)
                + (root.trackAlbum ? "&album_name=" + encodeURIComponent(root.trackAlbum) : "")
                + "&duration=" + duration;

            Requests.get(getUrl, text => {
                if (gen !== root._fetchGen || key !== root._fetchKey)
                    return;
                try {
                    const data = JSON.parse(text);
                    if (data && (data.syncedLyrics || data.plainLyrics)) {
                        const result = root.normalizeResult(data);
                        root._cache[key] = result;
                        root.applyResult(result);
                        console.log("Lyrics: get ok synced=", result.isSynced, "n=", (result.lines || []).length);
                        return;
                    }
                } catch (e) {}
                finishSearch();
            }, err => {
                if (gen !== root._fetchGen || key !== root._fetchKey)
                    return;
                console.warn("Lyrics: get failed", err);
                finishSearch();
            });
        } else {
            finishSearch();
        }
    }

    function searchLyrics(title: string, artist: string, key: string, gen: int): void {
        const q = (artist ? artist + " " : "") + title;
        const url = "https://lrclib.net/api/search?q=" + encodeURIComponent(q);
        console.log("Lyrics: search", JSON.stringify(q));

        Requests.get(url, text => {
            if (gen !== root._fetchGen || key !== root._fetchKey)
                return;
            try {
                const list = JSON.parse(text);
                if (!Array.isArray(list) || list.length === 0) {
                    root.status = "empty";
                    root.statusMessage = qsTr("暂无歌词");
                    root._cache[key] = { isSynced: false, lines: [], plainText: "", empty: true };
                    console.log("Lyrics: search empty");
                    return;
                }

                const targetDur = Math.round(root.length || 0);
                let best = null;
                let bestScore = -1e9;
                for (let i = 0; i < list.length; i++) {
                    const item = list[i];
                    if (!item)
                        continue;
                    let score = 0;
                    if (item.syncedLyrics)
                        score += 100;
                    else if (item.plainLyrics)
                        score += 40;
                    else
                        continue;
                    if (item.instrumental)
                        score -= 50;
                    if (targetDur > 0 && item.duration)
                        score -= Math.min(40, Math.abs(item.duration - targetDur));
                    const a = String(item.artistName || "").toLowerCase();
                    const ta = artist.toLowerCase();
                    if (ta && a && (a.includes(ta) || ta.includes(a)))
                        score += 20;
                    const tn = String(item.trackName || "").toLowerCase();
                    const tt = title.toLowerCase();
                    if (tt && tn && (tn.includes(tt) || tt.includes(tn)))
                        score += 25;
                    if (score > bestScore) {
                        bestScore = score;
                        best = item;
                    }
                }

                if (!best) {
                    root.status = "empty";
                    root.statusMessage = qsTr("暂无歌词");
                    return;
                }

                if (best.syncedLyrics || best.plainLyrics) {
                    const result = root.normalizeResult(best);
                    root._cache[key] = result;
                    root.applyResult(result);
                    console.log("Lyrics: search hit synced=", result.isSynced, "n=", (result.lines || []).length);
                    return;
                }

                if (best.id !== undefined) {
                    Requests.get("https://lrclib.net/api/get/" + best.id, text2 => {
                        if (gen !== root._fetchGen || key !== root._fetchKey)
                            return;
                        try {
                            const data = JSON.parse(text2);
                            const result = root.normalizeResult(data);
                            root._cache[key] = result;
                            root.applyResult(result);
                            console.log("Lyrics: get-by-id ok synced=", result.isSynced);
                        } catch (e2) {
                            root.status = "error";
                            root.statusMessage = qsTr("歌词解析失败");
                        }
                    }, err2 => {
                        if (gen !== root._fetchGen || key !== root._fetchKey)
                            return;
                        root.status = "error";
                        root.statusMessage = qsTr("歌词获取失败");
                    });
                    return;
                }

                root.status = "empty";
            } catch (e) {
                root.status = "error";
                root.statusMessage = qsTr("歌词解析失败");
                console.warn("Lyrics: search parse error", e);
            }
        }, err => {
            if (gen !== root._fetchGen || key !== root._fetchKey)
                return;
            root.status = "error";
            root.statusMessage = qsTr("网络错误");
            console.warn("Lyrics: search network error", err);
        });
    }

    function normalizeResult(data: var): var {
        if (data?.instrumental)
            return { isSynced: false, lines: [], plainText: qsTr("纯音乐"), empty: false };

        const synced = String(data?.syncedLyrics || "");
        if (synced.trim()) {
            const parsed = parseLrc(synced);
            if (parsed.length > 0)
                return { isSynced: true, lines: parsed, plainText: "", empty: false };
        }

        const plain = String(data?.plainLyrics || "").trim();
        return { isSynced: false, lines: [], plainText: plain, empty: !plain };
    }

    function applyResult(result: var): void {
        if (result?.empty) {
            status = "empty";
            lines = [];
            plainText = "";
            isSynced = false;
            currentIndex = -1;
            console.log("Lyrics: apply empty");
            return;
        }
        isSynced = !!result.isSynced;
        lines = result.lines || [];
        plainText = result.plainText || "";
        status = (isSynced && lines.length > 0) || plainText ? "ready" : "empty";
        console.log("Lyrics: apply status=", status, "synced=", isSynced, "lines=", lines.length, "visible=", visible, "titleLen=", trackTitle.length);
        updateCurrentIndex();
    }

    function parseLrc(text: string): var {
        const out = [];
        const rawLines = String(text).split(/\r?\n/);
        const re = /\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?\]/g;

        for (let i = 0; i < rawLines.length; i++) {
            const line = rawLines[i];
            if (!line)
                continue;
            const timestamps = [];
            let match;
            re.lastIndex = 0;
            while ((match = re.exec(line)) !== null) {
                const min = parseInt(match[1], 10);
                const sec = parseInt(match[2], 10);
                let frac = match[3] || "0";
                let fracSec = 0;
                if (frac.length === 1)
                    fracSec = parseInt(frac, 10) / 10;
                else if (frac.length === 2)
                    fracSec = parseInt(frac, 10) / 100;
                else
                    fracSec = parseInt(frac.substring(0, 3), 10) / 1000;
                timestamps.push(min * 60 + sec + fracSec);
            }
            if (timestamps.length === 0)
                continue;
            const lyricText = line.replace(/\[\d{1,2}:\d{2}(?:[\.:]\d{1,3})?\]/g, "").trim();
            if (!lyricText)
                continue;
            for (let t = 0; t < timestamps.length; t++)
                out.push({ time: timestamps[t], text: lyricText });
        }
        out.sort((a, b) => a.time - b.time);
        return out;
    }

    function togglePlaying(): void {
        const p = livePlayer ?? player;
        if (!p)
            return;

        // Cider/some players: togglePlaying only pauses and won't resume.
        // Prefer explicit pause()/play() based on state.
        if (p.isPlaying) {
            if (p.canPause)
                p.pause();
            else if (p.canTogglePlaying)
                p.togglePlaying();
            return;
        }

        if (p.canPlay)
            p.play();
        else if (p.canTogglePlaying)
            p.togglePlaying();
    }

    function next(): void {
        const p = livePlayer ?? player;
        if (p?.canGoNext)
            p.next();
    }

    function previous(): void {
        const p = livePlayer ?? player;
        if (p?.canGoPrevious)
            p.previous();
    }
}
