pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.config

import qs.components.widgets

Rectangle {
    id: root

    readonly property int contextWidth: Config.bar.workspaces.windowContextWidth
    readonly property int baseRadius: Appearance.rounding.normal
    readonly property int hPadding: Appearance.padding.xs
    readonly property int textWidth: root.itemH - hPadding * 2

    required property bool onPrimary
    required property bool isFocused
    required property int itemH
    required property bool popupActive
    required property var mainWindow

    property bool activated: false

    Component.onCompleted: activated = true

    color: "transparent"

    anchors.top: parent.top

    required property string displayTitle
    required property string displaySubtitle

    clip: true

    // Vertical extension hanging below the window icon in the horizontal bar:
    // fixed thickness (= icon width), length grows downward when active.
    implicitWidth: root.itemH
    implicitHeight: root.popupActive && Niri.wsContextAnchor && root.activated ? root.contextWidth + root.hPadding : 0

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        AnimatedText {
            Layout.topMargin: 0
            text: root.displayTitle
            font.pointSize: Appearance.font.size.labelMedium
            font.italic: root.isFocused
            color: root.onPrimary ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        }

        Rectangle {
            implicitWidth: classText.width + Appearance.padding.xs * 2
            implicitHeight: classText.height
            color: root.onPrimary ? Colours.palette.m3tertiary : "transparent"

            radius: root.baseRadius / 2

            Behavior on color {
                CAnim {}
            }

            AnimatedText {
                id: classText

                anchors.centerIn: parent

                text: root.displaySubtitle
                font.pointSize: Appearance.font.size.labelSmall
                font.family: Appearance.font.family.mono
                font.bold: root.isFocused
                color: root.onPrimary ? Colours.palette.m3onTertiary : Colours.palette.m3tertiaryContainer
            }
        }

        Rectangle {
            id: windowDecs
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Appearance.padding.xs
            color: "transparent"

            implicitWidth: decs.implicitWidth + root.hPadding
            implicitHeight: decs.implicitHeight + root.hPadding
            radius: Appearance.rounding.small

            WindowDecorations {
                id: decs
                anchors.centerIn: parent
                client: root.mainWindow
                opacity: mouseArea.containsMouse ? 1 : 0
                implicitSize: Appearance.font.size.labelLarge
                Behavior on opacity {
                    Anim {
                        duration: Appearance.anim.durations.normal
                    }
                }
            }
        }
    }

    StateLayer {
        id: mouseArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        propagateComposedEvents: true
        hoverEnabled: true

        cursorShape: Qt.ArrowCursor

        width: parent.width
        height: windowDecs.implicitHeight + root.hPadding * 2
    }

    // Local reusable StyledText with common props
    component AnimatedText: StyledText {
        Layout.preferredWidth: root.textWidth
        animate: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter

        Behavior on color {
            CAnim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        Behavior on font.pointSize {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }
}
