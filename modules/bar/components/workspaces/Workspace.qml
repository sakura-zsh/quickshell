pragma ComponentBehavior: Bound

import qs.components
// import qs.components.effects
import qs.config
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property int index
    required property var occupied
    required property int groupOffset
    required property int focusedWindowId
    required property int activeWsId

    required property Item windowPopoutSignal

    readonly property bool isWorkspace: true // Flag for finding workspace children
    readonly property int size: isWorkspace ? implicitWidth + (hasWindows ? Appearance.padding.xs : 0) : 0
    readonly property int ws: groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows

    // To make the windows repopulate, for Niri.
    // onGroupOffsetChanged: {
    //     windows.active = false;
    //     windows.active = true;
    // }

    // clip: true

    Behavior on scale {
        Anim {}
    }

    Behavior on Layout.preferredWidth {
        Anim {}
    }

    Layout.alignment: Qt.AlignTop
    Layout.preferredWidth: size

    spacing: 0

    WorkspaceIcon {
        workspace: root
    }

    Loader {
        id: windows
        objectName: "windowsLoader"

        Layout.alignment: Qt.AlignCenter
        // Layout.fillWidth: true
        Layout.leftMargin: -Config.bar.sizes.innerWidth / 10

        visible: active
        active: root.hasWindows
        asynchronous: true

        sourceComponent: DraggableWindowColumn {
            id: dragDropLayout
            spacing: 0

            workspace: root
            focusedWindowId: root.focusedWindowId
            activeWsId: root.activeWsId
            ws: root.ws
            windowPopoutSignal: root.windowPopoutSignal
            idx: root.index
            groupOffset: root.groupOffset
        }
    }
}
