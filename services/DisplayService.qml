pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Internal
import QtQuick

Singleton {
    id: root

    // ── 实时输出数据 ──
    // NiriIpc 只在 OutputsChanged 事件时刷新；而临时执行 `niri msg output ... scale`
    // 等命令并不会让 Niri 发 OutputsChanged，所以这里保留一个本地镜像，
    // 在命令成功后主动用 `niri msg --json outputs` 拉取一次最新状态。
    property var outputs: NiriIpc.outputs

    readonly property var outputList: {
        const list = [];
        for (const name in root.outputs)
            list.push(root.outputs[name]);
        return list;
    }

    readonly property bool available: NiriIpc.available

    // ── 单信号源自动恢复 ──
    // 场景：用户在外接屏工作时可能主动关闭内屏；拔掉外接屏后只剩一个输出源。
    // 如果这个唯一输出源仍处于关闭状态（没有 logical），niri 不会自动打开它，
    // 这里监听输出变化，检测到“唯一输出被关闭”时自动把它重新开启。

    property string _autoOnName: ""
    property bool _autoOnQueued: false

    function _maybeEnableSingleOutput() {
        if (!root.available)
            return;

        const list = root.outputList;
        if (list.length !== 1)
            return;

        const output = list[0];
        const name = output?.name ?? "";
        if (!name || root.isEnabled(name))
            return;

        // 没有可用模式时没有必要发送 on 命令
        const modes = output?.modes;
        if (!modes || modes.length === 0)
            return;

        // 避免重复的 on 命令排进队列
        if (root._autoOnQueued && root._autoOnName === name)
            return;

        root._autoOnQueued = true;
        root._autoOnName = name;
        root._run(["output", name, "on"], (ok, err) => {
            root._autoOnQueued = false;
            root._autoOnName = "";
            if (ok)
                root.refreshOutputs();
            else
                console.warn(`DisplayService: 自动开启唯一输出 ${name} 失败: ${err}`);
        });
    }

    Connections {
        target: NiriIpc

        function onOutputsChanged() {
            root.outputs = NiriIpc.outputs;
            root._maybeEnableSingleOutput();
        }

        function onAvailableChanged() {
            root._maybeEnableSingleOutput();
        }
    }

    Timer {
        interval: 800
        running: true
        repeat: false
        onTriggered: root._maybeEnableSingleOutput()
    }

    // ── 模式解析 ──

    function getModes(name) {
        const o = root.outputs[name];
        if (!o || !o.modes)
            return [];
        const modes = [];
        for (let i = 0; i < o.modes.length; i++) {
            const m = o.modes[i];
            const hz = m.refresh_rate / 1000;
            modes.push({
                index: i,
                width: m.width,
                height: m.height,
                refresh: hz,
                preferred: !!m.is_preferred,
                current: i === o.current_mode,
                label: `${m.width}×${m.height} @ ${Number(hz.toFixed(3))}Hz`,
                modeStr: `${m.width}x${m.height}@${hz.toFixed(3)}`
            });
        }
        return modes;
    }

    function getResolutions(name) {
        const modes = root.getModes(name);
        const seen = {};
        const list = [];
        for (const m of modes) {
            const key = `${m.width}x${m.height}`;
            if (seen[key] === undefined) {
                seen[key] = true;
                list.push({
                    width: m.width,
                    height: m.height,
                    label: `${m.width}×${m.height}`
                });
            }
        }
        list.sort((a, b) => (b.width * b.height) - (a.width * a.height) || b.width - a.width);
        return list;
    }

    function getRefreshRates(name, width, height) {
        const modes = root.getModes(name).filter(m => m.width === width && m.height === height);
        modes.sort((a, b) => b.refresh - a.refresh);
        return modes;
    }

    function getOutput(name) {
        return root.outputs[name] ?? null;
    }

    function getLogical(name) {
        return root.outputs[name]?.logical ?? null;
    }

    function isEnabled(name) {
        return !!root.getLogical(name);
    }

    function getTransform(name) {
        const l = root.getLogical(name);
        if (!l)
            return "normal";
        return (l.transform ?? "Normal").toString().toLowerCase();
    }

    function getScale(name) {
        return root.getLogical(name)?.scale ?? 1;
    }

    // ── 命令队列（串行执行 niri msg output ...） ──

    property var _queue: []
    property var _currentJob: null
    property bool _busy: false

    function _run(args, onDone) {
        root._queue.push({
            args: args,
            onDone: onDone
        });
        root._drain();
    }

    function _drain() {
        if (root._busy || root._queue.length === 0)
            return;
        const job = root._queue.shift();
        root._busy = true;
        root._currentJob = job;
        niriProc.command = ["niri", "msg"].concat(job.args);
        niriProc.running = true;
    }

    Process {
        id: niriProc

        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: stderrCollector
        }

        onExited: exitCode => {
            const job = root._currentJob;
            root._busy = false;
            root._currentJob = null;
            const err = (stderrCollector.text ?? "").trim();
            if (job?.onDone)
                job.onDone(exitCode === 0, exitCode === 0 ? "" : (err || qsTr("niri msg 退出码 %1").arg(exitCode)));
            root._drain();
        }
    }

    // ── 主动刷新 outputs（niri 的 OutputsChanged 事件不会覆盖所有临时配置变更） ──

    property bool _refreshRunning: false
    property bool _refreshQueued: false

    function refreshOutputs() {
        if (root._refreshRunning) {
            root._refreshQueued = true;
            return;
        }

        root._refreshRunning = true;
        root._refreshQueued = false;
        refreshProc.command = ["niri", "msg", "--json", "outputs"];
        refreshProc.running = true;
    }

    Process {
        id: refreshProc

        stdout: StdioCollector {
            id: refreshOutputCollector
        }
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode === 0) {
                const text = (refreshOutputCollector.text ?? "").trim();
                if (text) {
                    try {
                        root.outputs = JSON.parse(text);
                    } catch (e) {
                        console.warn(`DisplayService: 解析 outputs JSON 失败: ${e}`);
                    }
                }
            }

            root._refreshRunning = false;
            if (root._refreshQueued) {
                root._refreshQueued = false;
                root.refreshOutputs();
            }
        }
    }

    function _toastResult(ok, err, okTitle, failTitle, icon) {
        if (ok)
            Toaster.toast(okTitle, "", icon);
        else
            Toaster.toast(failTitle, err, "error");
    }

    // ── 公共操作 ──

    // 开关显示器。禁用前保护：不允许关闭最后一个启用的输出。
    function setEnabled(name, on) {
        if (!root.available)
            return;
        if (!on) {
            const enabledCount = root.outputList.filter(o => root.isEnabled(o.name)).length;
            if (root.isEnabled(name) && enabledCount <= 1) {
                Toaster.toast(qsTr("无法禁用"), qsTr("至少需要保留一个启用的显示器"), "monitor_off");
                return;
            }
        }
        root._run(["output", name, on ? "on" : "off"], (ok, err) => {
            root._toastResult(ok, err, qsTr("显示器已%1").arg(on ? qsTr("开启") : qsTr("关闭")), qsTr("显示器开关失败"), on ? "monitor" : "monitor_off");
            if (ok)
                root.refreshOutputs();
        });
    }

    // modeStr 形如 "2560x1440@144.000"
    function setMode(name, modeStr) {
        if (!root.available)
            return;
        root._run(["output", name, "mode", modeStr], (ok, err) => {
            root._toastResult(ok, err, qsTr("显示模式已更改"), qsTr("切换显示模式失败"), "aspect_ratio");
            if (ok)
                root.refreshOutputs();
        });
    }

    function setScale(name, scale) {
        if (!root.available)
            return;
        root._run(["output", name, "scale", String(scale)], (ok, err) => {
            root._toastResult(ok, err, qsTr("缩放已设置为 %1").arg(String(scale)), qsTr("设置缩放失败"), "zoom_out_map");
            if (ok)
                root.refreshOutputs();
        });
    }

    // transform: "normal" | "90" | "180" | "270"
    function setTransform(name, transform) {
        if (!root.available)
            return;
        root._run(["output", name, "transform", transform], (ok, err) => {
            root._toastResult(ok, err, qsTr("旋转已设置为 %1").arg(transform === "normal" ? qsTr("正常") : transform), qsTr("设置旋转失败"), "screen_rotation");
            if (ok)
                root.refreshOutputs();
        });
    }

    function setPosition(name, x, y) {
        if (!root.available)
            return;
        root._run(["output", name, "position", "set", String(Math.round(x)), String(Math.round(y))], (ok, err) => {
            root._toastResult(ok, err, qsTr("显示器位置已更新"), qsTr("设置显示器位置失败"), "open_with");
            if (ok)
                root.refreshOutputs();
        });
    }

    function setAutoPosition(name) {
        if (!root.available)
            return;
        root._run(["output", name, "position", "auto"], (ok, err) => {
            root._toastResult(ok, err, qsTr("已自动排列显示器位置"), qsTr("自动排列失败"), "auto_awesome");
            if (ok)
                root.refreshOutputs();
        });
    }

    function setVrr(name, on) {
        if (!root.available)
            return;
        root._run(["output", name, "vrr", on ? "on" : "off"], (ok, err) => {
            root._toastResult(ok, err, qsTr("可变刷新率已%1").arg(on ? qsTr("开启") : qsTr("关闭")), qsTr("设置可变刷新率失败"), "refresh");
            if (ok)
                root.refreshOutputs();
        });
    }
}
