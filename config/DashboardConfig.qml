import Quickshell.Io

JsonObject {
    property bool enabled: true
    property bool showOnHover: true
    property bool useWallpaperAvatar: true
    property int mediaUpdateInterval: 500
    property int resourceUpdateInterval: 1000
    property int dragThreshold: 50
    // Height (px) of the summon strip along the very top screen edge used to
    // open the dashboard on hover. Unused while topEdgeTrigger is false.
    property int hoverTriggerHeight: 12
    // Whether that top-edge strip summons/opens the dashboard at all. Off by
    // default: the dashboard is opened with the Win (Super) key instead, which
    // avoids accidental triggers and the pointer-hover conflicts with the bar's
    // interactive modules.
    property bool topEdgeTrigger: false
    property int updateInterval: 1000
    property Sizes sizes: Sizes {}
    property Performance performance: Performance {}

    component Performance: JsonObject {
        property bool showBattery: true
        property bool showGpu: true
        property bool showCpu: true
        property bool showMemory: true
        property bool showStorage: true
        property bool showNetwork: true
    }

    component Sizes: JsonObject {
        readonly property int tabIndicatorHeight: 3
        readonly property int tabIndicatorSpacing: 5
        readonly property int infoWidth: 200
        readonly property int infoIconSize: 25
        readonly property int dateTimeWidth: 110
        readonly property int mediaWidth: 200
        readonly property int mediaProgressSweep: 180
        readonly property int mediaProgressThickness: 8
        readonly property int resourceProgessThickness: 10
        readonly property int weatherWidth: 250
        readonly property int mediaCoverArtSize: 150
        readonly property int mediaVisualiserSize: 80
        readonly property int resourceSize: 200
    }
}
