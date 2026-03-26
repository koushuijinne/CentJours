# 开发日志 002

承接 `development_log_001.md`；当单份日志接近 `500` 行时，从本文件继续记录。

## 2026-03-24 第 29 轮
分支: `auto/gameplay_update`
范围: 主菜单 bug sweep，收口地图交互、回合卡死护栏和存读档 UX
变更:
- 新建了 `bug_audit_2026-03-24.md`，把主菜单、地图交互、回合推进和存读档 UX 的高优先级问题统一列成修复台账。
- `save_manager.gd` 从单槽升级成 3 槽位存档，并保留旧 `user://cent_jours_save.json` 的兼容读取；`main_menu.gd` 顶栏补上 `新局`，`存档 / 读档` 改成槽位选择弹窗。
- `turn_manager.gd` 的 `submit_action()` 现在会返回成功/失败；`main_menu.gd` 在行动提交失败时会恢复交互，读档后也会强制回到 `action` 阶段，补上“增加军费后卡在结算中”的 UI 防呆链。
- 地图交互拆成两层：hover 改成顶部小预览，click 才打开锁定详情；`main_menu.tscn`、`layout_controller.gd`、`map_controller.gd` 同时收口了详情面板宽度、滚动、最小内容宽度和 hover / click 分层逻辑。
- 地图现在支持 `MapScroll + 滚轮缩放 + 右键复位`，用 scroll 容器承接高密节点区的查看需求；前 10 天教程重复、地图副标题重复、动作按钮语义不清也在这轮一起清了。
验证:
- Windows Godot 无头主项目已通过两次，确认主菜单脚本链和场景节点结构可以正常加载。
- Windows Godot smoke scene 已通过，确认行动提交 -> 结算 -> 次日这条关键主循环链仍可运行。
- Windows GUI 启动冒烟已通过，主项目能正常打开并存活至少 5 秒，没有出现启动即崩的 UI 结构错误。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将以主菜单 bug sweep 独立提交并推送到 `auto/gameplay_update`。
下一步:
- 回到玩法主线，继续把区域运营从“知道哪里承压”推进到“知道这一段区域该怎么经营和回收收益”。

## 2026-03-24 第 30 轮
分支: `auto/gameplay_update`
范围: 吸收 `docs/bugs` 第二轮问题，并把 bug 修复纪律写成 ADR
变更:
- `NarrativePanel` 改成固定边界 + 内部滚动，动作后历史日志不再把整个页面撑出窗口。
- `MapHoverPanel` 和 `MapInspectorPanel` 重新对齐到同一块右上区域；hover 预览补了内部滚动和更高的默认高度，锁定详情保留可滚动完整内容。
- 存读档槽位弹窗修掉了 `theme_override_constants` 运行时报错，改成标准的 `add_theme_constant_override()`。
- 新增 [ADR-010-bug-sweep-and-validation-discipline.md](/mnt/e/projects/CentJours/docs/decisions/ADR-010-bug-sweep-and-validation-discipline.md)，明确采纳“禁止 speculative implementation / implicit assumptions / missing error handling”，同时把 Windows 最小验证、长文本面板边界、入口真实交互验证和提交隔离规则正式写进决策层。
- `development_plan`、`agent_handoff`、`bug_audit_2026-03-24` 已同步到新的 bug 修复与规则优化计划。
验证:
- Windows Godot 无头主项目通过。
- Windows Godot GUI 启动冒烟通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与代码和文档一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续沿 ADR-010 收口高风险入口，优先补真实交互验证和主菜单剩余耦合点。

## 2026-03-24 第 31 轮
分支: `auto/gameplay_update`
范围: 完成测试底座第一轮，补齐 Rust 集成测试与属性测试
变更:
- `cent-jours-core/tests/` 已正式建立，新增 `save_load_flow.rs`、`action_resolution_flow.rs`、`march_preview_contract.rs` 三个集成测试入口。
- `Cargo.toml` 新增 `proptest`，第一批属性测试已覆盖旧事件 ID 迁移去重、补给结果边界、合法相邻行军的士气 / 疲劳边界。
- 存档迁移、政策失败、行军预判与结算一致性等跨模块行为，已从 `engine/state.rs` 内部单测外提到公开接口级测试。
- 修复了一处现有回归：`整顿驿站运输会暂时提高补给线效率` 这条测试此前会被区域任务奖励串扰，现在已隔离到纯政策时长断言。
- `dev_plan`、`agent_handoff`、`agent_session_rules` 已同步到新基线：Rust 第一批正式集成测试和属性测试已完成，当前 `P0` 转为 Godot `GdUnit4` 与 Windows CI。
验证:
- Windows `cargo test` 通过。
- 当前 Windows Rust 测试基线提升到 `211/211`。
- 本轮没有运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 直接进入第 2 轮：接入 `GdUnit4`，建立主菜单、地图交互、存读档和弹窗状态流的第一批 Godot 自动回归。

## 2026-03-25 第 32 轮
分支: `auto/gameplay_update`
范围: 完成测试底座第二轮，接入 Godot `GdUnit4` 并固化执行顺序
变更:
- 项目已接入 `addons/gdUnit4/` 运行时最小集，并在 `project.godot` 启用插件。
- `main_menu.gd` 为动态按钮和弹窗补了稳定节点名，降低 `GdUnit4` 夹具对场景树路径漂移的脆弱性。
- 新增 `tests/godot/main_menu_flow_test.gd` 与 `tests/godot/map_controller_contract_test.gd`，覆盖主菜单初始化、`执行行动 -> 次日`、`存档 -> 读档`、`新局` 重开、地图 hover / click 分层、缩放与选点详情。
- 已确认一条新的项目级执行约束：在新 checkout / 新环境上执行 `GdUnit4` CLI 前，必须先跑一次 Windows Godot `--headless --editor --quit` 刷新脚本类缓存，否则 CLI 可能找不到 `GdUnit4` 全局类。
- `dev_plan`、`agent_handoff` 与 ADR-010 已同步到新基线：Godot 前端第一批 `GdUnit4` 自动回归已完成，当前 `P0` 转为 Windows GitHub Actions 和 `GdUnit4` 执行链脚本化。
验证:
- Windows Godot `--headless --editor --quit` 已通过，确认脚本类缓存刷新链有效。
- Windows `GdUnit4` 已通过，当前基线 `7/7`。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 `GdUnit4` 接入和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 直接进入第 3 轮：建立 Windows GitHub Actions、脚本化 `GdUnit4` 执行顺序，并把 bug 继续绑定到自动回归。

## 2026-03-25 第 33 轮
分支: `auto/gameplay_update`
范围: 完成测试底座第三轮，建立 Windows CI 与仓库级验证脚本
变更:
- 新增 `tools/run_gdunit_windows.cmd`，把 `Windows Godot --headless --editor --quit -> GdUnit4 CLI` 固化成单一命令入口。
- 新增 `.github/workflows/windows-validation.yml`，在 Windows runner 上执行 Rust tests、`cargo build --features godot-extension`、`GdUnit4`、Godot headless boot 和 smoke scene，并上传 `reports/` 产物。
- `dev_plan`、`agent_handoff`、`ADR-010` 与 `agent_session_rules` 已同步到新基线：Windows CI 与本地 `GdUnit4` 执行链均已落地，当前 `P0` 改成观察并收口首轮云端结果，以及继续扩 Godot 回归覆盖。
验证:
- Windows `cargo test` 将按新的 CI 顺序重新验证。
- Windows `cargo build --features godot-extension` 将按新的 CI 顺序重新验证。
- Windows `tools\\run_gdunit_windows.cmd` 将按新的仓库脚本入口重新验证。
- Windows Godot 无头主项目与 smoke scene 将按新的 CI 顺序重新验证。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 workflow、仓库脚本和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 观察 GitHub Actions 首轮云端结果；若云端稳定，再继续把 `docs/bugs` 剩余问题压进 `GdUnit4` 和 smoke。

## 2026-03-26 第 34 轮
分支: `auto/gameplay_update`
范围: 修复 Windows CI 首轮云端失败
变更:
- 使用 `gh run view` 追到首轮 `windows-validation` 失败点，确认不是 Rust/Godot 逻辑错误，而是 workflow 写成了不存在的 `Godot_v4.6.1-stable_win64_console.exe.zip`。
- `windows-validation.yml` 已改为下载官方存在的 `Godot_v4.6.1-stable_win64.exe.zip`，并同步更新解压后查找的 exe 名称。
- `dev_plan` 与 `agent_handoff` 已同步到新状态：首轮云端失败原因明确，仓库修正已推入待验证队列。
验证:
- 本轮云端失败日志已通过 `gh run view 23580633754 --log-failed` 核实。
- 本地 Windows 验证链不受该问题影响，上一轮的 `cargo test`、`cargo build --features godot-extension`、`tools\\run_gdunit_windows.cmd`、Godot headless 和 smoke 仍为通过状态。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 workflow 修正和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 观察第二次 GitHub Actions 云端结果；若继续失败，就按失败步骤继续修 workflow，直到 Windows CI 首轮绿灯。
