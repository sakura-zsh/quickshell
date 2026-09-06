//@ pragma Env QML2_IMPORT_PATH=/home/sakura/.config/quickshell
import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.config
import "modules/controlcenter"
import qs.modules.controlcenter.display

ShellRoot {
    Session {
        id: testSession

        active: "显示器"
    }

    PanelWindow {
        id: testWin

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusiveZone: -1
        color: "transparent"

        StyledRect {
            anchors.fill: parent
            anchors.margins: 150
            radius: Appearance.rounding.large
            color: Colours.palette.m3surface

            Loader {
                anchors.fill: parent
                sourceComponent: testPane
            }

            Component {
                id: testPane

                DisplayPane {
                    session: testSession
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        onTriggered: Qt.quit()
    }
}
