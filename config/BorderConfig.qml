import Quickshell.Io

JsonObject {
    // Draw the screen frame — the strip behind the bar plus the left, right
    // and bottom edges. Turning it off leaves the bar modules as free-standing
    // islands over the wallpaper instead (see modules/bar/Bar.qml).
    property bool enabled: true
    property int thickness: Appearance.padding.xs
    property int rounding: Appearance.rounding.large
    // Frame colour override. Empty means "follow the theme": the frame, the bar
    // strip and every panel fused into the frame use the palette's surface
    // colour. Set it to any "#rrggbb" to paint the frame separately — the bar
    // islands use the same colour when the frame is disabled.
    property string colour: ""
}
