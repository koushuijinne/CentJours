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
