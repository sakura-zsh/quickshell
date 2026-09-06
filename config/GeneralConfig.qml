import Quickshell.Io

JsonObject {
    property bool isDistLogo: false
    property Apps apps: Apps {}
    property Battery battery: Battery {}

    component Apps: JsonObject {
        property list<string> terminal: ["foot"]
        property list<string> audio: ["pavucontrol"]
        property list<string> playback: ["mpv"]
        property list<string> explorer: ["thunar"]
    }

    component Battery: JsonObject {
        property list<var> warnLevels: [
            {
                level: 30,
                title: "电量不足",
                message: "你可能需要插入充电器",
                icon: "battery_2_bar"
            },
            {
                level: 20,
                title: "你看到上一条消息了吗？",
                message: "你现在应该<b>立即</b>插上充电器",
                icon: "battery_1_bar"
            },
            {
                level: 10,
                title: "电池电量严重不足",
                message: "立刻插入充电器！！",
                icon: "battery_alert",
                critical: true
            }
        ]
        property int criticalLevel: 3 // Battery level to trigger critical action (e.g., suspend)
        property bool enableWarnings: true
    }
}
