pragma ComponentBehavior: Bound

import qs.services
import qs.config
import QtQuick
import qs.components.effects
import qs.components

Item {
    id: root

    required property int groupOffset
    required property int wsOffset
    required property Item anchorWs

    // --- Helpers ---
    readonly property bool isItem: Niri.wsContextType === "item"
    readonly property bool isWorkspaces: Niri.wsContextType === "workspaces"
    readonly property bool isWorkspace: Niri.wsContextType === "workspace"
    readonly property bool hasWindows: (isItem && anchorWs?.wsWindowCount > 0) || (isWorkspace && anchorWs?.isOccupied)
    readonly property bool isFocused: (isItem && anchorWs?.isWsFocused) || (isWorkspace && (Number(anchorWs?.index) === Number(Niri.focusedWorkspaceIndex)))

    readonly property int rounding: Appearance.rounding.small
    readonly property int gPadding: isItem ? Appearance.padding.xs / 2 : 0
    readonly property int cornerPieceSize: Config.bar.workspaces.windowIconSize + Appearance.padding.xs

    property bool activated: false
    Component.onCompleted: root.activated = true

    property color bgColor: isWorkspaces ? Colours.palette.m3surfaceContainer : ((isFocused) ? Qt.alpha(Colours.palette.m3primary, 0.95) : (hasWindows ? Colours.palette.m3surfaceContainerHigh : "transparent"))

    // --- Highlight Rect ---
    // Horizontal bar: when active this becomes a dropdown card as wide as the
    // context width, left-aligned under the anchored icon and extending
    // downward from the bar; when inactive it just backs the icon.
    component HighlightRect: Rectangle {
        id: hrect

        color: root.bgColor

        readonly property bool active: root.activated && !!Niri.wsContextAnchor

        width: active ? Config.bar.workspaces.windowContextWidth + root.gPadding * 2 : (root.anchorWs?.width ?? 0) + root.gPadding * 2
        height: active ? Config.bar.workspaces.windowContextWidth + Config.bar.workspaces.windowIconSize + Appearance.padding.xs * 2 : Config.bar.workspaces.windowIconSize

        x: root.anchorWs?.mapToItem(root, 0, 0).x - root.gPadding ?? 0
        y: 0

        radius: root.rounding
        bottomLeftRadius: Appearance.rounding.normal
        bottomRightRadius: Appearance.rounding.normal

        Behavior on color {
            CAnim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        Behavior on radius {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on bottomLeftRadius {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on bottomRightRadius {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        Behavior on width {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on height {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on opacity {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        Behavior on x {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on y {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }

    HighlightRect {
        id: highlightLow
        color: !root.isWorkspaces ? Colours.palette.m3surfaceContainer : "transparent"

        anchors.fill: highlight

        anchors.margins: -Appearance.padding.xs
        anchors.topMargin: -Appearance.padding.xs + 1
    }

    HighlightRect {
        id: highlight

        bottomLeftRadius: Appearance.rounding.small
        bottomRightRadius: Appearance.rounding.small
    }
}
