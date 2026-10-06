pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services
import qs.config
import QtQuick

// Pure desktop lyrics band.
//
// The bar's dynamic island owns the whole media surface (cover art, track
// metadata and transport controls), so this component carries no media space at
// all: it only renders the lyric lines of the source the island selected. The
// wrapper keeps it hidden unless that source is actually playing.
//
// The band is exactly the dock pill height and shows three lines at a time: the
// active line sits centred and highlighted, and the strip slides one line at a
// time as playback advances.
Item {
    id: root

    // Dock pill height, shared with the dock so the two are the same height.
    readonly property int bandHeight: Config.dock.sizes.barHeight
    // Three lines fill the band, matching the dock's height.
    readonly property int lineHeight: Math.max(16, Math.floor(root.bandHeight / 3))
    readonly property int lineCount: Lyrics.lineCount()
    readonly property int activeIndex: Math.max(0, Lyrics.currentIndex)

    // Scroll anchor: lags behind activeIndex so lines slide instead of jumping.
    // A large jump (seek / new track) snaps rather than flying through.
    property real anchor: 0
    property bool _snap: false

    function syncAnchor(): void {
        if (Math.abs(root.activeIndex - root.anchor) > 4) {
            root._snap = true;
            root.anchor = root.activeIndex;
            Qt.callLater(() => {
                root._snap = false;
            });
        } else {
            root.anchor = root.activeIndex;
        }
    }

    onActiveIndexChanged: root.syncAnchor()
    onLineCountChanged: root.syncAnchor()
    Component.onCompleted: root.anchor = root.activeIndex

    Behavior on anchor {
        enabled: !root._snap

        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    implicitWidth: Config.dock.media.width ?? 420
    implicitHeight: root.bandHeight

    StyledRect {
        id: pill

        anchors.fill: parent
        radius: Appearance.rounding.large
        color: {
            if (Colours.transparency.enabled)
                return Colours.layer(Colours.palette.m3surfaceContainer, 0);
            return Qt.alpha(Colours.tPalette.m3surfaceContainer, 0.72);
        }
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)

        // Glass edge highlight, matching the dock pill.
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
    }

    Item {
        id: viewport

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.lg
        anchors.rightMargin: Appearance.padding.lg
        z: 1
        clip: true

        // Loading / error / no-lyrics placeholder, shown until lines exist.
        StyledText {
            anchors.centerIn: parent
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.lineCount === 0
            text: Lyrics.displayPrimary
            color: Colours.palette.m3onSurface
            font.family: "Noto Sans CJK SC"
            font.pointSize: Appearance.font.size.bodyLarge
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // Sliding window of lyric lines. Each delegate is positioned by its
        // *absolute* line index minus the animated anchor, so when the active
        // line advances every delegate simply keeps sliding up; the text under
        // the centre never jumps.
        Repeater {
            model: root.lineCount > 0 ? [-2, -1, 0, 1, 2] : []

            delegate: StyledText {
                required property int modelData

                readonly property int lineIndex: root.activeIndex + modelData
                readonly property bool valid: lineIndex >= 0 && lineIndex < root.lineCount
                readonly property real dist: Math.abs(lineIndex - root.anchor)

                anchors.left: parent.left
                anchors.right: parent.right
                height: root.lineHeight
                verticalAlignment: Text.AlignVCenter
                y: (lineIndex - root.anchor) * root.lineHeight + (viewport.height - root.lineHeight) / 2
                visible: valid
                text: valid ? Lyrics.lineTextAt(lineIndex) : ""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                opacity: valid ? Math.max(0.15, 1 - dist * 0.5) : 0
                // Smoothly grows into the active line instead of popping.
                font.pointSize: Appearance.font.size.labelLarge + (Appearance.font.size.bodyLarge - Appearance.font.size.labelLarge) * Math.max(0, 1 - dist)
                font.weight: Font.DemiBold
                font.family: "Noto Sans CJK SC"
                color: dist < 0.5 ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
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
