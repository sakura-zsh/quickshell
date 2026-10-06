pragma ComponentBehavior: Bound

import qs.components
import qs.config
import qs.services
import qs.utils
import Quickshell
import Quickshell.Widgets
import QtQuick
import "DockEntries.js" as DockEntries

// Hover preview for one dock entry: live window thumbnails plus per-window
// controls. Thumbnails come from DockPreview, which captures them lazily.
StyledRect {
    id: root

    property var app: null
    property var windows: []
    property int iconSize: 48

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool hasWindows: root.windows.length > 0
    readonly property int cardWidth: Config.dock.previewWidth ?? 220
    readonly property int cardHeight: Math.round(root.cardWidth * 0.62) + 30
    readonly property int maxCards: 5
    readonly property int shownCards: Math.max(1, Math.min(root.windows.length, root.maxCards))
    readonly property var entry: DockEntries.resolveEntry(root.app, DesktopEntries)
    readonly property string appName: {
        if (root.app && root.app.name)
            return String(root.app.name);
        if (root.entry && root.entry.name)
            return String(root.entry.name);
        return String(root.app && root.app.id ? root.app.id : "");
    }
    readonly property string appIcon: Icons.getAppIcon(root.app?.icon || root.entry?.icon || DockEntries.desktopId(root.app) || "", "image-missing")

    // Fixed content width: avoids a layout/binding cycle with implicitWidth.
    readonly property int bodyWidth: Math.max(root.cardWidth, root.shownCards * root.cardWidth + (root.shownCards - 1) * Appearance.spacing.sm)

    signal windowActivated(var window)
    signal windowClosed(var window)
    signal closeAllRequested
    signal launchRequested
    signal dismissed

    function windowIds(): var {
        const out = [];
        for (let i = 0; i < root.windows.length; i++) {
            const id = root.windows[i] ? root.windows[i].id : null;
            if (id !== null && id !== undefined)
                out.push(String(id));
        }
        return out;
    }

    implicitWidth: root.bodyWidth + Appearance.padding.md * 2
    implicitHeight: content.implicitHeight + Appearance.padding.md * 2

    radius: Appearance.rounding.large
    color: Colours.transparency.enabled ? Colours.layer(Colours.palette.m3surfaceContainer, 2) : Qt.alpha(Colours.tPalette.m3surfaceContainer, 0.92)
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

    HoverHandler {
        id: hoverHandler
        grabPermissions: PointerHandler.TakeOverForbidden
    }

    // Capture on show, then refresh while the pointer stays here.
    Timer {
        interval: 2500
        repeat: true
        triggeredOnStart: true
        running: root.visible && root.hasWindows && DockPreview.available
        onTriggered: DockPreview.request(root.windowIds(), false)
    }

    onWindowsChanged: {
        if (root.visible)
            DockPreview.request(root.windowIds(), false);
    }

    onVisibleChanged: {
        if (root.visible)
            enterAnim.restart();
    }

    SequentialAnimation {
        id: enterAnim

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    Column {
        id: content

        anchors.centerIn: parent
        width: root.bodyWidth
        spacing: Appearance.spacing.sm

        // ---- header: app identity + actions ----
        Item {
            width: parent.width
            height: Math.max(headerRow.implicitHeight, Math.round(root.iconSize * 0.42))

            Row {
                id: headerRow

                anchors.left: parent.left
                anchors.right: headerActions.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacing.sm

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: Math.round(root.iconSize * 0.42)
                    source: root.appIcon
                    asynchronous: true
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, headerRow.width - Math.round(root.iconSize * 0.42) - Appearance.spacing.sm - countLabel.width - Appearance.spacing.sm)
                    text: root.appName
                    elide: Text.ElideRight
                    font.pointSize: Appearance.font.size.bodyMedium
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    id: countLabel

                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.windows.length > 1
                    text: root.windows.length > root.maxCards ? `+${root.windows.length - root.maxCards}` : `${root.windows.length}`
                    font.pointSize: Appearance.font.size.bodySmall
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Row {
                id: headerActions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacing.xs

                IconAction {
                    icon: "refresh"
                    tip: qsTr("刷新缩略图")
                    onClicked: DockPreview.request(root.windowIds(), true)
                }

                IconAction {
                    icon: "close"
                    visible: root.windows.length > 1
                    tip: qsTr("关闭全部窗口")
                    onClicked: root.closeAllRequested()
                }
            }
        }

        // ---- window cards ----
        Row {
            spacing: Appearance.spacing.sm
            visible: root.hasWindows

            Repeater {
                model: root.windows.slice(0, root.maxCards)

                WindowCard {}
            }
        }

        // ---- no windows: launch only ----
        StyledRect {
            width: parent.width
            height: 40
            radius: Appearance.rounding.small
            color: Qt.alpha(Colours.palette.m3primary, 0.12)
            visible: !root.hasWindows

            StyledText {
                anchors.centerIn: parent
                text: qsTr("打开应用")
                font.pointSize: Appearance.font.size.bodyMedium
                color: Colours.palette.m3primary
            }

            StateLayer {
                radius: parent.radius
                color: Colours.palette.m3primary
                onClicked: root.launchRequested()
            }
        }
    }

    // Rounded box with a small icon glyph, used for the header actions.
    component IconAction: StyledRect {
        id: action

        property string icon
        property string tip

        width: 24
        height: 24
        radius: width / 2
        color: actionHover.hovered ? Qt.alpha(Colours.palette.m3onSurface, 0.1) : "transparent"

        HoverHandler {
            id: actionHover
            grabPermissions: PointerHandler.TakeOverForbidden
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: action.icon
            font.pointSize: Appearance.font.size.bodyMedium
            color: Colours.palette.m3onSurfaceVariant
        }

        StateLayer {
            radius: parent.radius
            onClicked: action.clicked()
        }

        signal clicked
    }

    component WindowCard: StyledRect {
        id: card

        required property var modelData

        readonly property bool focused: !!card.modelData?.is_focused
        readonly property bool closeHovered: closeBtn.hovered

        width: root.cardWidth
        height: root.cardHeight
        radius: Appearance.rounding.normal
        color: cardHover.hovered ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) : (Colours.transparency.enabled ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 2) : Colours.palette.m3surfaceContainerHigh)
        border.width: card.focused ? 2 : 1
        border.color: card.focused ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
        clip: true

        HoverHandler {
            id: cardHover
            grabPermissions: PointerHandler.TakeOverForbidden
        }

        Image {
            id: thumb

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.cardHeight - 30
            source: {
                const revision = DockPreview.revision;
                return DockPreview.thumb(card.modelData?.id);
            }
            sourceSize.width: Math.round(root.cardWidth * 1.5)
            sourceSize.height: Math.round((root.cardHeight - 30) * 1.5)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: status === Image.Ready
        }

        // Placeholder until the first capture lands.
        IconImage {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round((root.cardHeight - 30 - Math.round(root.iconSize * 0.7)) / 2)
            visible: !thumb.visible
            implicitSize: Math.round(root.iconSize * 0.7)
            source: root.appIcon
            asynchronous: true
        }

        StyledText {
            id: cardTitle

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Appearance.padding.sm
            anchors.rightMargin: Appearance.padding.sm
            height: 30
            text: String(card.modelData?.title ?? root.appName)
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            font.pointSize: Appearance.font.size.bodySmall
            color: Colours.palette.m3onSurface
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    root.windowClosed(card.modelData);
                else
                    root.windowActivated(card.modelData);
            }
        }

        StyledRect {
            id: closeBtn

            readonly property bool hovered: closeHover.hovered

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            width: 22
            height: 22
            radius: width / 2
            color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.92)
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
            visible: cardHover.hovered || closeHover.hovered
            z: 2

            HoverHandler {
                id: closeHover
                grabPermissions: PointerHandler.TakeOverForbidden
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "close"
                font.pointSize: Appearance.font.size.bodyMedium
                color: Colours.palette.m3onSurface
            }

            StateLayer {
                radius: parent.radius
                onClicked: root.windowClosed(card.modelData)
            }
        }
    }
}
