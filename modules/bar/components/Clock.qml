pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Appearance.padding.normal : Appearance.padding.small

    implicitHeight: Config.bar.sizes.innerWidth
    implicitWidth: layout.implicitWidth + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Appearance.rounding.full

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: Appearance.spacing.sm

        Loader {
            anchors.verticalCenter: parent.verticalCenter

            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            visible: Config.bar.clock.showDate

            text: Time.format("ddd d")
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter

            visible: Config.bar.clock.showDate
            width: visible ? 1 : 0
            height: Appearance.font.size.smaller * 1.6

            color: root.colour
            opacity: 0.2
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            text: Time.format(Config.services.useTwelveHourClock ? "hh:mm A" : "hh:mm")
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
        }
    }
}
