import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

SectionContainer {
    id: root

    required property var rootItem

    Layout.fillWidth: true
    alignTop: true

    StyledText {
        text: qsTr("常规设置")
        font.pointSize: Appearance.font.size.bodyMedium
    }

    SwitchRow {
        label: qsTr("已启用")
        checked: root.rootItem.enabled
        onToggled: checked => {
            root.rootItem.enabled = checked;
            root.rootItem.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("悬停时显示")
        checked: root.rootItem.showOnHover
        onToggled: checked => {
            root.rootItem.showOnHover = checked;
            root.rootItem.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("将壁纸用作头像")
        checked: root.rootItem.useWallpaperAvatar
        onToggled: checked => {
            root.rootItem.useWallpaperAvatar = checked;
            root.rootItem.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.lg

        SliderInput {
            Layout.fillWidth: true
            
            label: qsTr("更新间隔")
            value: root.rootItem.updateInterval
            from: 100
            to: 10000
            stepSize: 100
            suffix: "ms"
            validator: IntValidator { bottom: 100; top: 10000 }
            formatValueFunction: (val) => Math.round(val).toString()
            parseValueFunction: (text) => parseInt(text)
            
            onValueModified: (newValue) => {
                root.rootItem.updateInterval = Math.round(newValue);
                root.rootItem.saveConfig();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            
            label: qsTr("拖动阈值")
            value: root.rootItem.dragThreshold
            from: 0
            to: 100
            suffix: "px"
            validator: IntValidator { bottom: 0; top: 100 }
            formatValueFunction: (val) => Math.round(val).toString()
            parseValueFunction: (text) => parseInt(text)
            
            onValueModified: (newValue) => {
                root.rootItem.dragThreshold = Math.round(newValue);
                root.rootItem.saveConfig();
            }
        }
    }
}
