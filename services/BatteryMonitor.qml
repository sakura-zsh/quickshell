pragma Singleton

import qs.config
import qs.services
import Caelestia
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    readonly property list<var> warnLevels: [...Config.general.battery.warnLevels].sort((a, b) => b.level - a.level)

    Connections {
        target: UPower

        function onOnBatteryChanged(): void {
            if (UPower.onBattery) {
                if (Config.utilities.toasts.chargingChanged)
                    Toaster.toast(qsTr("已拔下充电器"), qsTr("电池正在放电"), "power_off");
            } else {
                if (Config.utilities.toasts.chargingChanged)
                    Toaster.toast(qsTr("已插入充电器"), qsTr("电池正在充电"), "power");
                for (const level of root.warnLevels)
                    level.warned = false;
            }
        }
    }

    Connections {
        target: UPower.displayDevice

        function onPercentageChanged(): void {
            if (!UPower.onBattery)
                return;

            const p = UPower.displayDevice.percentage * 100;
            for (const level of root.warnLevels) {
                if (p <= level.level && !level.warned) {
                    level.warned = true;
                    Toaster.toast(level.title ?? qsTr("电池警告"), level.message ?? qsTr("电池电量过低"), level.icon ?? "battery_android_alert", level.critical ? Toast.Error : Toast.Warning);
                }
            }

            if (!hibernateTimer.running && p <= Config.general.battery.criticalLevel) {
                Toaster.toast(qsTr("5 秒后休眠"), qsTr("即将休眠以防止数据丢失"), "battery_android_alert", Toast.Error);
                hibernateTimer.start();
            }
        }
    }

    Timer {
        id: hibernateTimer

        interval: 5000
        onTriggered: Quickshell.execDetached(["systemctl", "hibernate"])
    }
}
