pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.utils
import qs.config
import QtQuick

// Horizontal active-window indicator: [icon] [title] [col/total]
// Config.bar.activeWindow.inverted is a no-op in the top layout (it used to
// flip the 90° rotation of the vertical title).
StyledRect {
    id: root

    required property var bar
    required property Brightness.Monitor monitor
    property color colour: Colours.palette.m3primary

    // Column count indicator
    readonly property var activeWindows: Niri.getActiveWorkspaceWindows()
    readonly property int columnCount: {
        const cols = new Set();
        for (const w of activeWindows) {
            if (w.layout?.pos_in_scrolling_layout)
                cols.add(w.layout.pos_in_scrolling_layout[0]);
        }
        return cols.size;
    }
    readonly property int focusedColumn: {
        const fw = Niri.focusedWindow;
        if (!fw?.layout?.pos_in_scrolling_layout)
            return 0;
        const focusedX = fw.layout.pos_in_scrolling_layout[0];
        const cols = [];
        for (const w of activeWindows) {
            if (w.layout?.pos_in_scrolling_layout)
                cols.push(w.layout.pos_in_scrolling_layout[0]);
        }
        const sorted = [...new Set(cols)].sort((a, b) => a - b);
        return sorted.indexOf(focusedX) + 1;
    }

    readonly property int maxWidth: {
        const otherModules = bar.children.filter(c => c.id && c.item !== this && c.id !== "spacer");
        const otherWidth = otherModules.reduce((acc, curr) => acc + curr.width, 0);
        // Length - 2 cause repeater counts as a child
        const available = bar.width - otherWidth - bar.spacing * (bar.children.length - 1) - bar.hPadding * 2;
        const cap = Config.bar.activeWindow.maxWidth;
        return cap > 0 ? Math.min(available, cap) : available;
    }
    property Title current: text1

    readonly property string windowTitle: Niri.focusedWindowTitle ?? qsTr("桌面")

    function getCompactName() {
        if (!root.windowTitle || root.windowTitle === qsTr("桌面"))
            return qsTr("桌面");
        // " - " (standard hyphen), " — " (em dash), " – " (en dash)
        const parts = root.windowTitle.split(/\s+[\-\u2013\u2014]\s+/);
        if (parts.length > 1)
            return parts[parts.length - 1].trim();
        return root.windowTitle;
    }

    readonly property int itemSpacing: Appearance.spacing.sm
    readonly property int hPadding: Config.bar.activeWindow.background ? Appearance.padding.md : 0

    clip: true
    implicitWidth: row.implicitWidth + root.hPadding * 2
    implicitHeight: row.implicitHeight

    // Same colour token as the clock / tray / status pills so every bar
    // module shares one background colour.
    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.activeWindow.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Appearance.rounding.full

    Row {
        id: row

        anchors.centerIn: parent
        spacing: root.itemSpacing

        MaterialIcon {
            id: icon

            anchors.verticalCenter: parent.verticalCenter

            animate: true
            text: Icons.getAppCategoryIcon(Niri.focusedWindowClass, "desktop_windows")
            color: root.colour
        }

        Item {
            id: titleBox

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(text1.implicitWidth, text2.implicitWidth)
            height: Math.max(text1.implicitHeight, text2.implicitHeight)

            Title {
                id: text1
            }

            Title {
                id: text2
            }
        }

        StyledText {
            id: colIndicator

            anchors.verticalCenter: parent.verticalCenter

            visible: root.columnCount > 1
            text: `${root.focusedColumn}/${root.columnCount}`
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.labelSmall
            font.family: Appearance.font.family.mono
        }
    }

    TextMetrics {
        id: metrics

        text: Config.bar.activeWindow.compact ? root.getCompactName() : root.windowTitle
        font.pointSize: Appearance.font.size.bodySmall
        font.family: Appearance.font.family.mono
        elide: Qt.ElideRight
        elideWidth: Math.max(0, root.maxWidth - root.hPadding * 2 - icon.width - (colIndicator.visible ? colIndicator.implicitWidth + root.itemSpacing : 0) - root.itemSpacing * 2)

        onTextChanged: {
            const next = root.current === text1 ? text2 : text1;
            next.text = elidedText;
            root.current = next;
        }
        onElideWidthChanged: root.current.text = elidedText
    }

    Behavior on implicitWidth {
        Anim {
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }

    component Title: StyledText {
        id: text

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        font.pointSize: metrics.font.pointSize
        font.family: metrics.font.family
        color: root.colour
        opacity: root.current === this ? 1 : 0

        Behavior on opacity {
            Anim {}
        }
    }
}
