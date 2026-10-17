pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property Item bar

    anchors.fill: parent
    // With the frame switched off nothing is painted here: the bar's modules
    // draw their own islands (modules/bar/Bar.qml) and the wallpaper shows
    // through everywhere the frame used to cover it.
    visible: Config.border.enabled && Config.border.thickness > 0

    StyledRect {
        anchors.fill: parent
        color: Colours.shellSurface

        layer.enabled: root.visible
        layer.effect: MultiEffect {
            maskSource: mask
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Item {
        id: mask

        anchors.fill: parent
        layer.enabled: root.visible
        visible: false

        Rectangle {
            anchors.fill: parent
            anchors.margins: Config.border.thickness
            anchors.topMargin: root.bar.implicitHeight
            radius: Config.border.rounding
        }
    }
}
