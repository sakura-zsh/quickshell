pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

// Time face of the bar's dynamic island: optional icon, date and clock.
// The pill, padding and background live in Island.qml so the same face can be
// reused while the island grows into a media controller.
Row {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property bool showDate: Config.bar.clock.showDate
    readonly property bool showIcon: Config.bar.clock.showIcon

    spacing: Appearance.spacing.sm

    Loader {
        anchors.verticalCenter: parent.verticalCenter

        active: root.showIcon
        visible: active

        sourceComponent: MaterialIcon {
            text: "calendar_month"
            color: root.colour
        }
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter

        visible: root.showDate

        text: Time.format(Config.bar.clock.dateFormat ?? "M月d日 ddd")
        font.pointSize: Appearance.font.size.smaller
        font.family: Appearance.font.family.mono
        color: root.colour
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter

        text: Time.format(Config.services.useTwelveHourClock ? (Config.bar.clock.showSeconds ? "hh:mm:ss A" : "hh:mm A") : (Config.bar.clock.showSeconds ? "hh:mm:ss" : "hh:mm"))
        font.pointSize: Appearance.font.size.smaller
        font.family: Appearance.font.family.mono
        color: root.colour
    }
}
