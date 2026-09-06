pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

CollapsibleSection {
    id: root

    required property var rootPane

    title: qsTr("透明度")
    showBackground: true

    ColumnLayout {
        spacing: Appearance.spacing.sm
        Layout.fillWidth: true

    SwitchRow {
        label: qsTr("透明度已启用")
        checked: rootPane.transparencyEnabled
        onToggled: checked => {
            rootPane.transparencyEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("降低透明度")
        checked: rootPane.reduceTransparency
        onToggled: checked => {
            rootPane.reduceTransparency = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.lg

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("透明度基准")
            value: rootPane.transparencyBase * 100
            from: 0
            to: 100
            suffix: "%"
            validator: IntValidator {
                bottom: 0
                top: 100
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                rootPane.transparencyBase = newValue / 100;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.lg

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("透明图层")
            value: rootPane.transparencyLayers * 100
            from: 0
            to: 100
            suffix: "%"
            validator: IntValidator {
                bottom: 0
                top: 100
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                rootPane.transparencyLayers = newValue / 100;
                rootPane.saveConfig();
            }
        }
    }

    } // end ColumnLayout wrapper
}
