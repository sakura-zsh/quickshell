import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Lock status display - uses Niri service for reactive state
ColumnLayout {
    id: root

    spacing: Appearance.spacing.sm

    StyledText {
        text: qsTr("大写锁定：%1").arg(Niri.capsLock ? "已开启" : "已关闭")
    }

    StyledText {
        text: qsTr("数字锁定：%1").arg(Niri.numLock ? "已开启" : "已关闭")
    }
}
