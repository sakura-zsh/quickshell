import qs.components
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root
    anchors.left: parent.right
    anchors.verticalCenter: parent.verticalCenter

    required property int groupOffset

    Component.onCompleted: active = true
    property bool active: false
    property bool entered: Config.bar.workspaces.shown < Niri.getWorkspaceCount() && active

    readonly property int wsCount: Niri.getWorkspaceCount()
    readonly property int focusedIdx: Niri.focusedWorkspaceIndex

    color: Colours.palette.m3surfaceContainer
    radius: entered ? Appearance.rounding.small / 2 : Appearance.rounding.full

    anchors.leftMargin: entered ? -Appearance.padding.md : -Config.bar.sizes.innerWidth

    height: Config.bar.sizes.innerWidth - Appearance.spacing.sm
    width: minimap.width + Appearance.spacing.sm * 2

    Behavior on anchors.leftMargin {
        Anim {}
    }

    // Scroll-position minimap
    Column {
        id: minimap

        opacity: root.entered ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: root.wsCount

            Rectangle {
                required property int index

                height: Math.max(3, (root.height - minimap.spacing * (root.wsCount - 1) - Appearance.spacing.sm * 2) / root.wsCount)
                width: index === root.focusedIdx ? 6 : 3
                radius: width / 2
                color: index === root.focusedIdx ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on width {
                    Anim {
                        duration: Appearance.anim.durations.small
                    }
                }

                CAnim on color {}
            }
        }

        Behavior on opacity {
            Anim {}
        }
    }
}
