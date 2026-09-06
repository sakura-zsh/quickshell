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

    title: qsTr("背景")
    showBackground: true

    ColumnLayout {
        spacing: Appearance.spacing.sm
        Layout.fillWidth: true

    SwitchRow {
        label: qsTr("背景已启用")
        checked: rootPane.backgroundEnabled
        onToggled: checked => {
            rootPane.backgroundEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("壁纸已启用")
        checked: rootPane.wallpaperEnabled
        onToggled: checked => {
            rootPane.wallpaperEnabled = checked;
            rootPane.saveConfig();
        }
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.lg
        text: qsTr("桌面时钟")
        font.pointSize: Appearance.font.size.bodyLarge
        font.weight: 500
    }

    SwitchRow {
        label: qsTr("桌面时钟已启用")
        checked: rootPane.desktopClockEnabled
        onToggled: checked => {
            rootPane.desktopClockEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        id: posContainer

        contentSpacing: Appearance.spacing.sm
        z: 1

        readonly property var pos: (rootPane.desktopClockPosition || "top-left").split('-')
        readonly property string currentV: pos[0]
        readonly property string currentH: pos[1]

        function updateClockPos(v, h) {
            rootPane.desktopClockPosition = v + "-" + h;
            rootPane.saveConfig();
        }

        StyledText {
            text: qsTr("定位")
            font.pointSize: Appearance.font.size.bodyLarge
            font.weight: 500
        }

        SplitButtonRow {
            label: qsTr("垂直位置")
            enabled: rootPane.desktopClockEnabled

            menuItems: [
                MenuItem {
                    text: qsTr("顶部")
                    icon: "vertical_align_top"
                    property string val: "top"
                },
                MenuItem {
                    text: qsTr("中间")
                    icon: "vertical_align_center"
                    property string val: "middle"
                },
                MenuItem {
                    text: qsTr("底部")
                    icon: "vertical_align_bottom"
                    property string val: "bottom"
                }
            ]

            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++) {
                    if (menuItems[i].val === posContainer.currentV)
                        active = menuItems[i];
                }
            }

            // The signal from SplitButtonRow
            onSelected: item => posContainer.updateClockPos(item.val, posContainer.currentH)
        }

        SplitButtonRow {
            label: qsTr("水平位置")
            enabled: rootPane.desktopClockEnabled
            expandedZ: 99

            menuItems: [
                MenuItem {
                    text: qsTr("左")
                    icon: "align_horizontal_left"
                    property string val: "left"
                },
                MenuItem {
                    text: qsTr("居中")
                    icon: "align_horizontal_center"
                    property string val: "center"
                },
                MenuItem {
                    text: qsTr("右")
                    icon: "align_horizontal_right"
                    property string val: "right"
                }
            ]

            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++) {
                    if (menuItems[i].val === posContainer.currentH)
                        active = menuItems[i];
                }
            }

            onSelected: item => posContainer.updateClockPos(posContainer.currentV, item.val)
        }
    }

    SwitchRow {
        label: qsTr("反转颜色")
        checked: rootPane.desktopClockInvertColors
        onToggled: checked => {
            rootPane.desktopClockInvertColors = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.sm

        StyledText {
            text: qsTr("阴影")
            font.pointSize: Appearance.font.size.bodyLarge
            font.weight: 500
        }

        SwitchRow {
            label: qsTr("已启用")
            checked: rootPane.desktopClockShadowEnabled
            onToggled: checked => {
                rootPane.desktopClockShadowEnabled = checked;
                rootPane.saveConfig();
            }
        }

        SectionContainer {
            contentSpacing: Appearance.spacing.lg

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("不透明度")
                value: rootPane.desktopClockShadowOpacity * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopClockShadowOpacity = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }

        SectionContainer {
            contentSpacing: Appearance.spacing.lg

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("模糊")
                value: rootPane.desktopClockShadowBlur * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopClockShadowBlur = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.sm

        StyledText {
            text: qsTr("背景")
            font.pointSize: Appearance.font.size.bodyLarge
            font.weight: 500
        }

        SwitchRow {
            label: qsTr("已启用")
            checked: rootPane.desktopClockBackgroundEnabled
            onToggled: checked => {
                rootPane.desktopClockBackgroundEnabled = checked;
                rootPane.saveConfig();
            }
        }

        SwitchRow {
            label: qsTr("模糊已启用")
            checked: rootPane.desktopClockBackgroundBlur
            onToggled: checked => {
                rootPane.desktopClockBackgroundBlur = checked;
                rootPane.saveConfig();
            }
        }

        SectionContainer {
            contentSpacing: Appearance.spacing.lg

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("不透明度")
                value: rootPane.desktopClockBackgroundOpacity * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopClockBackgroundOpacity = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.lg
        text: qsTr("可视化器")
        font.pointSize: Appearance.font.size.bodyLarge
        font.weight: 500
    }

    SwitchRow {
        label: qsTr("可视化器已启用")
        checked: rootPane.visualiserEnabled
        onToggled: checked => {
            rootPane.visualiserEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("可视化器自动隐藏")
        checked: rootPane.visualiserAutoHide
        onToggled: checked => {
            rootPane.visualiserAutoHide = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.lg

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("可视化器圆角")
            value: rootPane.visualiserRounding
            from: 0
            to: 10
            stepSize: 1
            validator: IntValidator {
                bottom: 0
                top: 10
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                rootPane.visualiserRounding = Math.round(newValue);
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.lg

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("可视化器间距")
            value: rootPane.visualiserSpacing
            from: 0
            to: 2
            validator: DoubleValidator {
                bottom: 0
                top: 2
            }

            onValueModified: newValue => {
                rootPane.visualiserSpacing = newValue;
                rootPane.saveConfig();
            }
        }
    }

    } // end ColumnLayout wrapper
}
