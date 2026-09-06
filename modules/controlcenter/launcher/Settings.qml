pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property Session session

    spacing: Appearance.spacing.lg

    SettingsHeader {
        icon: "apps"
        title: qsTr("启动器设置")
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.xxl
        title: qsTr("通用")
        description: qsTr("常规启动器设置")
    }

    SectionContainer {
        ToggleRow {
            label: qsTr("已启用")
            checked: Config.launcher.enabled
            toggle.onToggled: {
                Config.launcher.enabled = checked;
                Config.markDirty("launcher");
            }
        }

        ToggleRow {
            label: qsTr("悬停时显示")
            checked: Config.launcher.showOnHover
            toggle.onToggled: {
                Config.launcher.showOnHover = checked;
                Config.markDirty("launcher");
            }
        }

        ToggleRow {
            label: qsTr("Vim 键位")
            checked: Config.launcher.vimKeybinds
            toggle.onToggled: {
                Config.launcher.vimKeybinds = checked;
                Config.markDirty("launcher");
            }
        }

        ToggleRow {
            label: qsTr("启用危险操作")
            checked: Config.launcher.enableDangerousActions
            toggle.onToggled: {
                Config.launcher.enableDangerousActions = checked;
                Config.markDirty("launcher");
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.xxl
        title: qsTr("显示")
        description: qsTr("显示和外观设置")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.sm / 2

        PropertyRow {
            label: qsTr("最大显示项目数")
            value: qsTr("%1").arg(Config.launcher.maxShown)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("最大壁纸数")
            value: qsTr("%1").arg(Config.launcher.maxWallpapers)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("拖动阈值")
            value: qsTr("%1 px").arg(Config.launcher.dragThreshold)
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.xxl
        title: qsTr("前缀")
        description: qsTr("命令前缀设置")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.sm / 2

        PropertyRow {
            label: qsTr("特殊前缀")
            value: Config.launcher.specialPrefix || qsTr("无")
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("操作前缀")
            value: Config.launcher.actionPrefix || qsTr("无")
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.xxl
        title: qsTr("模糊搜索")
        description: qsTr("模糊搜索设置")
    }

    SectionContainer {
        ToggleRow {
            label: qsTr("应用")
            checked: Config.launcher.useFuzzy.apps
            toggle.onToggled: {
                Config.launcher.useFuzzy.apps = checked;
                Config.markDirty("launcher");
            }
        }

        ToggleRow {
            label: qsTr("操作")
            checked: Config.launcher.useFuzzy.actions
            toggle.onToggled: {
                Config.launcher.useFuzzy.actions = checked;
                Config.markDirty("launcher");
            }
        }

        ToggleRow {
            label: qsTr("方案")
            checked: Config.launcher.useFuzzy.schemes
            toggle.onToggled: {
                Config.launcher.useFuzzy.schemes = checked;
                Config.markDirty("launcher");
            }
        }

        ToggleRow {
            label: qsTr("变体")
            checked: Config.launcher.useFuzzy.variants
            toggle.onToggled: {
                Config.launcher.useFuzzy.variants = checked;
                Config.markDirty("launcher");
            }
        }

        ToggleRow {
            label: qsTr("壁纸")
            checked: Config.launcher.useFuzzy.wallpapers
            toggle.onToggled: {
                Config.launcher.useFuzzy.wallpapers = checked;
                Config.markDirty("launcher");
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.xxl
        title: qsTr("尺寸")
        description: qsTr("启动器项目的尺寸设置")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.sm / 2

        PropertyRow {
            label: qsTr("项目宽度")
            value: qsTr("%1 px").arg(Config.launcher.sizes.itemWidth)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("项目高度")
            value: qsTr("%1 px").arg(Config.launcher.sizes.itemHeight)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("壁纸宽度")
            value: qsTr("%1 px").arg(Config.launcher.sizes.wallpaperWidth)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("壁纸高度")
            value: qsTr("%1 px").arg(Config.launcher.sizes.wallpaperHeight)
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.xxl
        title: qsTr("隐藏的应用")
        description: qsTr("已从启动器隐藏的应用")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.sm / 2

        PropertyRow {
            label: qsTr("隐藏总数")
            value: qsTr("%1").arg(Config.launcher.hiddenApps ? Config.launcher.hiddenApps.length : 0)
        }
    }
}
