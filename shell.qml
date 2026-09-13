//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QML2_IMPORT_PATH=/home/sakura/.config/quickshell

import "modules"
import "components"
import "modules/drawers"
import "modules/areapicker"
import "modules/lock"
import "modules/quicktoggles"
import "modules/background"
import "modules/polkit"
import qs.modules.controlcenter
import qs.services

import Quickshell

ShellRoot {
    Backdrop {}
    Background {}
    Drawers {}
    AreaPicker {}
    Lock {}

    Shortcuts {}
    QuickTogglesPanel {}

    // Native polkit authentication agent — replaces polkit-kde-authentication-agent-1
    PolkitDialog {}

    ReloadPopup {}

    // Initialize BatteryMonitor service
    property var _batteryMonitor: BatteryMonitor

    // Keep DisplayService loaded so it can auto-enable the only output
    // after an external display is unplugged.
    property var _displayService: DisplayService
}

// hot-reload touch 2
// hot-reload touch 3
// hot-reload touch lyrics-overlay 1784783123
// touch 1784783194
// touch 1784783315
// lyrics-pos 1784783888
// lyrics-dock-right 1784783946
// fix-loop 1784783996
// lyrics-rewrite 1784784068
// lyrics-right-edge 1784784144



