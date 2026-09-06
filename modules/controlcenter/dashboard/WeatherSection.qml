import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

SectionContainer {
    id: root

    required property var rootItem

    Layout.fillWidth: true
    alignTop: true

    StyledText {
        text: qsTr("天气")
        font.pointSize: Appearance.font.size.bodyMedium
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.md / 2

        StyledText {
            text: qsTr("位置（城市名、州或经纬度）")
            font.pointSize: Appearance.font.size.labelLarge
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 40
            color: locationField.activeFocus ? Colours.layer(Colours.palette.m3surfaceContainer, 3) : Colours.layer(Colours.palette.m3surfaceContainer, 2)
            radius: Appearance.rounding.small
            border.width: 1
            border.color: locationField.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.3)

            Behavior on color {
                CAnim {}
            }
            Behavior on border.color {
                CAnim {}
            }

            StyledTextField {
                id: locationField
                anchors.centerIn: parent
                width: parent.width - Appearance.padding.md
                horizontalAlignment: TextInput.AlignLeft
                placeholderText: qsTr("按 IP 自动检测")
                text: root.rootItem.weatherLocation
                onEditingFinished: {
                    root.rootItem.weatherLocation = text;
                    root.rootItem.saveConfig();
                }
            }
        }
    }

    SwitchRow {
        label: qsTr("使用华氏度")
        checked: root.rootItem.useFahrenheit
        onToggled: checked => {
            root.rootItem.useFahrenheit = checked;
            root.rootItem.saveConfig();
        }
    }
}
