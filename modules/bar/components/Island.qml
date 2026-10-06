pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.config
import QtQuick

// The bar's dynamic island.
//
// Resting: a single circular media-source control sits to the left of the time
// component, and the time component stays anchored to the bar's centre. The
// circle only appears while a whitelisted player is the active media source —
// with nothing playing only the time component is drawn.
//
// Expanded: the time component grows to the island width and the circle moves
// below it, growing into a media capsule of exactly the same width. The two are
// separate rounded shapes with a gap between them: a column of capsules, never
// one joined block.
//
// Every moving part animates off a single `reveal` value (0 = resting,
// 1 = expanded) so the capsules cannot drift apart mid-transition.
StyledRect {
    id: root

    // ---- configuration ----
    readonly property bool islandEnabled: Config.bar.clock.island ?? true
    readonly property real barHeight: Config.bar.sizes.innerWidth
    readonly property real pad: Appearance.padding.sm
    readonly property real expandedWidth: Config.bar.clock.islandWidth ?? 340
    readonly property real capsuleHeight: Math.max(112, Config.bar.clock.islandHeight ?? 112)
    readonly property bool artworkEnabled: Config.bar.clock.islandArtwork ?? true
    readonly property bool waveformEnabled: Config.bar.clock.islandWaveform ?? false
    readonly property bool progressEnabled: Config.bar.clock.islandProgress ?? true
    readonly property real circleSize: Math.max(32, Config.bar.clock.islandCircleSize ?? 44)
    readonly property real circleGap: Math.max(0, Config.bar.clock.islandCircleGap ?? 3)
    readonly property real capsuleGap: Math.max(0, Config.bar.clock.islandExpandedGap ?? 6)
    readonly property int spinDuration: Math.max(1000, Config.bar.clock.islandSpinDuration ?? 12000)
    readonly property int autoCollapseDelay: Math.max(0, Config.bar.clock.islandAutoCollapse ?? 1500)

    // ---- media ----
    // The whitelist-aware source selection is shared with the desktop lyrics
    // band (Players.islandSource), so the island and the lyrics never disagree
    // about which player is on screen.
    readonly property var player: Players.islandSource
    readonly property bool hasMedia: root.player !== null && root.player !== undefined
    readonly property bool playing: root.hasMedia && !!root.player.isPlaying
    readonly property string artUrl: root.hasMedia ? String(root.player.trackArtUrl ?? "") : ""
    readonly property string title: root.hasMedia ? String(root.player.trackTitle ?? "") : ""
    readonly property string artist: root.hasMedia ? String(root.player.trackArtist || root.player.identity || "") : ""
    // Per-track timing: raw MPRIS Position/Length accumulate across a playlist on
    // some players, which made the capsule count the whole queue. The clock lives
    // in Players, so it survives this window being recreated and updates live.
    readonly property real trackLength: root.hasMedia ? Players.islandDuration : 0
    readonly property real trackPosition: root.hasMedia ? Players.islandElapsed : 0
    readonly property real progress: root.hasMedia ? Players.islandProgress : 0

    // ---- state ----
    property bool expanded: false
    // Animated expansion progress: 0 resting, 1 expanded.
    property real reveal: root.expanded ? 1 : 0
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool canExpand: root.islandEnabled && root.hasMedia
    readonly property bool showMediaControls: root.islandEnabled && root.hasMedia

    // ---- geometry ----
    // The time component keeps its natural width at rest and grows to the island
    // width when expanded; both capsules in the column share that width.
    readonly property real discSize: root.circleSize
    readonly property real artworkSlot: root.islandEnabled && root.artworkEnabled ? root.circleSize : 0
    readonly property real waveformSlot: root.islandEnabled && root.waveformEnabled ? root.circleSize : 0
    readonly property real artworkWidth: root.showMediaControls ? root.artworkSlot : 0
    readonly property real waveformWidth: root.showMediaControls ? root.waveformSlot : 0
    readonly property real leftControlsWidth: root.artworkWidth + root.waveformWidth + ((root.artworkWidth > 0 && root.waveformWidth > 0) ? root.circleGap : 0)
    readonly property real controlGap: root.leftControlsWidth > 0 ? root.circleGap : 0
    readonly property real naturalPillWidth: clockFace.implicitWidth + root.pad * 2
    readonly property real expandedPillWidth: Math.max(root.naturalPillWidth, root.expandedWidth)
    readonly property real pillWidth: root.expanded ? root.expandedPillWidth : root.naturalPillWidth
    readonly property real pillX: root.expanded ? 0 : root.leftControlsWidth + root.controlGap
    // Distance from the island's left edge to the time component's centre. The
    // bar uses it to pin that centre to the screen centre, so neighbours can
    // never drag the island sideways. It reads the pill's *animated* geometry
    // (not the binding targets) so the centre stays put while the pill grows.
    readonly property real centreAnchorX: centrePill.x + centrePill.width / 2
    readonly property real restingWidth: root.leftControlsWidth + root.controlGap + root.naturalPillWidth
    // Height of the hairline drawn in the disc/time gap.
    readonly property real separatorHeight: Math.max(10, Math.round(root.barHeight * 0.42))

    function expand(): void {
        if (root.canExpand)
            root.expanded = true;
    }

    function collapse(): void {
        root.expanded = false;
    }

    function toggleExpanded(): void {
        if (root.expanded)
            root.collapse();
        else
            root.expand();
    }

    // Called by the bar for wheel events over the island.
    function handleWheel(deltaY: real): void {
        if (!root.canExpand)
            return;
        if (deltaY < 0)
            root.expand();
        else if (deltaY > 0)
            root.collapse();
    }

    function formatTime(seconds: real): string {
        if (!isFinite(seconds) || seconds <= 0)
            return "0:00";
        const total = Math.floor(seconds);
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return `${minutes}:${rest < 10 ? "0" : ""}${rest}`;
    }

    onHasMediaChanged: {
        if (!root.hasMedia && root.expanded)
            root.collapse();
    }

    width: root.expanded ? root.expandedPillWidth : root.restingWidth
    height: root.expanded ? root.barHeight + root.capsuleGap + root.capsuleHeight : root.barHeight
    implicitWidth: root.restingWidth
    implicitHeight: root.barHeight

    radius: Appearance.rounding.full
    color: "transparent"

    // ---- transitions ----
    // Growing uses a decelerating curve, shrinking an accelerating one, so the
    // island snaps open and settles back rather than moving linearly.
    Behavior on reveal {
        NumberAnimation {
            duration: root.expanded ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.normal
            easing.bezierCurve: root.expanded ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.emphasizedAccel
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: root.expanded ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.normal
            easing.bezierCurve: root.expanded ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.emphasizedAccel
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: root.expanded ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.normal
            easing.bezierCurve: root.expanded ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.emphasizedAccel
        }
    }

    clip: false

    HoverHandler {
        id: hoverHandler
        grabPermissions: PointerHandler.TakeOverForbidden
    }

    // Collapse once the pointer has been away for a moment.
    Timer {
        id: collapseTimer
        interval: root.autoCollapseDelay
        onTriggered: {
            if (!root.hovered)
                root.collapse();
        }
    }

    onHoveredChanged: {
        if (root.hovered)
            collapseTimer.stop();
        else if (root.expanded)
            collapseTimer.restart();
    }

    // ---- resting controls: the circular media source, left of the pill ----
    Item {
        id: leftControls

        anchors.left: parent.left
        anchors.top: parent.top
        width: root.leftControlsWidth
        height: root.barHeight
        // Dissolves into the capsule below as the island expands, and fades in
        // when a media source appears.
        opacity: root.showMediaControls ? 1 - root.reveal : 0
        visible: root.leftControlsWidth > 0 || opacity > 0.01
        enabled: root.showMediaControls && !root.expanded

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.normal
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        // The artwork disc: the media source itself.
        Item {
            id: artworkControl

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.artworkSlot
            height: root.circleSize

            // Shrinks a little as it hands over to the capsule's cover art.
            scale: 1 - 0.12 * root.reveal

            Item {
                id: disc

                anchors.fill: parent

                // The clipping boundary stays static; only the artwork rotates.
                StyledClippingRect {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(0.06, 0.06, 0.07, 1)
                    antialiasing: true
                }

                StyledClippingRect {
                    anchors.fill: parent
                    anchors.margins: Math.max(3, root.discSize * 0.09)
                    radius: width / 2
                    color: "transparent"
                    antialiasing: true

                    Item {
                        id: spinningArtwork

                        anchors.fill: parent

                        RotationAnimation on rotation {
                            running: root.playing
                            loops: Animation.Infinite
                            to: 360
                            duration: root.spinDuration
                            direction: RotationAnimation.Clockwise
                        }

                        Image {
                            anchors.fill: parent
                            visible: root.artUrl.length > 0
                            source: root.artUrl
                            sourceSize.width: 256
                            sourceSize.height: 256
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            smooth: true
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: root.artUrl.length === 0
                            text: "music_note"
                            color: Qt.rgba(0.72, 0.76, 0.86, 1)
                            font.pointSize: Math.round(root.discSize * 0.42)
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(2, root.discSize * 0.07)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(0.06, 0.06, 0.07, 1)
                }
            }

            StateLayer {
                anchors.fill: parent
                radius: width / 2
                onClicked: root.toggleExpanded()
            }
        }

        Item {
            id: waveformControl

            anchors.left: artworkControl.right
            anchors.leftMargin: artworkControl.width > 0 ? root.circleGap : 0
            anchors.verticalCenter: parent.verticalCenter
            width: root.waveformSlot
            height: root.circleSize

            // The slot collapses to zero width when the waveform is off, but a
            // zero-width parent still paints its children (no implicit clip), so
            // the five bars used to leak into the gap as stray vertical stripes.
            // Gate on the slot itself: with the waveform disabled nothing draws.
            visible: root.waveformSlot > 0

            scale: 1 - 0.12 * root.reveal

            StyledRect {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(0.02, 0.02, 0.025, 0.96)

                Row {
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: 5

                        Rectangle {
                            required property int index

                            width: 2
                            height: Math.max(6, root.circleSize * (0.25 + (root.playing ? 0.12 * ((index + 2) % 3) : 0.04)))
                            radius: width / 2
                            color: root.playing ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }

            StateLayer {
                anchors.fill: parent
                radius: width / 2
                onClicked: root.toggleExpanded()
            }
        }
    }

    // ---- resting separator ----
    // One deliberate hairline in the gap between the disc and the time pill. It
    // replaces the stray waveform bars that used to leak into this space, so the
    // pair reads as two elements with a subtle divider instead of a thick comb.
    Rectangle {
        x: Math.round(root.leftControlsWidth + (root.controlGap - 1) / 2)
        y: Math.round((root.barHeight - root.separatorHeight) / 2)
        width: 1
        height: root.separatorHeight
        radius: 0.5
        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.45)
        visible: root.showMediaControls && !root.expanded && root.controlGap > 0
    }

    // ---- time component ----
    Item {
        id: centrePill

        anchors.top: parent.top
        x: root.pillX
        width: root.pillWidth
        height: root.barHeight

        // The pill stretches in place: its own width and left edge ease between
        // "circle + gap + clock" and the full island width.
        Behavior on width {
            NumberAnimation {
                duration: root.expanded ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.normal
                easing.bezierCurve: root.expanded ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.emphasizedAccel
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: root.expanded ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.normal
                easing.bezierCurve: root.expanded ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.emphasizedAccel
            }
        }

        StyledRect {
            id: pillBg

            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(0.01, 0.01, 0.015, 0.96)
        }

        Elevation {
            anchors.fill: pillBg
            radius: pillBg.radius
            level: root.expanded ? 2 : 0
            visible: root.expanded
            z: -1
        }

        Clock {
            id: clockFace

            anchors.centerIn: parent
        }

        StateLayer {
            anchors.fill: parent
            radius: parent.height / 2
            disabled: !root.canExpand
            onClicked: root.toggleExpanded()
        }
    }

    // ---- expanded media capsule: a separate capsule below the time pill ----
    Item {
        id: capsule

        x: 0
        // Rises the last few pixels into place, so the capsule reads as growing
        // out of the pill above it instead of appearing fully formed.
        y: root.barHeight + root.capsuleGap - (1 - root.reveal) * 10
        width: root.expandedPillWidth
        height: root.capsuleHeight
        opacity: root.reveal
        scale: 0.95 + 0.05 * root.reveal
        transformOrigin: Item.Top
        visible: opacity > 0.01

        StyledRect {
            id: capsuleBg

            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Qt.rgba(0.01, 0.01, 0.015, 0.96)
        }

        Elevation {
            anchors.fill: capsuleBg
            radius: capsuleBg.radius
            level: 2
            z: -1
        }

        // Cover art, mirroring the resting circle it grew out of.
        StyledClippingRect {
            id: capsuleArt

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Appearance.padding.md
            anchors.topMargin: Appearance.padding.md

            implicitWidth: 44
            implicitHeight: 44
            radius: Appearance.rounding.small
            color: Colours.tPalette.m3surfaceContainerHigh

            MaterialIcon {
                anchors.centerIn: parent
                visible: root.artUrl.length === 0
                text: root.artUrl.length === 0 ? "art_track" : "music_note"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.bodyLarge
            }

            Image {
                anchors.fill: parent
                visible: root.artUrl.length > 0
                source: root.artUrl
                sourceSize.width: 128
                sourceSize.height: 128
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
        }

        StyledText {
            id: capsuleTitle

            anchors.left: capsuleArt.right
            anchors.right: parent.right
            anchors.leftMargin: Appearance.spacing.md
            anchors.rightMargin: Appearance.padding.md
            anchors.top: capsuleArt.top
            anchors.topMargin: 2

            text: root.title.length > 0 ? root.title : qsTr("未知曲目")
            elide: Text.ElideRight
            color: Qt.rgba(0.96, 0.94, 0.98, 1)
            font.pointSize: Appearance.font.size.bodyMedium
        }

        StyledText {
            id: capsuleArtist

            anchors.left: capsuleTitle.left
            anchors.right: capsuleTitle.right
            anchors.top: capsuleTitle.bottom
            anchors.topMargin: 1

            text: root.artist
            elide: Text.ElideRight
            color: Qt.rgba(0.78, 0.75, 0.84, 1)
            font.pointSize: Appearance.font.size.labelLarge
        }

        // Progress: track + fill, then elapsed/total.
        Item {
            id: capsuleProgress

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Appearance.padding.md
            anchors.rightMargin: Appearance.padding.md
            anchors.top: capsuleArt.bottom
            anchors.topMargin: Appearance.spacing.sm
            height: 4

            visible: root.progressEnabled

            StyledRect {
                anchors.fill: parent
                radius: height / 2
                color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.25)
            }

            StyledRect {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.progress
                height: parent.height
                radius: height / 2
                color: Colours.palette.m3primary

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Row {
            id: capsuleTimes

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Appearance.padding.md
            anchors.rightMargin: Appearance.padding.md
            anchors.top: capsuleProgress.bottom
            anchors.topMargin: 2
            height: 13

            visible: root.progressEnabled

            StyledText {
                text: root.formatTime(root.trackPosition)
                verticalAlignment: Text.AlignVCenter
                color: Qt.rgba(0.72, 0.76, 0.86, 1)
                font.pointSize: Appearance.font.size.labelSmall
                font.family: Appearance.font.family.mono
            }

            Item {
                width: Math.max(0, capsuleTimes.width - capsuleElapsed.implicitWidth * 2)
                height: 1
            }

            StyledText {
                id: capsuleElapsed

                text: root.formatTime(root.trackLength)
                verticalAlignment: Text.AlignVCenter
                color: Qt.rgba(0.72, 0.76, 0.86, 1)
                font.pointSize: Appearance.font.size.labelSmall
                font.family: Appearance.font.family.mono
            }
        }

        Row {
            id: capsuleControls

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: capsuleTimes.bottom
            anchors.topMargin: Appearance.spacing.xs
            spacing: Appearance.spacing.lg

            IconButton {
                icon: "skip_previous"
                type: IconButton.Text
                disabled: !root.hasMedia || !root.player.canGoPrevious
                font.pointSize: Appearance.font.size.bodyLarge
                onClicked: {
                    if (root.hasMedia)
                        root.player.previous();
                }
            }

            IconButton {
                icon: root.playing ? "pause" : "play_arrow"
                type: IconButton.Text
                disabled: !root.hasMedia || !root.player.canTogglePlaying
                font.pointSize: Appearance.font.size.titleMedium
                onClicked: {
                    if (root.hasMedia)
                        root.player.togglePlaying();
                }
            }

            IconButton {
                icon: "skip_next"
                type: IconButton.Text
                disabled: !root.hasMedia || !root.player.canGoNext
                font.pointSize: Appearance.font.size.bodyLarge
                onClicked: {
                    if (root.hasMedia)
                        root.player.next();
                }
            }
        }
    }
}
