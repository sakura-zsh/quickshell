pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    anchors.fill: parent

    // ── Read-only system information ──────────────────────────────────────────
    // Values are read once at startup from /proc, /sys and a few standard tools.
    property string kernel: ""
    property string architecture: ""
    property string hostname: ""
    property string hardware: ""
    property string cpuModel: ""
    property int cpuCores: 0
    property string memoryTotal: ""
    property string swapTotal: ""
    property string packages: ""
    property string display: ""
    property var gpus: []
    property var disks: []
    property var _dfMap: ({})

    readonly property string osBase: {
        const like = SysInfo.osIdLike ?? [];
        if (like.length === 0)
            return qsTr("Linux 发行版");
        const named = like.map(id => id === "arch" ? "Arch Linux" : id);
        return qsTr("基于 %1 的发行版").arg(named.join(", "));
    }

    readonly property string sessionType: {
        const raw = Quickshell.env("XDG_SESSION_TYPE") ?? "";
        return raw ? raw.charAt(0).toUpperCase() + raw.slice(1) : "";
    }

    function gpuName(driver: string, pci: string): string {
        const known = {
            "10de:2820": "NVIDIA GeForce RTX 4070 Mobile",
            "1002:164e": "AMD Radeon 610M"
        };
        return known[(pci ?? "").toLowerCase()] ?? `${driver === "nvidia" ? "NVIDIA" : driver === "amdgpu" ? "AMD" : driver} GPU`;
    }

    function formatBytes(bytes: number): string {
        if (bytes >= 1073741824)
            return `${(bytes / 1073741824).toFixed(1)} GiB`;
        if (bytes >= 1048576)
            return `${Math.round(bytes / 1048576)} MiB`;
        return `${Math.round(bytes / 1024)} KiB`;
    }

    function parseDf(text: string): var {
        const map = {};
        for (const line of text.split("\n")) {
            const tokens = line.trim().split(/\s+/);
            if (tokens.length < 6 || tokens[0] === "Filesystem")
                continue;
            map[tokens[5]] = {
                used: parseFloat(tokens[2]) * 1024,
                pct: tokens[4]
            };
        }
        return map;
    }

    function parseDisks(text: string): var {
        try {
            const blocks = (JSON.parse(text).blockdevices ?? []);
            // System disk first (nvme0n1 before nvme1n1), swap devices excluded
            blocks.sort((a, b) => a.name.localeCompare(b.name));

            const disks = [];
            let index = 0;

            for (const block of blocks) {
                if (block.type !== "disk" || block.name.startsWith("zram"))
                    continue;

                index++;
                const parts = [];

                for (const part of block.children ?? []) {
                    if (part.type !== "part")
                        continue;

                    const mounts = part.mountpoints ?? [];
                    if (mounts.length === 0)
                        continue;

                    // One partition can be mounted in several places (e.g. /, /home, /srv);
                    // prefer "/" and show a single row.
                    const mount = mounts.includes("/") ? "/" : mounts[0];
                    const df = root._dfMap[mount];

                    parts.push({
                        mount: mount,
                        value: df ? `${root.formatBytes(df.used)} / ${part.size} · ${df.pct} 已用` : part.size
                    });
                }

                parts.sort((a, b) => a.mount.localeCompare(b.mount));

                disks.push({
                    label: `${qsTr("磁盘 %1").arg(index)} · ${block.model ?? block.name}`,
                    size: block.size,
                    parts: parts
                });
            }

            return disks;
        } catch (err) {
            return [];
        }
    }

    // ── Data sources ──────────────────────────────────────────────────────────
    FileView {
        path: "/proc/version"

        onLoaded: {
            const tokens = text().trim().split(/\s+/);
            root.kernel = tokens[2] ?? "";
        }
    }

    Process {
        running: true
        command: ["uname", "-m"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.architecture = text.trim();
            }
        }
    }

    FileView {
        path: "/proc/sys/kernel/hostname"

        onLoaded: {
            root.hostname = text().trim();
        }
    }

    FileView {
        path: "/sys/class/dmi/id/sys_vendor"

        onLoaded: {
            const vendor = text().trim();
            if (vendor)
                root.hardware = vendor;
        }
    }

    FileView {
        path: "/sys/class/dmi/id/product_name"

        onLoaded: {
            const model = text().trim();
            if (model)
                root.hardware = root.hardware ? `${root.hardware} ${model}` : model;
        }
    }

    FileView {
        path: "/sys/class/dmi/id/product_version"

        onLoaded: {
            const version = text().trim();
            if (version && version !== "1")
                root.hardware = root.hardware ? `${root.hardware} (${version})` : version;
        }
    }

    FileView {
        path: "/proc/cpuinfo"

        onLoaded: {
            const lines = text().split("\n");
            let cores = 0;

            for (const line of lines) {
                if (line.startsWith("model name"))
                    root.cpuModel = line.split(":")[1]?.trim() ?? "";
                if (line.startsWith("processor"))
                    cores++;
            }

            root.cpuCores = cores;
        }
    }

    FileView {
        path: "/proc/meminfo"

        onLoaded: {
            const lines = text().split("\n");
            let totalKb = 0;
            let availableKb = 0;

            for (const line of lines) {
                const tokens = line.trim().split(/\s+/);
                if (tokens[0] === "MemTotal:")
                    totalKb = parseFloat(tokens[1]) ?? 0;
                else if (tokens[0] === "MemAvailable:")
                    availableKb = parseFloat(tokens[1]) ?? 0;
            }

            if (totalKb > 0) {
                const used = (totalKb - availableKb) / 1048576;
                root.memoryTotal = `${used.toFixed(1)} GiB / ${(totalKb / 1048576).toFixed(1)} GiB`;
            }
        }
    }

    FileView {
        path: "/proc/swaps"

        onLoaded: {
            const lines = text().split("\n");
            for (const line of lines) {
                const tokens = line.trim().split(/\s+/);
                if (tokens.length < 3 || !tokens[0].startsWith("/"))
                    continue;

                const size = parseFloat(tokens[2]) / 1048576;
                const name = tokens[0].split("/").pop().replace(/[0-9]+$/, "");
                root.swapTotal = `${size.toFixed(1)} GiB（${name}）`;
                break;
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/drm/card[0-9]/device/uevent; do . \"$d\" 2>/dev/null; echo \"$DRIVER|$PCI_ID\"; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.trim().split("\n")
                    .filter(line => line.includes("|"))
                    .map(line => {
                        const [driver, pci] = line.split("|");
                        return root.gpuName(driver, pci);
                    });

                // Discrete GPU first, matching common fetch tools
                names.sort((a, b) => (a.includes("NVIDIA") ? 0 : 1) - (b.includes("NVIDIA") ? 0 : 1));
                root.gpus = names;
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "pacman -Q 2>/dev/null | wc -l"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.packages = text.trim();
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "lsblk -J -o NAME,SIZE,TYPE,MODEL,MOUNTPOINTS; printf '\\n=====DF=====\\n'; df -P -x tmpfs -x devtmpfs -x efivarfs"]

        stdout: StdioCollector {
            onStreamFinished: {
                const chunks = text.split("=====DF=====");
                root._dfMap = root.parseDf(chunks[1] ?? "");
                root.disks = root.parseDisks(chunks[0] ?? "");
            }
        }
    }

    Process {
        running: true
        command: ["niri", "msg", "outputs"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const outputLine = lines.find(line => line.includes('Output "')) ?? "";
                const modeLine = lines.find(line => line.startsWith("  Current mode:")) ?? "";

                const nameMatch = outputLine.match(/\(([^)]+)\)\s*$/);
                const modeMatch = modeLine.match(/Current mode:\s*(\d+x\d+)\s*@\s*([\d.]+)\s*Hz/);

                if (nameMatch && modeMatch)
                    root.display = `${nameMatch[1]} · ${modeMatch[1]} @ ${Math.round(parseFloat(modeMatch[2]))} Hz`;
            }
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    ClippingRectangle {
        id: systemClippingRect

        anchors.fill: parent
        anchors.margins: Appearance.padding.md
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.md

        radius: systemBorder.innerRadius
        color: "transparent"

        Loader {
            id: systemLoader

            anchors.fill: parent
            anchors.margins: Appearance.padding.xl + Appearance.padding.md
            anchors.leftMargin: Appearance.padding.xl
            anchors.rightMargin: Appearance.padding.xl

            sourceComponent: systemContentComponent
        }
    }

    InnerBorder {
        id: systemBorder

        leftThickness: 0
        rightThickness: Appearance.padding.md
    }

    Component {
        id: systemContentComponent

        StyledFlickable {
            id: systemFlickable

            flickableDirection: Flickable.VerticalFlick
            contentHeight: systemLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: systemFlickable
            }

            ColumnLayout {
                id: systemLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.lg

                RowLayout {
                    spacing: Appearance.spacing.md

                    StyledText {
                        text: qsTr("系统")
                        font.pointSize: Appearance.font.size.titleMedium
                        font.weight: 500
                    }
                }

                // ── Operating system ────────────────────────────────────────────
                SectionContainer {
                    alignTop: true

                    StyledText {
                        text: qsTr("操作系统")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.xl

                        ColouredIcon {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48

                            source: SysInfo.osLogo
                            implicitSize: 48
                            colour: Colours.palette.m3primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true

                                text: SysInfo.osPrettyName || SysInfo.osName
                                font.pointSize: Appearance.font.size.titleMedium
                                font.weight: 600
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true

                                text: root.osBase
                                font.pointSize: Appearance.font.size.bodySmall
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }

                    InfoRow {
                        label: qsTr("发行版")
                        value: SysInfo.osPrettyName || SysInfo.osName
                    }

                    InfoRow {
                        label: qsTr("内核")
                        value: root.kernel
                    }

                    InfoRow {
                        label: qsTr("架构")
                        value: root.architecture
                    }

                    InfoRow {
                        label: qsTr("桌面环境")
                        value: SysInfo.wm
                    }

                    InfoRow {
                        label: qsTr("会话类型")
                        value: root.sessionType
                    }

                    InfoRow {
                        label: qsTr("软件包")
                        value: root.packages ? `${root.packages}（pacman）` : ""
                    }
                }

                // ── Hardware ────────────────────────────────────────────────────
                SectionContainer {
                    alignTop: true

                    StyledText {
                        text: qsTr("硬件")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    InfoRow {
                        label: qsTr("主机名")
                        value: root.hostname
                    }

                    InfoRow {
                        label: qsTr("硬件型号")
                        value: root.hardware
                    }

                    InfoRow {
                        label: qsTr("CPU")
                        value: root.cpuCores > 0 ? `${root.cpuModel} × ${root.cpuCores}` : root.cpuModel
                    }

                    Repeater {
                        model: root.gpus

                        delegate: ColumnLayout {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true

                            InfoRow {
                                Layout.fillWidth: true

                                label: root.gpus.length > 1 ? qsTr("GPU %1").arg(index + 1) : qsTr("GPU")
                                value: modelData
                            }
                        }
                    }

                    InfoRow {
                        label: qsTr("内存")
                        value: root.memoryTotal
                    }

                    InfoRow {
                        label: qsTr("交换")
                        value: root.swapTotal
                    }

                    InfoRow {
                        label: qsTr("显示器")
                        value: root.display
                    }
                }

                // ── Storage ─────────────────────────────────────────────────────
                SectionContainer {
                    alignTop: true

                    StyledText {
                        text: qsTr("存储")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    Repeater {
                        model: root.disks

                        delegate: ColumnLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: Appearance.spacing.sm

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.md

                                StyledText {
                                    Layout.fillWidth: true

                                    text: modelData.label
                                    font.pointSize: Appearance.font.size.bodySmall
                                    font.weight: 600
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: modelData.size
                                    font.pointSize: Appearance.font.size.bodySmall
                                    font.family: Appearance.font.family.mono
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }

                            Repeater {
                                model: modelData.parts

                                delegate: RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.xl

                                    StyledText {
                                        text: modelData.mount
                                        font.pointSize: Appearance.font.size.bodySmall
                                        font.family: Appearance.font.family.mono
                                        color: Colours.palette.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignRight

                                        text: modelData.value
                                        font.pointSize: Appearance.font.size.bodySmall
                                        font.family: Appearance.font.family.mono
                                        color: Colours.palette.m3onSurface
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideLeft
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Account / session ───────────────────────────────────────────
                SectionContainer {
                    alignTop: true

                    StyledText {
                        text: qsTr("账户")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    InfoRow {
                        label: qsTr("用户")
                        value: SysInfo.user
                    }

                    InfoRow {
                        label: qsTr("Shell")
                        value: SysInfo.shell
                    }

                    InfoRow {
                        label: qsTr("运行时长")
                        value: SysInfo.uptime
                    }

                    InfoRow {
                        visible: UPower.displayDevice.isLaptopBattery
                        label: qsTr("电池")
                        value: `${Math.round(UPower.displayDevice.percentage * 100)}%${UPower.onBattery ? "" : " · 已接电源"}`
                    }
                }
            }
        }
    }

    component InfoRow: RowLayout {
        id: infoRow

        required property string label
        required property string value

        Layout.fillWidth: true
        spacing: Appearance.spacing.xl

        StyledText {
            text: infoRow.label
            font.pointSize: Appearance.font.size.bodySmall
            font.family: Appearance.font.family.mono
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            Layout.fillWidth: true

            text: infoRow.value || "—"
            font.pointSize: Appearance.font.size.bodySmall
            font.family: Appearance.font.family.mono
            color: Colours.palette.m3onSurface
            elide: Text.ElideRight
        }
    }
}
