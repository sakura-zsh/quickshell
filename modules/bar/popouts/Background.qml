import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

// Background for a popout attached to the *bottom* of the top bar.
//
// Frame on: the top edge stays square so the popout fuses with the strip behind
// the bar; only the bottom corners are rounded (they flatten when the popout
// reaches the bottom screen edge).
//
// Frame off: with no strip above it the popout is a card of its own — all four
// corners rounded, in the same tone as the function block it hangs from.
ShapePath {
    id: root

    required property Wrapper wrapper
    required property bool invertBottomRounding

    readonly property real rounding: wrapper.isDetached ? Appearance.rounding.normal : Config.border.rounding
    readonly property bool floating: !Config.border.enabled

    // One radius for every corner, clamped so it can never exceed the box.
    readonly property real rMax: Math.min(rounding, wrapper.width / 2, wrapper.height / 2)
    // A hair of rounding in the "square" case: a zero radius makes the arc
    // degenerate.
    readonly property real rTop: floating ? rMax : 0.5
    readonly property real rBottom: invertBottomRounding ? 0.5 : rMax

    // Kept for API compatibility with the callers; the attached edge is
    // always the top one in the horizontal layout.
    readonly property real sideRounding: 1

    strokeWidth: -1
    fillColor: floating ? Colours.barBlock : Colours.shellSurface

    startX: root.wrapper.x + root.rTop
    startY: root.wrapper.y

    // Top edge
    PathLine {
        relativeX: root.wrapper.width - root.rTop * 2
        relativeY: 0
    }
    // Top-right corner
    PathArc {
        relativeX: root.rTop
        relativeY: root.rTop
        radiusX: root.rTop
        radiusY: root.rTop
        direction: PathArc.Clockwise
    }
    // Right edge
    PathLine {
        relativeX: 0
        relativeY: root.wrapper.height - root.rTop - root.rBottom
    }
    // Bottom-right corner
    PathArc {
        relativeX: -root.rBottom
        relativeY: root.rBottom
        radiusX: root.rBottom
        radiusY: root.rBottom
        direction: PathArc.Clockwise
    }
    // Bottom edge
    PathLine {
        relativeX: -(root.wrapper.width - root.rBottom * 2)
        relativeY: 0
    }
    // Bottom-left corner
    PathArc {
        relativeX: -root.rBottom
        relativeY: -root.rBottom
        radiusX: root.rBottom
        radiusY: root.rBottom
        direction: PathArc.Clockwise
    }
    // Left edge
    PathLine {
        relativeX: 0
        relativeY: -(root.wrapper.height - root.rBottom - root.rTop)
    }
    // Top-left corner
    PathArc {
        relativeX: root.rTop
        relativeY: -root.rTop
        radiusX: root.rTop
        radiusY: root.rTop
        direction: PathArc.Clockwise
    }

    Behavior on fillColor {
        CAnim {}
    }
}
