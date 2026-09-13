# quickshell 项目长期记忆

## 架构

- Caelestia shell（niri compositor）。服务层 `services/`（qs.services 单例），组件库 `components/`（qs.components，含 controls/containers/effects），控制中心 `modules/controlcenter/`，面板注册在 `PaneRegistry.qml`，面板通过 Loader 按路径懒加载。
- niri IPC：`plugin/src/Caelestia/Internal/niriipc.cpp` 原生 socket（NiriIpc 单例，outputs/workspaces/windows 实时事件）；`services/NiriService`-ish 封装在 `Niri.qml`；外部命令走 `Quickshell.Io` Process（如 DisplayService.qml）。
- niri 26.04：`niri msg output <name> {on|off|mode|scale|transform|position|vrr}`；outputs JSON 的 scale/transform/position 在 `logical` 对象内；mode 字符串 `WxH@R.fff`，refresh_rate 单位 mHz。

## niri 输出与显示配置

- 本机为双显卡（AMD 核显 + NVIDIA 4070 Max-Q），内屏在 eDP-1（AMD 侧）/ eDP-2（NVIDIA 侧）间交替枚举；已用 `~/.config/niri/cfg/display.kdl` 对两个名字持久化 `off`。外接屏 HDMI-A-1 挂 NVIDIA card1。
- niri 配置在 `~/.config/niri/config.kdl`（include cfg/*.kdl），改后自动热重载，`niri validate -c` 校验。`niri msg output off` 仅为临时配置。

## quickshell 热重载限制（踩过的坑）

- 运行中新增 service 单例文件：必须 `import Quickshell`（否则根类型 Singleton 解析失败），且避免 `Component.onCompleted`（Component 附加对象在热重载降级上下文不可用）——冷启动无此限制。
- 触发重载：修改 shell.qml 内容（touch 有时不触发）；看日志：`quickshell log -t N`。
- 系统自带 `/usr/bin/qmllint` 是 Qt5 旧版；用 `/usr/lib/qt6/bin/qmllint` 做语法检查。
- Flickable 内的 ColumnLayout 不要用 `anchors.left/right: parent` 拿宽度（contentItem 宽度不可靠），用 `width: <flickable id>.width` 显式绑定。

## 用户偏好

- 设置面板 UI 全部使用现有组件库（StyledText/StyledRect/StateLayer/CollapsibleSection/SwitchRow/ToggleButton/SectionContainer 等），颜色走 `Colours.palette.m3*`，尺寸走 `Appearance.*`。
