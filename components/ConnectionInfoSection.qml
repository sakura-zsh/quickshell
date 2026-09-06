import qs.components
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var deviceDetails

    spacing: Appearance.spacing.sm / 2

    StyledText {
        text: qsTr("IP 地址")
    }

    StyledText {
        text: root.deviceDetails?.ipAddress || qsTr("不可用")
        color: Colours.palette.m3outline
        font.pointSize: Appearance.font.size.labelLarge
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.lg
        text: qsTr("子网掩码")
    }

    StyledText {
        text: root.deviceDetails?.subnet || qsTr("不可用")
        color: Colours.palette.m3outline
        font.pointSize: Appearance.font.size.labelLarge
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.lg
        text: qsTr("网关")
    }

    StyledText {
        text: root.deviceDetails?.gateway || qsTr("不可用")
        color: Colours.palette.m3outline
        font.pointSize: Appearance.font.size.labelLarge
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.lg
        text: qsTr("DNS 服务器")
    }

    StyledText {
        text: (root.deviceDetails && root.deviceDetails.dns && root.deviceDetails.dns.length > 0) ? root.deviceDetails.dns.join(", ") : qsTr("不可用")
        color: Colours.palette.m3outline
        font.pointSize: Appearance.font.size.labelLarge
        wrapMode: Text.Wrap
        Layout.maximumWidth: parent.width
    }
}
