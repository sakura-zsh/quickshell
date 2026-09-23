pragma ComponentBehavior: Bound

import qs.services
import qs.config
import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import Quickshell
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts
    readonly property int hPadding: Appearance.padding.xl

    // Handle Workspace Popouts for Niri

    Connections {
        target: root.popouts
        function onHasCurrentChanged() {
            if (!root.popouts.hasCurrent && root.popouts.currentName === "wsWindow") {
                Niri.wsContextAnchor = null;
            }
        }
    }

    // Handle Popouts Hover

    function checkPopout(x: real): void {
        if (Niri.wsContextType === "workspaces") {
            // Workspace context menu
            const anchor = Niri.wsContextAnchor;
            if (!anchor) {
                popouts.hasCurrent = false;
                return;
            }
            popouts.currentCenter = Qt.binding(() => Math.round(anchor.mapToItem(root, anchor.width / 2, 0).x));
            return;
        }

        const ch = childAt(x, height / 2) as WrappedLoader;
        if (!ch?.item) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.id;
        const left = ch.x;
        const item = ch.item;
        const itemWidth = item.implicitWidth;

        if (id === "statusIcons") {
            const items = item.items;
            const icon = items.childAt(mapToItem(items, x, 0).x, items.height / 2);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, icon.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray") {
            const index = Math.floor(((x - left) / itemWidth) * item.items.count);
            const trayItem = item.items.itemAt(index);
            if (trayItem) {
                popouts.currentName = `traymenu${index}`;
                popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, trayItem.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            }
        }
    }

    function handleWheel(x: real, angleDelta: point): void {
        const ch = childAt(x, height / 2) as WrappedLoader;
        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            Niri.switchToWorkspaceUpDown(angleDelta.y > 0 ? "up" : "down");
        } else if (Config.bar.scrollActions.volume) {
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        }
    }

    spacing: Appearance.spacing.lg

    // ── Centred module pinning ──────────────────────────────────────────────
    // The module sitting between the two spacers (normally the clock) used to be
    // laid out by the row itself, which put it at the centre of the *free* space
    // — so its position drifted as the modules left and right of it changed
    // width (extra workspaces, a longer window title, more status icons...).
    //
    // It is now pinned to the bar's own centre instead: the slot keeps a zero
    // layout footprint, and the module itself is drawn as an overlay whose x is
    // computed from the bar width only. Nothing that happens elsewhere on the
    // bar can move it. Config.bar.clock.offset is applied here as a plain px
    // nudge (positive = right).
    readonly property var spacerIndices: {
        const out = [];
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i);
            if (it && it.enabled && it.id === "spacer")
                out.push(i);
        }
        return out;
    }

    function isCentredModule(index: int): bool {
        const idx = root.spacerIndices;
        return idx.length === 2 && index > idx[0] && index < idx[1];
    }

    Repeater {
        id: repeater

        model: Config.bar.entries

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: WrappedLoader {
                    Layout.fillWidth: enabled
                }
            }
            DelegateChoice {
                roleValue: "divider"
                delegate: WrappedLoader {
                    sourceComponent: Rectangle {
                        implicitWidth: 1
                        implicitHeight: Appearance.padding.md
                        color: Colours.palette.m3outlineVariant
                    }
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: WrappedLoader {
                    sourceComponent: OsIcon {
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    Niri.wsContextType = "workspaces";
                                    root.popouts.currentName = "wsWindow";
                                    root.popouts.hasCurrent = true;
                                }
                            }
                        }
                    }
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: WrappedLoader {
                    sourceComponent: Workspaces {

                        property var anchorItem: Niri.wsContextAnchor && Niri.wsContextType !== "none" ? Niri.wsContextAnchor : null

                        onRequestWindowPopout: {
                            if (anchorItem && Config.bar.workspaces.windowRighClickContext) {
                                root.popouts.currentName = "wsWindow";
                                root.popouts.currentCenter = Qt.binding(() => Math.round(anchorItem.mapToItem(null, anchorItem.width / 2, 0).x));
                                root.popouts.hasCurrent = true;
                            }
                        }
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: WrappedLoader {
                    sourceComponent: ActiveWindow {
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: WrappedLoader {
                    sourceComponent: Tray {}
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: WrappedLoader {
                    id: clockSlot

                    readonly property bool pinned: root.isCentredModule(index)

                    // When pinned the slot itself takes no width in the row, and
                    // the row still reserves the bar's pill height so the bar
                    // height is unchanged.
                    Layout.preferredWidth: clockSlot.pinned ? 0 : implicitWidth
                    Layout.preferredHeight: Config.bar.sizes.innerWidth

                    // The Clock sits inside a wrapper Item: the slot is zero-wide
                    // when pinned, so the wrapper is too, but a child keeps its
                    // own size (a Loader resizes only its direct item, never that
                    // item's children). Without this the pill would collapse to
                    // zero width.
                    sourceComponent: Item {
                        implicitWidth: clockPill.implicitWidth
                        implicitHeight: clockPill.implicitHeight

                        Clock {
                            id: clockPill

                            // Pinned to the bar centre: depends on the bar width
                            // only, so nothing to the left or right can move it.
                            x: clockSlot.pinned ? (root.width / 2 + Config.bar.clock.offset - clockSlot.x - width / 2) : 0
                        }
                    }
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: WrappedLoader {
                    sourceComponent: StatusIcons {}
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: WrappedLoader {
                    sourceComponent: Power {
                        visibilities: root.visibilities
                    }
                }
            }
            // DelegateChoice {
            //     roleValue: "idleInhibitor"
            //     delegate: WrappedLoader {
            //         sourceComponent: IdleInhibitor {}
            //     }
            // }
        }
    }

    // Cached first/last enabled items — recomputed once when repeater changes
    property Item firstEnabled: null
    property Item lastEnabled: null

    function updateEnabledCache(): void {
        let first = null;
        let last = null;
        const count = repeater.count;
        for (let i = 0; i < count; i++) {
            const item = repeater.itemAt(i);
            if (item?.enabled) {
                if (!first) first = item;
                last = item;
            }
        }
        firstEnabled = first;
        lastEnabled = last;
    }

    Connections {
        target: repeater
        function onCountChanged() { root.updateEnabledCache(); }
    }

    Component.onCompleted: updateEnabledCache()

    component WrappedLoader: Loader {
        required property string id
        required property int index

        onEnabledChanged: root.updateEnabledCache()

        Layout.alignment: Qt.AlignVCenter

        Layout.leftMargin: root.firstEnabled === this ? root.hPadding : 0
        Layout.rightMargin: root.lastEnabled === this ? root.hPadding : 0

        asynchronous: true
        visible: enabled
        active: enabled
    }
}
