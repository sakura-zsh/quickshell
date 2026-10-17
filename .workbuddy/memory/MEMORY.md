# quickshell 项目长期记忆

## 架构

- Caelestia shell（niri compositor）。服务层 `services/`（qs.services 单例），组件库 `components/`（qs.components，含 controls/containers/effects），控制中心 `modules/controlcenter/`，面板注册在 `PaneRegistry.qml`，面板通过 Loader 按路径懒加载。
- **桌面歌词必须绑 `Players.islandSourceSteady`，不能绑 `islandSourcePlaying`**：Cider (Electron) 在**手动切歌**时会把 MPRIS `PlaybackStatus` 打成 `Stopped`（2026-10-05 实测持续 ~0.59s：16:54:04.379 掉、16:54:04.968 回）。`Wrapper.qml` 的 `visible` 若直接读 `isPlaying`，整个 layer 面会在这 0.6s 内 unmount→remount，肉眼就是"切歌瞬间歌词闪一下/消失再出现"。`islandSourceSteady = isPlaying || 最近 islandIdleGrace(3000ms) 内播放过`（`services/Players.qml`，用时间戳派生而非 latch，热重载期间也不会读到假值），只放行真正的停止。队列自然过渡（自动切歌）不会掉状态，只有手动切歌会。验证手段：`niri msg layers | grep caelestia-lyrics` 轮询图层是否存在 + `busctl --user get-property <mpris> … PlaybackStatus`。
- **bar 居中模块（时钟）钉死约定**：位于两个 `spacer` 之间的条目（`Config.bar.entries` 中 clock）在 `Bar.qml` 里被**钉在栏中心**，不参与流式布局：槽位 `Layout.preferredWidth: 0`，条目内容包一层 `Item` 后由 `x = root.width/2 + Config.bar.clock.offset - slot.x - width/2` 定位。原因：曾用"两侧宽度补偿"让模块居中，但邻居（工作区/标题/托盘/status）一变化就会漂移。**注意 Loader 会把直接子项尺寸改成自身尺寸**，所以零宽槽位必须再包一层 Item，否则被承载组件宽度变 0。
- **bar 为顶部横向布局**（2026-09-13 由竖向左侧重构而来）。`modules/bar/BarWrapper.qml` 是容器（`implicitHeight`/`anchors.bottom`/`contentHeight`），`Bar.qml` 根为 `RowLayout`，`hPadding` 为首尾内边距；bar 的**厚度**复用 `Config.bar.sizes.innerWidth`（不新增字段以免配置迁移）。drawers 中所有定位以 `bar.implicitHeight` 为垂直偏移、`Config.border.thickness` 为水平偏移。workspaces/context 右键菜单尚未横向化（遗留）。
- popouts 弹出语义已横向化：Wrapper 挂在 bar 下方，宽度不参与动画、高度收合（implicitHeight: open ? H : 0）；Background.qml 融合形状顶部直角、底部圆角。勿恢复旧 x>0||hasCurrent 宽度条件（关闭不收敛→白背景残留）。
- 抽屉系统：`modules/drawers/Drawers.qml` 定义全屏 StyledWindow（mask + regions + Interactions{Panels, BarWrapper}），`Exclusions/Border/Backgrounds/Panels/Interactions` 都依赖 `bar.implicitHeight` 定位。
- **「四周边框」= `modules/drawers/Border.qml` 画的整圈 surface**（顶部那圈就是任务栏底色，左右/下是 `Config.border.thickness` 细条；mask 内挖出圆角矩形）。所有面板背景（10 个 `*/Background.qml` 的 `fillColor`）与它共用 `Colours.shellSurface`，才不会有接缝。相关配置：`Config.border.{enabled, colour, thickness, rounding}`——`colour` 为 `""` 表示跟随主题 `palette.m3surface`，`enabled=false` 时 Border 整圈不画。
- **关边框后的任务栏功能区化**：`Bar.qml` 的 `zones/zonePad`。每个非 spacer/divider/居中(pinned) 条目的 delegate 是 `Item`（内层 `Loader` + 一个 `StyledRect id: zoneBg` 胶囊，`visible: isZone && root.zones`）。**关键：zones 打开时模块自己的胶囊必须让位**（Tray/StatusIcons/ActiveWindow/Workspaces 的颜色都加了 `Config.border.enabled &&`），否则两层胶囊叠出一个亮边，肉眼就是「多出来的白色块」。pinned 的时钟槽位 `Layout.preferredWidth=0`，不能给它画 zoneBg（会变成 20px 白条），灵动岛自带黑底。**`pad` 加在 `Layout.left/rightMargin` 上，不是从 row spacing 里扣** —— 功能区块之间的间隙恒等于原 `spacing`（实测 12px）。`zoneBg` 的 `opacity` 要跟 Drawers.qml 那层一致（`Colours.transparency.enabled ? base : 1`）。`zoneColour`：设了 `Config.border.colour` 就用 `shellSurface`，否则用 `tPalette.m3surfaceContainer`（跟开边框时模块胶囊同色）。
- **静止壁纸（总览不出现黑底、壁纸不跟工作区跑）= 纯 niri 配置，不要用 QML 硬扛**：niri 25.05+ 把 background/bottom 层跟着工作区缩放，黑底就是 `overview.backdrop-color`。正解是 `layer-rule { match namespace="^caelestia-background$" place-within-backdrop true }` + `layout { background-color "transparent" }`，并且**必须同时给 `^quickshell:Backdrop$` 也加**（它是模糊底，只加清晰壁纸那条的话模糊底仍然跟着工作区缩放、把壁纸盖住）。本机配置在 `~/.config/niri/cfg/backdrop.kdl`。`"WorkspacePositions"` 请求不存在（`error parsing request`），niri 也没有 workspace 级坐标可查 —— 试图用 QML 每列一张壁纸去"跟上"总览是死路（做过，全黑）。
- **`Bar.qml` 里没有 `import qs.components`**（原来只用 `Rectangle`），新增 `StyledRect` 时必须补上，否则 `StyledRect is not a type` → 整条栏加载失败。同类：`Bar.qml` 里 `id: island` 已被灵动岛占用，inline `component` **共享整文件 id 作用域**，新 id 不能撞。
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
