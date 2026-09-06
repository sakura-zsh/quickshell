pragma ComponentBehavior: Bound

import qs.services
import qs.config
import Quickshell
import Quickshell.Wayland
import QtQuick

// Bottom band aligned with dock; lyrics pill flush to the desktop right edge.
PanelWindow {
    id: root

    required property ShellScreen screen
    property PersistentProperties visibilities: null

    screen: root.screen

    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    implicitHeight: Math.max(lyrics.implicitHeight + 8, 44)
    margins.bottom: Config.dock.media.bottomMargin ?? 10
    margins.right: Config.dock.media.rightMargin ?? 12

    visible: (Config.dock.media.enabled ?? true)
        && (!(Config.dock.media.autoHide ?? true) || lyrics.hasMedia)
        && (root.visibilities ? !root.visibilities.quicktoggles : true)

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "caelestia-lyrics"

    color: "transparent"

    mask: Region {
        item: lyrics.clickTarget
    }

    DesktopLyrics {
        id: lyrics

        anchors.right: parent.right
        anchors.rightMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(Config.dock.media.width ?? 420, Math.max(240, parent.width - margins.right * 2))
    }
}
