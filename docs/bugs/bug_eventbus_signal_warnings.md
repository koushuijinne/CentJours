# BUG-2026-03-27-EVENTBUS-WARNINGS

## 基本信息

- `ID`: `BUG-2026-03-27-EVENTBUS-WARNINGS`
- `标题`: `EventBus` 声明型 signal 在 `GdUnit4` 中持续产生 warning 噪音
- `级别`: `P2`
- `状态`: `已修复`
- `来源`: Windows `GdUnit4` 执行日志

## 复现

1. 在 Windows 下运行 `tools\run_gdunit_windows.cmd`
2. 观察 `main_menu_flow_test.gd` 开始前的 GDScript reload 日志
3. 会看到 `EventBus` 中多条 signal 被报告为“declared but never explicitly used”

## 预期结果

- 自动化测试日志主要只保留真正有诊断价值的 warning 和 failure

## 实际结果

- `EventBus` 的声明型 signal 每次 `GdUnit4` 运行都会重复刷出 warning
- 会稀释真正的失败信号，增加日志阅读成本

## 影响范围

- Godot `GdUnit4` 本地执行
- Windows CI 日志可读性

## 根因

- `EventBus` 是集中声明 signal 的单例，信号主要被外部脚本连接与发射
- Godot 的静态检查对这种“声明在一个文件、使用在别处”的模式会报告未显式使用 warning

## 修复方案

- 在 [src/core/event_bus.gd](src/core/event_bus.gd) 对声明型 signal 区块增加 `@warning_ignore_start("unused_signal")` / `@warning_ignore_restore("unused_signal")`
- 仅屏蔽 `unused_signal`，不压制其他真实 warning
- 保留集中声明结构，不把总线拆散到多个脚本

## 回归验证

- Windows `GdUnit4`
- Windows Godot headless 主项目
- Windows Godot smoke scene
- 手工观察 `tools\run_gdunit_windows.cmd` 日志，确认 `EventBus` 的 `unused_signal` warning 不再刷屏

## 附件

- 日志来源：最近几轮 `GdUnit4` 运行输出
