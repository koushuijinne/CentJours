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

## 2026-03-26 第 35 轮
分支: `auto/gameplay_update`
范围: 收口历史文案视角规则，给拿破仑第一人称建立边界
变更:
- `ADR-008` 已新增“玩家直面文本的拿破仑第一人称”检查项，明确只把第一人称用于教学、行动建议、阶段复盘和结局前独白，不把联军、议会、外交和 `historical_note` 强行改成主观口吻。
- `ADR-008` 已补入拿破仑语言风格参考书：`拿破仑书信集`、`圣赫勒拿回忆录`、`拿破仑战报`、`拿破仑：神话的终结`、`拿破仑致约瑟芬情书`。
- `product_plan` 已同步叙事分层：主观层服务玩家代入，客观层保证史实。
- `agent_handoff` 已补入接手约束，避免后续文案线把所有事件一刀切改成拿破仑第一人称。
验证:
- 本轮为文档与 ADR 收口，没有新增代码或运行时逻辑，未执行测试。
提交/推送:
- 本轮将与 ADR 和产品计划同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 新增 ADR，系统分析当前核心循环的系统化程度与历史逻辑深度，并把 Steam 可上线目标写成当前总目标。

## 2026-03-26 第 36 轮
分支: `auto/gameplay_update`
范围: 新增系统化设计 ADR，锁定 Steam 首发前的产品判断
变更:
- 新增 `ADR-011-core-loop-systemization-and-historical-depth.md`，把 `agent_chat_history` 里的横向比较收束成正式项目判断：当前系统化程度、历史逻辑深度、Steam 首发前的完成标准与优化顺序。
- `ADR-011` 已正式采纳两条方向判断：拿破仑第一人称只用于玩家主观层；大本营第一 / 第三人称互动场景属于低优先级扩展，不进入当前首发 P0。
- `product_plan`、`dev_plan` 与 `agent_handoff` 已同步到同一口径：当前总目标是“核心玩法优化完成，并达到 Steam 可上线级别”。
验证:
- 本轮为 ADR 与计划文档收口，没有新增代码或运行时逻辑，未执行测试。
提交/推送:
- 本轮将与新 ADR 和相关入口文档一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续第 3 轮，把自动工作流、交接规则和开发日志统一改成以 Steam 可上线为终局目标，并明确最少三轮自动循环已经完成。

## 2026-03-26 第 37 轮
分支: `auto/gameplay_update`
范围: 收口自动工作流终局条件，并把测试三轮完成状态写入规则层
变更:
- `agent_autonomous_workflow` 已把终局条件收紧为“核心玩法优化完成并达到 Steam 可上线级别”，不再把普通阶段里程碑或三轮完成当成停止理由。
- 自动工作流最高优先级规则已补充：即使一组三轮计划已经完成，也只能作为切换下一组 `P0` 的依据，不能当成停机点。
- `agent_handoff` 已同步写明：测试三轮计划已经完成，但后续主线仍然是观察 Windows CI、继续把 `docs/bugs` 绑定到回归、扩大 `GdUnit4` 覆盖。
验证:
- 本轮为规则与交接文档收口，没有新增代码或运行时逻辑，未执行测试。
提交/推送:
- 本轮将与前一轮尚未推送的 ADR-011 一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：先看 Windows GitHub Actions 最新云端结果，再把剩余高风险 UI / 状态流 bug 继续压进 `GdUnit4` 和 smoke。

## 2026-03-27 第 38 轮
分支: `auto/gameplay_update`
范围: 扩大 Godot 前端回归，补存读档、叙事面板和区域任务显示护栏
变更:
- `sidebar_controller.gd` 与 `main_menu.gd` 已把 `logistics_regional_task_*` 接进 `Current Situation`，右侧态势面板现在会直接显示区域任务、进度和奖励文本。
- `tests/godot/main_menu_flow_test.gd` 从 `4` 条扩到 `7` 条，新增覆盖多槽读档按钮可用性、叙事面板滚动日志追加、区域任务文本展示。
- 新增回归在执行中抓出一个真实 bug：`save_manager.gd` 在拼槽位标签时对 `outcome` 错用了 `String(...)` 构造，遇到 `in_progress` 会直接报错；本轮已改成 `str(...)` 并纳入自动回归。
- 本轮完成后，Godot 前端 `GdUnit4` 基线从 `7/7` 提升到 `10/10`。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 10/10`。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 GDScript 改动、回归测试和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：先看 Windows GitHub Actions 云端结果，再把弹窗失败恢复和更多主菜单边界状态继续压进 `GdUnit4`。

## 2026-03-27 第 39 轮
分支: `auto/gameplay_update`
范围: 收口 Windows CI 触发策略，减少 docs-only 无效占用
变更:
- `windows-validation.yml` 已新增 `concurrency`，同一分支新的 run 会自动取消旧 run，避免 Windows runner 被过期提交长期占用。
- `windows-validation.yml` 已对 `push` / `pull_request` 增加 `paths-ignore`，纯 `docs/**`、`bugs/**` 和根目录 `*.md` 改动不再默认触发整套 Windows 验证。
- 本轮同步把计划和交接里的 CI 状态改成新真值：首条成功 run 已出现，当前工作重点从“等首绿”切到“减少无效排队、继续观察代码提交 run”。
验证:
- 已通过 `gh run view 23606297120` 确认存在完整成功的 Windows validation run，包含 Rust tests、Windows GDExt build、`GdUnit4`、headless boot 和 smoke scene。
- 本轮对 workflow 的本地结构调整未跑 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 workflow 和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：观察这次 workflow 收紧后的下一条代码提交 run，并继续把弹窗失败恢复、结局和设置链路压进 `GdUnit4`。

## 2026-03-27 第 40 轮
分支: `auto/gameplay_update`
范围: 收口存读档槽位标签 UX，并把这条边界继续压进 `GdUnit4`
变更:
- `save_manager.gd` 现已统一正规化存档元信息中的 `outcome`：`null` 或空值会按 `in_progress` 处理，槽位标签不再显示 `<null>`。
- 槽位按钮文案现在会把进行中状态显示为“进行中”，并为常见结局提供玩家可读标签。
- `tests/godot/main_menu_flow_test.gd` 新增槽位标签文案回归，Godot 前端 `GdUnit4` 基线从 `10/10` 提升到 `11/11`。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 11/11`。
- Windows Godot 无头主项目通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与存读档 UX 修复、回归测试和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：观察 `cdcc8e6` 之后的新 CI run 是否按预期取消旧 run，并继续把弹窗失败恢复和更多主菜单边界状态压进 `GdUnit4`。

## 2026-03-27 第 41 轮
分支: `auto/gameplay_update`
范围: 扩主菜单弹窗状态机回归，把取消路径和禁用态压进 `GdUnit4`
变更:
- `dialogs_controller.gd` 为战斗 / 接见弹窗补了稳定节点名，测试不再依赖脆弱的匿名按钮顺序。
- `tests/godot/main_menu_flow_test.gd` 新增 4 条回归：`新局` 取消保持进度、`读档` 取消保持当前天数、战斗弹窗取消后仍停留在 `action` 阶段、低合法性时接见按钮保持禁用。
- Godot 前端 `GdUnit4` 基线从 `11/11` 提升到 `15/15`，主菜单关键取消路径现在进入自动回归。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 15/15`。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与弹窗测试锚点、`GdUnit4` 回归和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：把结局弹窗、设置链路和更多失败恢复边界继续压进 `GdUnit4`，同时观察最新 Windows CI run。

## 2026-03-27 第 42 轮
分支: `auto/gameplay_update`
范围: 把结局弹窗关键状态纳入 `GdUnit4`
变更:
- `main_menu.gd` 给控制器节点补了稳定名字，`dialogs_controller.gd` 给结局遮罩、标题、统计和重开按钮补了测试锚点。
- `tests/godot/main_menu_flow_test.gd` 新增 3 条回归：结局弹窗出现时会锁动作、重开后回到 `Day 1 / action`、结局统计显示的天数会截断到 `100`。
- Godot 前端 `GdUnit4` 基线从 `15/15` 提升到 `18/18`。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 18/18`。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与结局弹窗测试锚点、`GdUnit4` 回归和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：把设置链路和更多失败恢复边界继续压进 `GdUnit4`，并继续观察最新 Windows CI run。

## 2026-03-27 第 43 轮
分支: `auto/gameplay_update`
范围: 清理 `GdUnit4` 验证噪音，提升 Windows 回归日志可读性
变更:
- `dialogs_controller.gd` 把战斗兵力默认值改成显式浮点计算，移除整数除法 warning。
- `map_controller.gd` 修正两处局部变量遮蔽，`main_menu.gd`、`rn_slider.gd`、`turn_manager.gd` 移除几处无用变量，减少 GDScript 重载时的无效警告。
- 本轮不改测试用例数量，目标是让现有 `GdUnit4` / smoke 输出更接近“只剩真正问题”。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 18/18`。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 warning 清理和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：把设置链路和更多失败恢复边界继续压进 `GdUnit4`，并继续观察最新 Windows CI run。

## 2026-03-27 第 44 轮
分支: `auto/gameplay_update`
范围: 把“文档补强”从建议升级为正式决策，并提到当前 `P0`
变更:
- 新增 [ADR-012](/mnt/e/projects/CentJours/docs/decisions/ADR-012-developer-documentation-operability.md)，正式采纳“根 README、架构文档、接口文档、结构化 bug 文档、英文函数名渐进迁移、关键中文注释”的开发者文档基线。
- `dev_plan.md` 当前 `P0` 已前置文档补强：优先补根 `README.md`、`architecture.md`、`interfaces.md` 和 `docs/bugs/` 规范化。
- `agent_handoff.md` 当前最高优先级和已知缺口已同步到“先补人类开发者入口”的口径。
验证:
- 本轮为文档与规则轮，没有新增代码路径验证。
提交/推送:
- 本轮将与 ADR、计划和交接同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 第 2 轮直接补齐根 `README.md`、`docs/architecture.md`、`docs/interfaces.md` 三份核心文档。

## 2026-03-27 第 45 轮
分支: `auto/gameplay_update`
范围: 补齐人类开发者接手的三份核心文档
变更:
- 新增根 `README.md`，补齐项目简介、Windows-first 环境部署、测试与质量、roadmap、术语表和文档导航。
- 新增 `docs/architecture.md`，解释 `TurnManager -> CentJoursEngine -> GameState -> UI` 主结构、目录职责、主循环、数据流、Save/Load 边界和验证结构。
- 新增 `docs/interfaces.md`，整理 `TurnManager`、`CentJoursEngine`、`GameState`、Save/Load、主菜单弹窗和 CI 的核心接口契约。
- `dev_plan.md` 与 `agent_handoff.md` 已同步写明：这三份文档已经存在，当前剩余文档补强重点转为 `docs/bugs/` 规范化与导航更新。
验证:
- 本轮为文档轮，没有新增代码路径验证。
提交/推送:
- 本轮将与三份核心文档和交接同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 第 3 轮规范 `docs/bugs/`：补索引、模板、维护规则，并更新 docs 导航。

## 2026-03-27 第 46 轮
分支: `auto/gameplay_update`
范围: 收口文档补强目标，把 bug 文档制度和 docs 导航补齐
变更:
- `docs/bugs/` 新增 `bug_index.md`、`bug_template.md`，并创建首个代码问题条目 `BUG-2026-03-27-EVENTBUS-WARNINGS`。
- `README.md` 与 `docs/README.md` 已把 bug 索引纳入默认导航，文档入口链现在包含根入口、架构、接口和 bug 制度。
- `dev_plan.md` 与 `agent_handoff.md` 已切回正常开发优先级，同时把“文档补强已完成，后续进入维护期”写进当前状态。
验证:
- 本轮为文档轮，没有新增代码路径验证。
提交/推送:
- 本轮将与 bug 文档制度、导航同步和交接更新一起提交并推送到 `auto/gameplay_update`。
下一步:
- 文档补强目标闭环后，回到正常主线：继续收口 Windows CI、把剩余 bug 绑定自动化验证、扩大 `GdUnit4` 覆盖。

## 2026-03-27 第 47 轮
分支: `auto/gameplay_update`
范围: 给代码改动补文档同步门禁，并推进命名/注释治理
变更:
- 新增 `.github/workflows/doc-sync.yml` 与 `tools/check_doc_sync.py`，让 `src/`、`cent-jours-core/`、`tests/`、`tools/`、`.github/workflows/` 改动时必须同步更新 `README.md` 或 `docs/`。
- `README.md`、`dev_plan.md`、`agent_handoff.md`、`ADR-012`、`docs/interfaces.md`、`docs/architecture.md` 已同步写入新门禁，并删掉 live 文档中已经过期的“文档骨架刚补齐”表述。
- 核心代码补了高价值中文注释：`engine/state.rs`、`game_state.gd`、`save_manager.gd`、`turn_manager.gd` 现在对行军预判契约、存档迁移边界、扁平状态同步和前端缓存职责说明更明确。
- 生产函数名未发现中文残留；Rust 核心里剩余的中文函数名主要是测试，已统一改成英文，并在测试模块保留中文说明注释。
验证:
- 本地 `python3 tools/check_doc_sync.py --files ...` 通过。
- Windows `cargo test` 通过，当前基线仍为 `211/211`。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 CI 门禁、注释补强和命名治理一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把剩余高频 bug 绑定到 `GdUnit4`，并保持 README / architecture / interfaces 跟随接口变化同步维护。

## 2026-03-27 第 48 轮
分支: `auto/gameplay_update`
范围: 收紧 Windows CI 触发面，并给主菜单弹窗失败恢复补回归护栏
变更:
- `.github/workflows/windows-validation.yml` 从 `paths-ignore` 改成代码白名单 `paths`，现在只会被 `src/`、`cent-jours-core/`、`tests/`、`addons/`、`tools/run_gdunit_windows.cmd` 和自身 workflow 触发。
- `dialogs_controller.gd` 现在会在战斗弹窗和接见弹窗打开时锁住托盘交互，取消时恢复，避免 modal 打开期间继续误触主托盘。
- `tests/godot/main_menu_flow_test.gd` 新增接见弹窗取消恢复测试，并把战斗取消、低合法性接见、结局重开后的按钮可用性一起锁进回归。
- `dev_plan.md`、`agent_handoff.md`、`interfaces.md` 已同步到新触发规则和 `GdUnit4 19/19` 基线。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 19/19`。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 CI 收口、弹窗交互修正和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把设置链路和更多失败恢复边界压进 `GdUnit4`，并观察新一轮 Windows CI 排队是否继续下降。

## 2026-03-27 第 49 轮
分支: `auto/gameplay_update`
范围: 把地图详情层位置跳变与长文本滚动护栏转成正式回归
变更:
- `layout_controller.gd` 统一了 `MapHoverPanel` 与 `MapInspectorPanel` 的右上展示锚点、高度和尺寸来源，不再让 hover 预览与锁定详情各算一套几何。
- `main_menu.tscn` 显式固定 `MapHoverScroll` 与 `MapInspectorScroll` 的纵向滚动模式，避免后续布局改动把长文本护栏悄悄打掉。
- `tests/godot/map_controller_contract_test.gd` 新增地图详情层契约测试，锁住 hover / inspector 同一右上锚点、同一高度和滚动容器配置。
- `docs/bugs/` 新增 `BUG-2026-03-27-MAP-DETAIL-ANCHOR` 条目，并把问题正式挂到 bug 索引；`dev_plan.md`、`agent_handoff.md` 已同步到 `GdUnit4 20/20` 基线。
验证:
- 本地 `python3 tools/check_doc_sync.py --files ...` 通过。
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 20/20`。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与地图详情层布局收口、`GdUnit4` 回归和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：把设置链路、更多失败恢复边界和剩余 `docs/bugs` 问题继续转成自动化验证。

## 2026-03-27 第 50 轮
分支: `auto/gameplay_update`
范围: 收口主菜单 transient modal 与 `DecisionTray` 的交互竞态
变更:
- `main_menu.gd` 新增 transient modal 深度计数，统一管理 `新局`、`存档槽位`、`读档确认` 打开时的托盘锁定与关闭后的恢复。
- `main_menu_flow_test.gd` 新增 1 条回归，并加强已有取消链路断言：存档槽位打开时执行按钮禁用、取消后恢复；`新局` 取消与 `读档确认` 取消也都显式验证执行按钮恢复。
- `docs/bugs/` 新增 `BUG-2026-03-27-MAIN-MENU-MODAL-LOCK`，并把当前 Godot 基线同步到 `GdUnit4 21/21`。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 21/21`。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 modal 状态机修复、`GdUnit4` 回归和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：补设置链路和剩余失败恢复边界，并继续把 `docs/bugs` 的问题转成自动化验证。

## 2026-03-27 第 51 轮
分支: `auto/gameplay_update`
范围: 给多槽存档补齐覆盖确认、删除入口和 modal 收尾护栏
变更:
- `main_menu.gd` 的槽位弹窗改成行式布局；已有槽位保存时不再直接覆盖，而是先弹 `SaveOverwriteConfirmDialog` 二次确认。
- 已存在的存档槽位现在会在存档 / 读档弹窗里都显示删除按钮，删除前统一经过 `DeleteSaveConfirmDialog`。
- `新局`、`读档确认`、`覆盖确认`、`删除确认` 的 `confirmed` 回调都改成先显式关闭确认弹窗，再执行后续业务，避免 transient modal depth 残留导致 `DecisionTray` 卡死。
- `tests/godot/main_menu_flow_test.gd` 新增 2 条回归：已有槽位必须先覆盖确认、从读档弹窗删除存档后槽位和按钮状态同步恢复。
- `docs/bugs/` 新增 `BUG-2026-03-27-SAVE-SLOT-GUARDS`，并把 `dev_plan.md`、`agent_handoff.md` 同步到 `GdUnit4 23/23` 基线。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 23/23`。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与存档槽位交互收口、`GdUnit4` 回归和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：优先把设置链路和更多失败恢复边界继续压进 `GdUnit4`，再处理 `EventBus` 验证噪音。

## 2026-03-27 第 52 轮
分支: `auto/gameplay_update`
范围: 收掉 `EventBus` 声明型 signal 的 `GdUnit4` warning 噪音
变更:
- `event_bus.gd` 的 signal 声明区块增加 `@warning_ignore_start("unused_signal")` / `@warning_ignore_restore("unused_signal")`，只精准屏蔽这类集中声明信号带来的静态检查噪音。
- `BUG-2026-03-27-EVENTBUS-WARNINGS` 已从待处理改成已修复，`bug_index.md` 同步补上回归方式。
- `dev_plan.md` 与 `agent_handoff.md` 已同步到新状态：`EventBus` warning 不再是当前 Windows `GdUnit4` / CI 日志里的主要噪音来源。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 手工复核 `GdUnit4` 日志，确认 `EventBus` 的 `unused_signal` warning 已消失。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 `EventBus` 噪音修复和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：把设置链路和更多失败恢复边界继续压进 `GdUnit4`，避免自动化只覆盖“成功路径”。

## 2026-03-27 第 53 轮
分支: `auto/gameplay_update`
范围: 补主菜单失败恢复回归，收口存档确认取消链和 battle/boost 提交失败链
变更:
- `main_menu.gd` 的覆盖确认 / 删除确认改成显式“先关闭确认框，再回到对应槽位选择框”的流转，不再依赖嵌套 transient modal 的副作用维持托盘锁定。
- `main_menu.gd` 的 transient popup 关闭逻辑补上 `is_instance_valid()` 护栏，避免确认链里对已释放 popup 重复调用。
- `dialogs_controller.gd` 现在会保留 `submit_action` 回调的布尔结果；战斗和接见提交失败时，主菜单会恢复 `DecisionTray` 交互，不再把玩家卡在半关闭 modal 状态。
- `tests/godot/main_menu_flow_test.gd` 新增 4 条回归：覆盖确认取消返回槽位选择框、删除确认取消返回槽位选择框、战斗提交失败恢复交互、接见提交失败恢复交互。
- `bug_save_slot_overwrite_and_delete.md` 与 `bug_main_menu_modal_tray_lock.md` 已同步补充这轮的取消路径与失败恢复护栏；`dev_plan.md`、`agent_handoff.md` 已同步到 `GdUnit4 27/27` 基线。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 27/27`。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与主菜单失败恢复修复、`GdUnit4` 回归和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：把设置入口、更多地图交互边界和剩余失败恢复链继续压进 `GdUnit4`。

## 2026-03-27 第 54 轮
分支: `auto/gameplay_update`
范围: 补最小设置系统，并把设置入口从计划项变成可验证功能
变更:
- 新增 `src/core/settings_manager.gd`，负责默认值、归一化、`ConfigFile` 读写和把窗口模式 / 界面缩放应用到当前窗口。
- `main_menu.gd` 顶栏新增 `设置` 入口；设置弹窗现已支持窗口模式、界面缩放、应用、恢复默认和取消。
- 新增 `tests/godot/settings_manager_test.gd`；`main_menu_flow_test.gd` 也补了设置弹窗的打开/取消/读取已保存值/应用持久化回归。
- `README.md`、`interfaces.md`、`dev_plan.md`、`agent_handoff.md` 已同步到“最小设置入口已落地，Godot 前端 `GdUnit4 33/33`”的新基线。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 33/33`。
- 本轮 `settings_manager.gd` 的 enum warning 已一并收口，没有把新噪音带回日志。
- Windows Godot 无头主项目通过。
- Windows Godot smoke scene 通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与设置系统、`GdUnit4` 回归和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：补 Windows 主项目 / smoke 验证并提交这轮设置包；完成后继续收口更多地图交互边界。

## 2026-03-27 第 55 轮
分支: `auto/gameplay_update`
范围: 扩地图交互边界回归，把常见误操作路径锁进 `GdUnit4`
变更:
- `tests/godot/map_controller_contract_test.gd` 新增 4 条地图边界回归：锁定后忽略其他节点 hover、重复点击同节点取消锁定、点击空白画布清空交互、右键缩放复位保持锁定。
- 这轮没有改生产代码，说明当前 `map_controller.gd` 的交互状态机已经能满足这组真实误操作路径。
- `dev_plan.md` 与 `agent_handoff.md` 已同步到 `GdUnit4 37/37` 基线，并把这组地图交互边界写成当前真值。
验证:
- Windows `tools\\run_gdunit_windows.cmd` 通过，`GdUnit4 37/37`。
- 本轮未改生产代码，因此未重复跑 Windows Godot 主项目 / smoke scene。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与地图交互回归扩展和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续按当前 `P0` 推进：优先把更多地图行动边界或 CI 结果继续压成可重复验证。
