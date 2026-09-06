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

    title: qsTr("边框")
    showBackground: true

    ColumnLayout {
        spacing: Appearance.spacing.sm
        Layout.fillWidth: true

    SectionContainer {
        contentSpacing: Appearance.spacing.lg

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("边框圆角")
            value: rootPane.borderRounding
            from: 0.1
            to: 100
            decimals: 1
            suffix: "px"
            validator: DoubleValidator {
                bottom: 0.1
                top: 100
            }

            onValueModified: newValue => {
                rootPane.borderRounding = newValue;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.lg

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("边框粗细")
            value: rootPane.borderThickness
            from: 0.1
            to: 100
            decimals: 1
            suffix: "px"
            validator: DoubleValidator {
                bottom: 0.1
                top: 100
            }

            onValueModified: newValue => {
                rootPane.borderThickness = newValue;
                rootPane.saveConfig();
            }
        }
    }

    } // end ColumnLayout wrapper
}
