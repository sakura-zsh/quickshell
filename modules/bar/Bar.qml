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

    // ── Centring compensation ───────────────────────────────────────────────
    // With two fill-width spacers the module between them sits at the centre of
    // the *free* space, which drifts off the screen centre as soon as the left
    // and right groups differ in width. Feed that difference into the spacer on
    // the narrower side so the centred module lands on the true centre.
    //
    // Index arithmetic only (no object identity, no object arrays): the summed
    // ranges are derived from the spacer *indices*, so a spacer's own width can
    // never leak into the sums (that would create a feedback loop).
    readonly property var spacerIndices: {
        const out = [];
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i);
            if (it && it.enabled && it.id === "spacer")
                out.push(i);
        }
        return out;
    }

    readonly property real leftSideWidth: root.sideWidth(true)
    readonly property real rightSideWidth: root.sideWidth(false)

    function sideWidth(left: bool): real {
        const idx = root.spacerIndices;
        if (idx.length !== 2)
            return 0;

        const from = left ? 0 : idx[1] + 1;
        const to = left ? idx[0] : repeater.count;

        let sum = 0;
        for (let i = from; i < to; i++) {
            const it = repeater.itemAt(i);
            if (it && it.enabled)
                sum += it.width + root.spacing;
        }
        return sum;
    }

    function spacerPreferredWidth(index: int): real {
        const idx = root.spacerIndices;
        if (idx.length !== 2)
            return 0;
        if (index !== idx[0] && index !== idx[1])
            return 0;

        const l = root.leftSideWidth;
        const r = root.rightSideWidth;
        const wanted = index === idx[0] ? Math.max(0, r - l) : Math.max(0, l - r);

        // Safety clamp: never hand a spacer more than a quarter of the bar
        // (an unbounded value would wreck the whole layout).
        return Math.min(wanted, root.width * 0.25);
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
                    Layout.preferredWidth: root.spacerPreferredWidth(index)
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
                    sourceComponent: Clock {}
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
