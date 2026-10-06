pragma ComponentBehavior: Bound

import qs.services
import qs.config
import Quickshell
import Quickshell.Wayland
import QtQuick

// Desktop lyrics band: bottom-right, level with the dock.
//
// The bar's dynamic island owns all media controls, so this window is a pure
// display surface. It only exists while the media source the island selected —
// a whitelisted player when the island whitelist is in use — is playing, or was
// playing a moment ago: `Players.islandSourceSteady` holds the band through the
// gap Cider leaves in MPRIS while it swaps tracks, so switching songs no longer
// unmaps and remaps the whole surface. A background player the island ignores
// never draws a lyrics band.
//
// Height equals the dock pill and the bottom margin matches the dock's, so the
// lyrics band and the dock sit on the same line as one bottom band.
PanelWindow {
    id: root

    required property ShellScreen screen
    property PersistentProperties visibilities: null

    screen: root.screen

    // Dock pill height, shared with the dock so both surfaces match exactly.
    readonly property int bandHeight: Config.dock.sizes.barHeight

    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    implicitHeight: root.bandHeight
    // Same bottom margin as the dock, so the two bands are flush on one line.
    margins.bottom: Config.dock.bottomMargin ?? 10
    margins.right: Config.dock.media.rightMargin ?? 12

    visible: (Config.dock.media.enabled ?? true)
        && (Config.services.desktopLyrics ?? true)
        && Players.islandSourceSteady
        && (root.visibilities ? !root.visibilities.quicktoggles : true)

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "caelestia-lyrics"

    color: "transparent"

    // Pure display — never captures input; media interaction stays on the island.
    mask: Region {}

    DesktopLyrics {
        id: lyrics

        anchors.right: parent.right
        anchors.rightMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(Config.dock.media.width ?? 420, Math.max(240, parent.width - margins.right * 2))
        height: root.bandHeight
    }
}
