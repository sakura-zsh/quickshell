# quickshell 项目长期记忆

## 架构

- Caelestia shell（niri compositor）。服务层 `services/`（qs.services 单例），组件库 `components/`（qs.components，含 controls/containers/effects），控制中心 `modules/controlcenter/`，面板注册在 `PaneRegistry.qml`，面板通过 Loader 按路径懒加载。
- **bar 为顶部横向布局**（2026-09-13 由竖向左侧重构而来）。`modules/bar/BarWrapper.qml` 是容器（`implicitHeight`/`anchors.bottom`/`contentHeight`），`Bar.qml` 根为 `RowLayout`，`hPadding` 为首尾内边距；bar 的**厚度**复用 `Config.bar.sizes.innerWidth`（不新增字段以免配置迁移）。drawers 中所有定位以 `bar.implicitHeight` 为垂直偏移、`Config.border.thickness` 为水平偏移。workspaces/context 右键菜单尚未横向化（遗留）。
- popouts 弹出语义已横向化：Wrapper 挂在 bar 下方，宽度不参与动画、高度收合（implicitHeight: open ? H : 0）；Background.qml 融合形状顶部直角、底部圆角。勿恢复旧 x>0||hasCurrent 宽度条件（关闭不收敛→白背景残留）。
- 抽屉系统：`modules/drawers/Drawers.qml` 定义全屏 StyledWindow（mask + regions + Interactions{Panels, BarWrapper}），`Exclusions/Border/Backgrounds/Panels/Interactions` 都依赖 `bar.implicitHeight` 定位。
- niri IPC：`plugin/src/Caelestia/Internal/niriipc.cpp` 原生 socket（NiriIpc 单例，outputs/workspaces/windows 实时事件）；`services/NiriService`-ish 封装在 `Niri.qml`；外部命令走 `Quickshell.Io` Process（如 DisplayService.qml）。
- niri 26.04：`niri msg output <name> {on|off|mode|scale|transform|position|vrr}`；outputs JSON 的 scale/transform/position 在 `logical` 对象内；mode 字符串 `WxH@R.fff`，refresh_rate 单位 mHz。

## niri 输出与显示配置

- 本机为双显卡（AMD 核显 + NVIDIA 4070 Max-Q），内屏在 eDP-1（AMD 侧）/ eDP-2（NVIDIA 侧）间交替枚举；已用 `~/.config/niri/cfg/display.kdl` 对两个名字持久化 `off`。外接屏 HDMI-A-1 挂 NVIDIA card1。
- niri 配置在 `~/.config/niri/config.kdl`（include cfg/*.kdl），改后自动热重载，`niri validate -c` 校验。`niri msg output off` 仅为临时配置。

## quickshell 热重载限制（踩过的坑）

- 运行中新增 service 单例文件：必须 `import Quickshell`（否则根类型 Singleton 解析失败），且避免 `Component.onCompleted`（Component 附加对象在热重载降级上下文不可用）——冷启动无此限制。
- 触发重载：修改 shell.qml 内容（touch 有时不触发）；看日志：`quickshell log -t N`。
- **大改动后不要依赖热重载**：多次 reload 会让实例进入"配置加载成功但组件不实例化"甚至进程崩溃的状态。改完直接重启：`pkill -x quickshell; setsid quickshell -c /home/sakura/.config/quickshell > /tmp/qs.log 2>&1 &`。判断实例是否存活用 `pgrep -x quickshell`（无输出=已崩溃，不是代码问题）。
- **重启 quickshell 禁止用 WorkBuddy 内嵌终端直接 setsid**：会把 ELECTRON_RUN_AS_NODE=1 等 WorkBuddy 环境变量带进 quickshell，dock/启动器经 execDetached 继承该环境，导致 Cider 等 Electron 应用被以纯 Node 模式拉起、静默失败（2026-09-13 实际发生）。正确方式：niri msg action spawn -- quickshell -c ~/.config/quickshell（继承 niri 干净环境），或 env -u ELECTRON_RUN_AS_NODE setsid ...
- 截图验证 bar 前需确认**没有全屏窗口**（niri 全屏窗口会遮挡 layer-shell top 层）；无鼠标模拟工具时可用 `quickshell ipc call drawers toggle dashboard` / `quicktoggles open` 验证面板定位。
- 系统自带 `/usr/bin/qmllint` 是 Qt5 旧版；用 `/usr/lib/qt6/bin/qmllint` 做语法检查。
- Flickable 内的 ColumnLayout 不要用 `anchors.left/right: parent` 拿宽度（contentItem 宽度不可靠），用 `width: <flickable id>.width` 显式绑定。

## 用户偏好

- 设置面板 UI 全部使用现有组件库（StyledText/StyledRect/StateLayer/CollapsibleSection/SwitchRow/ToggleButton/SectionContainer 等），颜色走 `Colours.palette.m3*`，尺寸走 `Appearance.*`。
