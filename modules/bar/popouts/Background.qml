import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

// Fused background for a popout attached to the *bottom* of the top bar.
// The top edge is square so it merges seamlessly with the bar above it;
// only the bottom corners are rounded (unless the popout reaches the
// bottom screen edge, in which case they flatten too).
ShapePath {
    id: root

    required property Wrapper wrapper
    required property bool invertBottomRounding
    readonly property real rounding: wrapper.isDetached ? Appearance.rounding.normal : Config.border.rounding
    readonly property bool flatten: wrapper.width < rounding * 2
    readonly property real roundingX: flatten ? wrapper.width / 2 : rounding
    property real ibr: invertBottomRounding ? -1 : 1

    // Kept for API compatibility with the callers; the attached edge is
    // always the top one in the horizontal layout.
    readonly property real sideRounding: 1

    strokeWidth: -1
    fillColor: Colours.palette.m3surface

    // Top edge — square, runs along the bottom of the bar
    PathLine {
        relativeX: root.wrapper.width
        relativeY: 0
    }
    // Right edge down to the bottom-right corner
    PathLine {
        relativeX: 0
        relativeY: root.wrapper.height - root.rounding
    }
    // Bottom-right corner
    PathArc {
        relativeX: -root.roundingX
        relativeY: root.rounding * root.ibr
        radiusX: Math.min(root.rounding, root.wrapper.width)
        radiusY: root.rounding
        direction: root.ibr > 0 ? PathArc.Clockwise : PathArc.Counterclockwise
    }
    // Bottom edge
    PathLine {
        relativeX: -(root.wrapper.width - root.roundingX * 2)
        relativeY: 0
    }
    // Bottom-left corner
    PathArc {
        relativeX: -root.roundingX
        relativeY: -root.rounding * root.ibr
        radiusX: Math.min(root.rounding, root.wrapper.width)
        radiusY: root.rounding
        direction: root.ibr > 0 ? PathArc.Clockwise : PathArc.Counterclockwise
    }
    // Left edge back up to the start
    PathLine {
        relativeX: 0
        relativeY: -(root.wrapper.height - root.rounding * 2)
    }

    Behavior on fillColor {
        CAnim {}
    }

    Behavior on ibr {
        Anim {}
    }
}
