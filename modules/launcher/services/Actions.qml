pragma Singleton

import qs.modules.launcher
import qs.modules.controlcenter
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

Searcher {
    id: root

    readonly property list<QtObject> actions: [
        Action {
            name: qsTr("设置")
            desc: qsTr("打开配置编辑器")
            icon: "settings"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                WindowFactory.create();
            }
        },
        Action {
            name: qsTr("计算器")
            desc: qsTr("进行简单数学运算（由 Qalc 驱动）")
            icon: "calculate"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "calc");
            }
        },
        Action {
            name: qsTr("方案")
            desc: qsTr("更改当前配色方案")
            icon: "palette"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "scheme");
            }
        },
        Action {
            name: qsTr("壁纸")
            desc: qsTr("更改当前壁纸")
            icon: "image"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "wallpaper");
            }
        },
        Action {
            name: qsTr("变体")
            desc: qsTr("更改当前方案变体")
            icon: "colors"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "variant");
            }
        },
        Action {
            name: qsTr("剪贴板")
            desc: qsTr("搜索剪贴板历史")
            icon: "content_paste"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "clip");
            }
        },
        Action {
            name: qsTr("网页搜索")
            desc: qsTr("搜索网络或打开网址")
            icon: "travel_explore"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "web");
            }
        },
        Action {
            name: qsTr("表情符号")
            desc: qsTr("搜索并复制表情符号")
            icon: "mood"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "emoji");
            }
        },
        Action {
            name: qsTr("OCR")
            desc: qsTr("从屏幕区域提取文本")
            icon: "document_scanner"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                const configName = Quickshell.shellDir.toString().replace(/\/$/, "").split("/").pop();
                Quickshell.execDetached(["qs", "-c", configName, "ipc", "call", "picker", "regionOcr"]);
            }
        },
        Action {
            name: qsTr("Google Lens")
            desc: qsTr("使用 Google Lens 搜索屏幕区域")
            icon: "image_search"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                const configName = Quickshell.shellDir.toString().replace(/\/$/, "").split("/").pop();
                Quickshell.execDetached(["qs", "-c", configName, "ipc", "call", "picker", "regionSearch"]);
            }
        },
        Action {
            name: qsTr("透明度")
            desc: qsTr("更改桌面壳透明度")
            icon: "opacity"
            disabled: true

            function onClicked(list: AppList): void {
                root.autocomplete(list, "transparency");
            }
        },
        Action {
            name: qsTr("随机")
            desc: qsTr("切换到随机壁纸")
            icon: "casino"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                // Get a random wallpaper from the Wallpapers service
                const wallpaperList = Wallpapers.list;
                if (wallpaperList && wallpaperList.length > 0) {
                    const randomIndex = Math.floor(Math.random() * wallpaperList.length);
                    const randomWallpaper = wallpaperList[randomIndex];
                    if (randomWallpaper && randomWallpaper.path) {
                        Wallpapers.setWallpaper(randomWallpaper.path);
                    }
                }
            }
        },
        Action {
            name: qsTr("浅色")
            desc: qsTr("将配色方案切换为浅色模式")
            icon: "light_mode"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                Colours.setMode("light");
                Schemes.regenerateDynamic();
            }
        },
        Action {
            name: qsTr("深色")
            desc: qsTr("将配色方案切换为深色模式")
            icon: "dark_mode"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                Colours.setMode("dark");
                Schemes.regenerateDynamic();
            }
        },
        Action {
            name: qsTr("关机")
            desc: qsTr("关闭系统")
            icon: "power_settings_new"
            disabled: !Config.launcher.enableDangerousActions

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                Quickshell.execDetached(["systemctl", "poweroff"]);
            }
        },
        Action {
            name: qsTr("重启")
            desc: qsTr("重启系统")
            icon: "cached"
            disabled: !Config.launcher.enableDangerousActions

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                Quickshell.execDetached(["systemctl", "reboot"]);
            }
        },
        Action {
            name: qsTr("注销")
            desc: qsTr("注销当前会话")
            icon: "exit_to_app"
            disabled: !Config.launcher.enableDangerousActions

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                Quickshell.execDetached(["niri", "msg", "action", "quit", "-s"]);
            }
        },
        Action {
            name: qsTr("锁定")
            desc: qsTr("锁定当前会话")
            icon: "lock"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                const configName = Quickshell.shellDir.toString().replace(/\/$/, "").split("/").pop();
                Quickshell.execDetached(["qs", "-c", configName, "ipc", "call", "lock", "lock"]);
            }
        }
    ]

    function transformSearch(search: string): string {
        return search.slice(Config.launcher.actionPrefix.length);
    }

    function autocomplete(list: AppList, text: string): void {
        list.search.text = `${Config.launcher.actionPrefix}${text} `;
    }

    list: actions.filter(a => !a.disabled)
    useFuzzy: Config.launcher.useFuzzy.actions

    component Action: QtObject {
        required property string name
        required property string desc
        required property string icon
        property bool disabled

        function onClicked(list: AppList): void {
        }
    }
}
