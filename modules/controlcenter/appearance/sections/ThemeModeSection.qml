pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import QtQuick

CollapsibleSection {
    title: qsTr("主题模式")
    description: qsTr("浅色或深色主题")
    showBackground: true

    SwitchRow {
        label: qsTr("深色模式")
        checked: !Colours.currentLight
        onToggled: checked => {
            Colours.setMode(checked ? "dark" : "light");
            Schemes.regenerateDynamic();
        }
    }
}
