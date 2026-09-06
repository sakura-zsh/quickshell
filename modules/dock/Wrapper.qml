pragma ComponentBehavior: Bound

import qs.components
import qs.config
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen screen

    screen: root.screen

    readonly property string position: Config.dock.position ?? "center"
    readonly property bool showOnHover: Config.dock.showOnHover ?? false
    readonly property real grabHeight: 8

    // Always anchored to bottom+left+right: exclusiveZone only takes effect
    // with 1 or 3 anchors, so a bottom-only + side anchor (2 anchors) would
    // silently fail to reserve space. The full-width window is transparent;
    // `mask` limits actual clickable area to the pill (or the hover grab).
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    margins.bottom: Config.dock.bottomMargin ?? 10
    margins.left: 12
    margins.right: 12

    // Auto-size to dock content (macOS pill, not full-width strip)
    // Include hover growth + tooltip headroom so magnification is not clipped
    implicitWidth: dock.implicitWidth
    implicitHeight: dock.implicitHeight

    visible: Config.dock.enabled ?? true

    // When "show on hover" is enabled the pill starts off-screen; a small grab
    // strip remains visible at the bottom edge to reveal it.
    property bool _userExpanded: false
    readonly property bool expanded: !root.showOnHover || root._userExpanded

    function revealDock(): void {
        root._userExpanded = true;
    }

    function concealDock(): void {
        root._userExpanded = false;
    }

    // Reserve only the visual pill height so hover/tooltip space doesn't push windows
    exclusiveZone: {
        if (!root.visible)
            return 0;
        if (root.showOnHover && !root.expanded)
            return 0;
        return dock.baseHeight + margins.bottom;
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Normal
    WlrLayershell.namespace: "caelestia-dock"

    color: "transparent"

    mask: Region {
        item: root.showOnHover && !root.expanded ? grab : dock.clickTarget
    }

    // Collapse back after the mouse leaves the dock
    Timer {
        id: collapseTimer
        interval: Config.dock.settleDuration ?? 500
        onTriggered: root.concealDock()
    }

    onExpandedChanged: {
        if (root.expanded && !dock.dockHovered && !grabMouse.containsMouse)
            collapseTimer.restart();
    }

    Connections {
        target: dock

        function onDockHoveredChanged(): void {
            if (dock.dockHovered) {
                collapseTimer.stop();
            } else if (root.expanded && root.showOnHover) {
                collapseTimer.restart();
            }
        }
    }

    // Don't steal keyboard focus from apps

    Dock {
        id: dock

        anchors.horizontalCenter: root.position === "center" ? parent.horizontalCenter : undefined
        anchors.left: root.position === "left" ? parent.left : undefined
        anchors.right: root.position === "right" ? parent.right : undefined
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.expanded ? 0 : -(dock.height + margins.bottom)

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    // Invisible-ish grab strip used only while the dock is hidden
    Item {
        id: grab

        anchors.horizontalCenter: root.position === "center" ? parent.horizontalCenter : undefined
        anchors.left: root.position === "left" ? parent.left : undefined
        anchors.right: root.position === "right" ? parent.right : undefined
        anchors.bottom: parent.bottom
        width: 56
        height: root.grabHeight + 6
        z: 20
        visible: root.showOnHover && !root.expanded

        Rectangle {
            anchors.centerIn: parent
            width: 36
            height: 4
            radius: 2
            color: Qt.alpha(Colours.palette.m3onSurface, 0.45)
        }

        MouseArea {
            id: grabMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onContainsMouseChanged: {
                if (grabMouse.containsMouse)
                    root.revealDock();
            }
        }
    }
}
