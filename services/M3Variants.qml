pragma Singleton

import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Searcher {
    id: root

    // Path to store current scheme state
    readonly property string schemeStatePath: `${Paths.state}/scheme.json`

    function transformSearch(search: string): string {
        return search.slice(`${Config.launcher.actionPrefix}variant `.length);
    }

    // Set the variant and save to state file
    function setVariant(variantName: string): void {
        schemeStateFile.setVariant(variantName);
    }

    // Load current scheme state from state file
    FileView {
        id: schemeStateFile

        path: root.schemeStatePath

        // Helper to update the variant while preserving other state
        function setVariant(variantName: string): void {
            try {
                const currentState = JSON.parse(text());
                const isDynamic = currentState.name === "dynamic";
                currentState.variant = variantName;

                // Save updated state via FileView
                const jsonContent = JSON.stringify(currentState, null, 2);
                ensureStateDirProcess._pendingContent = jsonContent;
                ensureStateDirProcess.running = true;

                // Update the Schemes service current variant
                Schemes.currentVariant = variantName;

                // If using dynamic scheme, regenerate colors with new variant
                if (isDynamic) {
                    Schemes.regenerateDynamic();
                    // Also regenerate terminal/GTK colors with new variant
                    if (Wallpapers.current) {
                        Wallpapers.runColorGeneration(Wallpapers.current, variantName);
                    }
                }
            } catch (e) {
                console.error("Failed to set variant:", e);
            }
        }
    }

    Process {
        id: ensureStateDirProcess

        property string _pendingContent

        command: ["mkdir", "-p", Paths.state]
        running: false

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && _pendingContent) {
                schemeStateFile.setText(_pendingContent);
            }
        }
    }

    list: [
        Variant {
            variant: "vibrant"
            icon: "sentiment_very_dissatisfied"
            name: qsTr("鲜艳色")
            description: qsTr("高彩度调色板。主调色板的彩度达到最大。")
        },
        Variant {
            variant: "tonalspot"
            icon: "android"
            name: qsTr("色调斑点")
            description: qsTr("Material 主题颜色的默认方案。低彩度的柔和调色板。")
        },
        Variant {
            variant: "expressive"
            icon: "compare_arrows"
            name: qsTr("表现色")
            description: qsTr("中等彩度调色板。主调色板的色相与种子颜色不同，以增添变化。")
        },
        Variant {
            variant: "fidelity"
            icon: "compare"
            name: qsTr("保真色")
            description: qsTr("与种子颜色匹配，即使种子颜色非常鲜艳（高彩度）。")
        },
        Variant {
            variant: "content"
            icon: "sentiment_calm"
            name: qsTr("内容")
            description: qsTr("与保真色几乎相同。")
        },
        Variant {
            variant: "fruitsalad"
            icon: "nutrition"
            name: qsTr("水果沙拉")
            description: qsTr("趣味主题 - 种子颜色的色相不会出现在主题中。")
        },
        Variant {
            variant: "rainbow"
            icon: "looks"
            name: qsTr("彩虹")
            description: qsTr("趣味主题 - 种子颜色的色相不会出现在主题中。")
        },
        Variant {
            variant: "neutral"
            icon: "contrast"
            name: qsTr("中性色")
            description: qsTr("接近灰度，带一丝彩度。")
        },
        Variant {
            variant: "monochrome"
            icon: "filter_b_and_w"
            name: qsTr("单色")
            description: qsTr("所有颜色均为灰度，无彩度。")
        }
    ]
    useFuzzy: Config.launcher.useFuzzy.variants

    component Variant: QtObject {
        required property string variant
        required property string icon
        required property string name
        required property string description

        function onClicked(list: var): void {
            list.visibilities.launcher = false;
            root.setVariant(variant);
        }
    }
}
