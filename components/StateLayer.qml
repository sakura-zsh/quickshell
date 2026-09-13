import qs.services
import qs.config
import QtQuick

MouseArea {
    id: root

    property bool disabled
    property bool showHoverBackground: true
    property bool showFocusRing: true
    property color color: Colours.palette.m3onSurface
    property real radius: parent?.radius ?? 0
    property alias rect: hoverLayer

    function onClicked(): void {
    }

    // M3 ripple: expand and fade simultaneously from the press point
    // (Canvas-based, adapted from Clavis Shell).
    function rippleAt(x: real, y: real): void {
        if (disabled)
            return;

        ripple.centerX = x;
        ripple.centerY = y;

        const dist = (ox, oy) => ox * ox + oy * oy;
        ripple.targetRadius = Math.sqrt(Math.max(dist(x, y), dist(x, height - y), dist(width - x, y), dist(width - x, height - y)));

        rippleAnim.restart();
    }

    anchors.fill: parent

    enabled: !disabled
    cursorShape: disabled ? undefined : Qt.PointingHandCursor
    hoverEnabled: true

    onPressed: event => root.rippleAt(event.x, event.y)

    onClicked: event => !disabled && onClicked(event)

    NumberAnimation {
        id: rippleAnim

        target: ripple
        property: "progress"
        from: 0
        to: 1
        duration: Appearance.anim.durations.normal
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.anim.curves.standardDecel
        onFinished: ripple.progress = 0
    }

    StyledClippingRect {
        id: hoverLayer

        anchors.fill: parent

        color: Qt.alpha(root.color, root.disabled ? 0 : root.pressed ? 0.12 : (root.showHoverBackground && root.containsMouse) ? 0.08 : 0)
        radius: root.radius

        Canvas {
            id: ripple

            property real progress
            property real centerX
            property real centerY
            property real targetRadius
            readonly property bool active: progress > 0

            anchors.fill: parent
            visible: active
            renderStrategy: Canvas.Immediate
            antialiasing: true

            onVisibleChanged: {
                if (visible)
                    requestPaint();

            }
            onProgressChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);
                if (!root.enabled || width <= 0 || height <= 0)
                    return ;

                const cr = Math.min(root.radius, width / 2, height / 2);
                ctx.beginPath();
                ctx.moveTo(cr, 0);
                ctx.lineTo(width - cr, 0);
                ctx.quadraticCurveTo(width, 0, width, cr);
                ctx.lineTo(width, height - cr);
                ctx.quadraticCurveTo(width, height, width - cr, height);
                ctx.lineTo(cr, height);
                ctx.quadraticCurveTo(0, height, 0, height - cr);
                ctx.lineTo(0, cr);
                ctx.quadraticCurveTo(0, 0, cr, 0);
                ctx.closePath();
                ctx.clip();
                ctx.globalAlpha = 0.18 * (1 - progress);
                ctx.fillStyle = String(root.color);
                ctx.beginPath();
                ctx.arc(centerX, centerY, targetRadius * progress, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    FocusRing {
        visible: root.showFocusRing && (root.parent?.activeFocus ?? false)
    }
}
