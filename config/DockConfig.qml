import Quickshell.Io

JsonObject {
    property bool enabled: true
    property bool showOnHover: false
    property string position: "center" // "left" | "center" | "right"
    property int bottomMargin: 10
    property bool showTooltip: true
    property bool showSeparator: true
    property bool showDynamicApps: true
    property int settleDuration: 160
    property Sizes sizes: Sizes {}
    property Media media: Media {}
    property Visualiser visualiser: Visualiser {}

    // Pinned launcher apps. "enabled" can be toggled from the settings panel.
    property list<var> pinnedApps: [
        {
            id: "obsidian",
            exec: "obsidian",
            icon: "obsidian",
            match: ["obsidian"],
            enabled: true
        },
        {
            id: "code",
            exec: "code",
            icon: "vscode",
            match: ["code", "Code", "code-url-handler"],
            enabled: true
        },
        {
            id: "cider",
            exec: "cider",
            icon: "cider",
            match: ["cider", "Cider"],
            enabled: true
        },
        {
            id: "flclash",
            exec: "flclash",
            icon: "flclash",
            match: ["flclash", "FlClash", "com.follow.clash"],
            enabled: true
        },
        {
            id: "com.obsproject.Studio",
            exec: "obs",
            icon: "com.obsproject.Studio",
            match: ["com.obsproject.Studio", "obs"],
            enabled: true
        },
        {
            id: "ChatGPT",
            exec: "chatgpt-desktop",
            icon: "chatgpt-desktop",
            match: ["chatgpt", "ChatGPT", "chatgpt-desktop"],
            enabled: true
        }
    ]

    component Sizes: JsonObject {
        property int iconSize: 48
        property int iconGap: 14
        property int hPad: 16
        property int vPad: 10
        property int indicatorGap: 6
    }

    component Media: JsonObject {
        property bool enabled: true
        property bool autoHide: true
        property bool compact: false
        property bool showControls: true
        property bool showSecondary: true
        property int width: 420
        property int bottomMargin: 10
        property int rightMargin: 12
    }

    component Visualiser: JsonObject {
        property bool enabled: true
        property bool autoHide: true
        property int barWidth: 4
        property int barGap: 4
        property int barHeight: 48
        property int minBarCount: 14
        property int maxBarCount: 96
        property int width: 0 // 0 = auto (screenWidth / autoWidthDivisor)
        property real autoWidthDivisor: 5.5
        property int leftMargin: 10
        property int bottomMargin: 10
        property int animDuration: 90
    }
}
