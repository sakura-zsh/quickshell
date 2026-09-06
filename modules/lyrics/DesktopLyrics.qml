pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // True while an MPRIS player is registered with an actual track.
    // Some environments keep a placeholder player around without a track,
    // so "active player" alone is not enough for auto-hide.
    readonly property bool hasMedia: !!Players.active && !!Players.active.trackTitle

    readonly property bool showControls: (Config.dock.media.showControls ?? true) && !(Config.dock.media.compact ?? false)
    readonly property bool showSecondary: (Config.dock.media.showSecondary ?? true) && !(Config.dock.media.compact ?? false)

    readonly property bool isPlaying: Players.active?.isPlaying ?? false
    property bool pillHovered: false

    readonly property Item clickTarget: pill

    // Width assigned by Wrapper
    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    StyledRect {
        id: pill

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: content.implicitWidth + Appearance.padding.md * 2
        implicitHeight: Math.max(content.implicitHeight, 34) + Appearance.padding.sm * 2
        radius: Appearance.rounding.large
        color: {
            if (Colours.transparency.enabled)
                return Colours.layer(Colours.palette.m3surfaceContainer, 0);
            return Qt.alpha(Colours.tPalette.m3surfaceContainer, 0.88);
        }
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

        // Glass edge highlight
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: parent.height * 0.42
            radius: parent.radius
            z: 0
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.07)
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        RowLayout {
            id: content

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.sm
            anchors.rightMargin: Appearance.padding.sm
            spacing: Appearance.spacing.sm

            // Previous
            Item {
                id: prevBtn

                visible: root.showControls
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.fillHeight: true

                StyledRect {
                    anchors.centerIn: parent
                    width: 34
                    height: 34
                    radius: width / 2
                    color: prevMouse.containsMouse ? Qt.alpha(Colours.palette.m3primary, 0.16) : "transparent"

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "skip_previous"
                        color: Colours.palette.m3onSurface
                        font.pointSize: Appearance.font.size.titleMedium
                        opacity: 0.9
                    }
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Lyrics.previous()
                }
            }

            // Lyrics
            ColumnLayout {
                id: lyricsCol

                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.hasMedia && Lyrics.isSynced && text.length > 0
                    text: Lyrics.previousLine
                    color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.55)
                    font.family: "Noto Sans CJK SC"
                    font.pointSize: Appearance.font.size.labelMedium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.hasMedia ? (Lyrics.displayPrimary || " ") : qsTr("无媒体")
                    color: root.hasMedia ? Colours.palette.m3onSurface : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.7)
                    font.family: "Noto Sans CJK SC"
                    font.pointSize: Appearance.font.size.bodyLarge
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.hasMedia && Lyrics.isSynced && text.length > 0
                    text: Lyrics.nextLine
                    color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.55)
                    font.family: "Noto Sans CJK SC"
                    font.pointSize: Appearance.font.size.labelMedium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 1
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.hasMedia && root.showSecondary
                    text: Lyrics.displaySecondary || " "
                    color: Colours.palette.m3outline
                    font.family: "Noto Sans CJK SC"
                    font.pointSize: Appearance.font.size.labelSmall
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                MouseArea {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }

            // Next
            Item {
                id: nextBtn

                visible: root.showControls
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.fillHeight: true

                StyledRect {
                    anchors.centerIn: parent
                    width: 34
                    height: 34
                    radius: width / 2
                    color: nextMouse.containsMouse ? Qt.alpha(Colours.palette.m3primary, 0.16) : "transparent"

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "skip_next"
                        color: Colours.palette.m3onSurface
                        font.pointSize: Appearance.font.size.titleMedium
                        opacity: 0.9
                    }
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Lyrics.next()
                }
            }
        }

        // Center play/pause overlay: shown while hovering the pill,
        // replacing the old "click anywhere to pause" behaviour.
        Item {
            id: playOverlay

            anchors.centerIn: parent
            width: 38
            height: 38
            z: 10
            visible: root.hasMedia
            opacity: root.pillHovered ? 1 : 0
            scale: root.pillHovered ? 1 : 0.8

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            StyledRect {
                anchors.fill: parent
                radius: width / 2
                color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.9)
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.isPlaying ? "pause" : "play_arrow"
                color: Colours.palette.m3onSurface
                font.pointSize: Appearance.font.size.titleMedium
                fill: 1
            }

            MouseArea {
                id: playBtnMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Lyrics.togglePlaying()
            }
        }
    }

    // Pill-wide hover tracking (does not steal clicks from child controls)
    MouseArea {
        anchors.fill: pill
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: root.pillHovered = containsMouse
    }

    Elevation {
        anchors.fill: pill
        radius: pill.radius
        level: 2
        z: -1
    }
}
