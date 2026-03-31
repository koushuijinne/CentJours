# BUG-2026-03-28-VALIDATION-MATRIX

## 标题

把 `docs/bugs` 里的关键问题收口为可重复执行的验证矩阵

## 用途

- 保留 [docs/bugs/bugs_check.md](docs/bugs/bugs_check.md) 作为原始问题输入
- 用本文件记录“哪些问题已经有自动化回归，哪些仍需 Windows 真机”
- 后续新增 bug 时，优先补这里的“回归入口”

## 自动化验证

| 原始问题 | 当前回归入口 | 覆盖点 |
|----------|--------------|--------|
| 悬停框挡字 / 点击详情看不到底部内容 / hover 与 click 面板位置突变 | `tests/godot/map_controller_contract_test.gd` | hover / click 分层、同锚点、滚动护栏、缩放与复位 |
| 存档/读档报 `theme_override_constants` 错误 | `tests/godot/save_load_flow_test.gd` + Windows headless boot | 顶栏存读档链可打开、可关闭、可提交；主场景装配不再因弹窗构建崩溃 |
| 一回合行动语义不清、modal 打开时还能继续交互 | `tests/godot/save_load_flow_test.gd` + `tests/godot/dialog_flow_test.gd` | 新局确认/取消、难度取消、设置取消、读档取消、战斗/接见失败恢复 |
| 读档后状态错位或锁死 | `tests/godot/save_load_flow_test.gd` | Day / phase 恢复、地图锁定清空、难度恢复、Tray 清空 |
| 页面被长文本撑大 | `tests/godot/main_menu_flow_test.gd` + `tests/godot/map_controller_contract_test.gd` | Narrative/Situation 仍走滚动容器，hover/详情面板有边界和滚动 |
| 教程弹窗正文变成竖排窄列 | `tests/godot/main_menu_flow_test.gd` + Windows 真机 | 弹窗固定宽度、正文/滚动区最小宽度、长中文正文不再被压成异常窄列 |
| 第 2 天后教程弹窗遮住主流程，连续两日行动 / 顶栏存读档 / 新局取消链容易误判 | `tests/godot/main_menu_flow_test.gd` + `tests/godot/save_load_flow_test.gd` | 跨天后先清 tutorial modal，再验证连续休整后行军、覆盖确认、读档取消、新局取消 |

## 仍需 Windows 真机

| 问题类型 | 原因 |
|----------|------|
| 中文换行、字体发虚、局部遮挡 | `GdUnit4` 只能测节点状态，不能替代视觉验收 |
| 地图缩放后的主观可读性 | 自动化能测缩放数值，不能判断操作手感 |
| 面板层级与整体布局观感 | 需要真机看交互流畅度和视觉稳定性 |

## 执行入口

- Windows `GdUnit4`

```bash
cd /d E:\projects\CentJours
tools\run_gdunit_windows.cmd E:\software\godot\Godot_v4.6.1-stable_win64_console.exe res://tests/godot
```

- Windows headless boot

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --quit
```

- Windows smoke scene

```bash
E:\software\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path E:\projects\CentJours --scene res://src/dev/engine_smoke_test_scene.tscn
```
