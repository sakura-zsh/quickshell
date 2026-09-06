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

    title: qsTr("字体")
    showBackground: true

    ColumnLayout {
        spacing: Appearance.spacing.lg
        Layout.fillWidth: true

        FontDropdown {
            Layout.fillWidth: true
            label: qsTr("Material 字体族")
            currentFont: rootPane.fontFamilyMaterial
            onFontSelected: fontName => {
                rootPane.fontFamilyMaterial = fontName;
                rootPane.saveConfig();
            }
        }

        FontDropdown {
            Layout.fillWidth: true
            label: qsTr("等宽字体族")
            currentFont: rootPane.fontFamilyMono
            onFontSelected: fontName => {
                rootPane.fontFamilyMono = fontName;
                rootPane.saveConfig();
            }
        }

        FontDropdown {
            Layout.fillWidth: true
            label: qsTr("无衬线字体族")
            currentFont: rootPane.fontFamilySans
            onFontSelected: fontName => {
                rootPane.fontFamilySans = fontName;
                rootPane.saveConfig();
            }
        }

        SectionContainer {
            contentSpacing: Appearance.spacing.lg

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("字体大小倍率")
                value: rootPane.fontSizeScale
                from: 0.7
                to: 1.5
                decimals: 2
                suffix: "×"
                validator: DoubleValidator {
                    bottom: 0.7
                    top: 1.5
                }

                onValueModified: newValue => {
                    rootPane.fontSizeScale = newValue;
                    rootPane.saveConfig();
                }
            }
        }
    }
}
