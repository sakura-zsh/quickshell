pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

CollapsibleSection {
    id: root

    required property var rootPane

    title: qsTr("边框")
    description: qsTr("包裹四周的边框，包括任务栏下方的底色。关闭后左右与下方不再有边框覆盖壁纸，任务栏变成一个个独立的功能区，功能区之间的间隔保持不变，其余位置直接显示壁纸。")
    showBackground: true

    // Preset frame colours. "" follows the theme's surface colour, which is
    // what the frame has always used; the rest are plain palette picks.
    readonly property var swatches: [
        {
            colour: "",
            label: qsTr("跟随主题")
        },
        {
            colour: Colours.palette.m3surface,
            label: qsTr("表面")
        },
        {
            colour: Colours.palette.m3surfaceContainerHighest,
            label: qsTr("表面容器")
        },
        {
            colour: Colours.palette.m3primaryContainer,
            label: qsTr("主色容器")
        },
        {
            colour: Colours.palette.m3secondaryContainer,
            label: qsTr("次色容器")
        },
        {
            colour: Colours.palette.m3tertiaryContainer,
            label: qsTr("第三色容器")
        },
        {
            colour: "#000000",
            label: qsTr("黑")
        },
        {
            colour: "#ffffff",
            label: qsTr("白")
        }
    ]

    // QML hands colour channels back as 0..1 floats, so build the "#rrggbb"
    // form by hand — it is the form that ends up in the config file.
    function hexOf(c: color): string {
        const h = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
        return `#${h(c.r)}${h(c.g)}${h(c.b)}`;
    }

    function isColourHex(s: string): bool {
        return /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(String(s ?? "").trim());
    }

    function normaliseHex(s: string): string {
        let v = String(s ?? "").trim().toLowerCase();
        if (v.startsWith("#"))
            v = v.slice(1);
        if (v.length === 3)
            v = v[0] + v[0] + v[1] + v[1] + v[2] + v[2];
        return `#${v}`;
    }

    function applyColour(value: string): void {
        rootPane.borderColour = value;
        rootPane.saveConfig();
    }

    function isSelected(colour: color): bool {
        if (rootPane.borderColour === "")
            return false;
        return Qt.colorEqual(colour, rootPane.borderColour);
    }

    ColumnLayout {
        spacing: Appearance.spacing.sm
        Layout.fillWidth: true

    // ── Frame on / off ──────────────────────────────────────────────────────
    SwitchRow {
        label: qsTr("启用四周边框")
        checked: rootPane.borderEnabled
        onToggled: checked => {
            rootPane.borderEnabled = checked;
            rootPane.saveConfig();
        }
    }

    // ── Frame colour ────────────────────────────────────────────────────────
    SectionContainer {
        contentSpacing: Appearance.spacing.md

        StyledText {
            Layout.fillWidth: true
            text: qsTr("边框颜色")
            font.pointSize: Appearance.font.size.bodyMedium
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("同时作用于边框、任务栏底色与各面板背景。留空（跟随主题）时使用主题的表面色。")
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.labelLarge
            wrapMode: Text.WordWrap
        }

        Flow {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            Repeater {
                model: root.swatches

                delegate: StyledRect {
                    id: swatch

                    required property var modelData

                    readonly property bool selected: modelData.colour === "" ? rootPane.borderColour === "" : root.isSelected(modelData.colour)

                    implicitWidth: 32
                    implicitHeight: 32
                    radius: Appearance.rounding.full
                    color: modelData.colour === "" ? Colours.palette.m3surface : modelData.colour
                    border.width: selected ? 2 : 1
                    border.color: selected ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.4)

                    StateLayer {
                        function onClicked(): void {
                            root.applyColour(swatch.modelData.colour === "" ? "" : root.hexOf(swatch.modelData.colour));
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: swatch.selected
                        text: "check"
                        color: Colours.on(swatch.color)
                        font.pointSize: Appearance.font.size.bodyMedium
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            StyledRect {
                implicitWidth: 20
                implicitHeight: 20
                radius: Appearance.rounding.full
                color: Colours.shellSurface
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outline, 0.5)
            }

            StyledText {
                Layout.fillWidth: true
                text: rootPane.borderColour === "" ? qsTr("跟随主题") : rootPane.borderColour
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.labelLarge
                elide: Text.ElideRight
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Appearance.rounding.small
            color: colourField.activeFocus ? Colours.layer(Colours.palette.m3surfaceContainer, 3) : Colours.layer(Colours.palette.m3surfaceContainer, 2)
            border.width: 1
            border.color: colourField.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.3)

            Behavior on color {
                CAnim {}
            }
            Behavior on border.color {
                CAnim {}
            }

            StyledTextField {
                id: colourField

                anchors.centerIn: parent
                width: parent.width - Appearance.padding.md
                horizontalAlignment: TextInput.AlignLeft
                placeholderText: qsTr("自定义十六进制颜色（如 #1e1e2e），回车确认")
                onAccepted: {
                    const value = text.trim();
                    if (root.isColourHex(value))
                        root.applyColour(root.normaliseHex(value));
                    text = "";
                }
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.lg

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("边框圆角")
            value: rootPane.borderRounding
            from: 0.1
            to: 100
            decimals: 1
            suffix: "px"
            validator: DoubleValidator {
                bottom: 0.1
                top: 100
            }

            onValueModified: newValue => {
                rootPane.borderRounding = newValue;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.lg

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("边框粗细")
            value: rootPane.borderThickness
            from: 0.1
            to: 100
            decimals: 1
            suffix: "px"
            validator: DoubleValidator {
                bottom: 0.1
                top: 100
            }

            onValueModified: newValue => {
                rootPane.borderThickness = newValue;
                rootPane.saveConfig();
            }
        }
    }

    } // end ColumnLayout wrapper
}
