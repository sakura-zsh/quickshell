pragma ComponentBehavior: Bound

import qs.services
import qs.config
import Caelestia.Services
import Quickshell
import Quickshell.Wayland
import QtQuick

// Audio visualizer at the bottom-left, just right of the status bar.
// Self-contained: sizing comes from Config + screen only, so no cross-window
// bindings that can crash during hot-reload teardown.
PanelWindow {
    id: root

    required property ShellScreen screen
    readonly property real barWidth: Config.dock.visualiser.barWidth ?? 4
    readonly property real barGap: Config.dock.visualiser.barGap ?? 4
    readonly property int barHeight: Config.dock.visualiser.barHeight ?? 48
    readonly property int minBarCount: Config.dock.visualiser.minBarCount ?? 14
    readonly property int maxBarCount: Config.dock.visualiser.maxBarCount ?? 96
    readonly property bool autoHide: Config.dock.visualiser.autoHide ?? true

    // True while an MPRIS player is registered with an actual track.
    // Some environments keep a placeholder player around without a track,
    // so "active player" alone is not enough for auto-hide.
    readonly property bool hasMedia: !!Players.active && !!Players.active.trackTitle

    // Left offset: flush against the screen edge. The top bar no longer
    // reserves any left-side space; config value is the only offset.
    readonly property int leftMargin: Config.dock.visualiser.leftMargin ?? 0

    // Length: about half the status-bar→dock span. The right edge is free
    // (no longer touching the dock), so a screen-relative width is enough.
    readonly property int vizWidth: {
        const fixed = Config.dock.visualiser.width ?? 0;
        if (fixed > 0)
            return fixed;
        const sw = screen?.width ?? 0;
        if (sw <= 0)
            return 0;
        const divisor = Config.dock.visualiser.autoWidthDivisor ?? 5.5;
        return Math.max(220, Math.round(sw / divisor));
    }

    // Fixed bar count so the Repeater never churns on reload/layout changes
    readonly property int barCount: {
        const span = root.vizWidth;
        if (span <= 0)
            return root.minBarCount;
        const count = Math.floor(span / (root.barWidth + root.barGap));
        return Math.min(root.maxBarCount, Math.max(root.minBarCount, count));
    }

    screen: root.screen

    anchors.left: true
    anchors.bottom: true

    implicitWidth: root.vizWidth
    implicitHeight: Math.max(root.barHeight + 8, 44)
    margins.bottom: Config.dock.visualiser.bottomMargin ?? 10
    margins.left: root.leftMargin

    visible: (Config.dock.visualiser.enabled ?? true) && (!root.autoHide || root.hasMedia)

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "caelestia-dock-visualiser"

    color: "transparent"

    // Pure display — never capture input
    mask: Region {}

    // Only capture audio while media exists
    Loader {
        active: root.hasMedia
        sourceComponent: ServiceRef {
            service: Cava.provider
        }
    }

    Item {
        id: viz

        anchors.left: parent.left
        anchors.bottom: parent.bottom

        width: parent.width
        height: root.barHeight

        Repeater {
            model: root.barCount

            Rectangle {
                required property int index

                readonly property real value: {
                    if (!root.hasMedia)
                        return 0;
                    const values = Cava.values;
                    const count = values.length;
                    if (count === 0)
                        return 0;
                    const idx = Math.min(count - 1, Math.floor(index * count / root.barCount));
                    return Math.max(0, Math.min(1, values[idx] ?? 0));
                }

                width: root.barWidth
                height: root.hasMedia ? Math.max(2, Math.min(parent.height - 4, value * (parent.height - 4) * 1.5)) : 0
                x: index * (root.barWidth + root.barGap)
                y: parent.height - 2 - height
                radius: Math.min(2, root.barWidth / 2)

                gradient: Gradient {
                    orientation: Gradient.Vertical

                    GradientStop {
                        position: 0.0
                        color: Qt.alpha(Colours.palette.m3primary, 0.9)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.alpha(Colours.palette.m3inversePrimary, 0.9)
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: Config.dock.visualiser.animDuration ?? 90
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
