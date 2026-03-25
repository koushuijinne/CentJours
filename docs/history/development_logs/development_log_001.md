# 开发日志 001

从旧版在线文档中抽离出的多轮开发历史整理稿；后续轮次继续追加到 `development_logs/`。

## 2026-03-24 第 1 轮
分支: `claude/review-project-status-05vxD`
范围: 主循环稳定化与基线整合
变更:
- `main_menu.tscn` 被收口为正式 Godot 入口。
- 运行链路 `TurnManager -> engine -> state -> UI` 从原型骨架提升为真实主循环。
- Save / Load、行动日志和历史事件展示路径被接入真实游戏流程。
- 项目从“核心原型”推进到可运行的回合制游戏闭环。
验证:
- 规则层改动后重新跑了 Rust 测试。
- 用主循环启动检查确认项目能通过预期入口正常启动。
提交/推送:
- 本轮增量改动已在当前分支提交并推送。
下一步:
- 继续扩充事件内容，并持续收紧历史呈现层。

## 2026-03-24 第 2 轮
分支: `claude/review-project-status-05vxD`
范围: 历史事件扩充与时间线补密
变更:
- 事件池补入了后期事件和联军协同内容。
- 终盘战役与政治事件被加入，以提高百日时间线后半段的密度。
- 晚期 `minor` 事件覆盖被显式保护，避免事件池尾段过稀。
- 文档中的历史内容基线随事件扩充一并上调。
验证:
- 通过 `cargo test` 保护事件池与时间线规则。
- 扩容后检查了事件数量与 tier 数量回归。
提交/推送:
- 内容增量与本轮其余改动一起提交并推送。
下一步:
- 继续扩写事件池，并补齐剩余史实缺口。

## 2026-03-24 第 3 轮
分支: `claude/review-project-status-05vxD`
范围: 历史文本 QA 与 ADR-008 风格清理
变更:
- 重写了一批历史注释和叙事段，清掉 reframing 过重的句式。
- 多条事件条目被收紧，信息密度更高，文学性填充更少。
- 文案规则转向直接、可核对的写法，不再使用“先设错再纠正”的表达。
- 事件文本和规则数据里造成表达混乱的负 bonus 用法被清理。
验证:
- 为历史事件池新增了文案护栏回归测试。
- 文案清理后项目测试基线保持绿色。
提交/推送:
- 文案 QA 清理已随本轮分支历史一起提交并推送。
下一步:
- 继续把同样的直写标准应用到剩余政治与外交事件。

## 2026-03-24 第 4 轮
分支: `claude/review-project-status-05vxD`
范围: UI 打磨与验证链路加固
变更:
- `DecisionTray` 被收口为更稳定的横向滚动模型。
- `Map Inspector` 增加了内部滚动和更响应式的布局。
- 行动结果日志被收紧，使回合后果在 UI 中更清楚。
- 显示名处理被统一，让前端和引擎都使用同一套可读标签。
验证:
- UI 桥接和日志链路改动后重新跑了 Rust 测试。
- 用 Windows Godot 无头和 smoke 检查确认 UI 侧集成仍能正常加载。
提交/推送:
- UI 打磨改动已在同一开发流程中提交并推送。
下一步:
- 收口剩余视觉问题，并持续在 Windows Godot 上验证。

## 2026-03-24 第 5 轮
分支: `claude/review-project-status-05vxD`
范围: 分支整合、存档迁移与基线交接
变更:
- `codex/0323-auto` 的实现基线被整合回当前活动分支。
- `fontainebleau_eve` 被正式更名为 `tuileries_eve`。
- Save / Load 进入 `v2` 兼容路径，旧存档可以迁移到新事件 ID。
- 终盘事件时间窗口被对齐到最终时间线，事件池测试也同步更新。
验证:
- `cargo test` 达到当前 `168/168` 全通过基线。
- 存档迁移与终盘时间线回归被纳入更新后的测试覆盖。
提交/推送:
- 整合工作已在 `claude/review-project-status-05vxD` 上提交并推送。
下一步:
- 继续以这个分支为主开发线，把事件内容往 `100+` 目标推进。

## 2026-03-24 第 6 轮
分支: `claude/review-project-status-05vxD`
范围: 将开发历史抽离到新的 `docs/history/` 结构
变更:
- 多轮开发历史被从当前计划文档和交接文档中抽离出来。
- 新建了专门的开发日志，用于集中存放逐轮进展。
- 补了一个简洁的历史文档索引，让 `history` 目录有清晰入口。
验证:
- 新日志保持在 `500` 行上限以内。
- 历史索引已指向最新开发日志。
提交/推送:
- 这次历史抽离工作作为单独文档轮次记录。
下一步:
- 当当前日志接近 `500` 行时，改写到下一份日志文件。

## 2026-03-24 第 7 轮
分支: `claude/review-project-status-05vxD`
范围: 文档分类重构、agent 命名统一与中文正文收口
变更:
- 文档被整理为 `plans / rules / history / decisions` 四类目录，相关文件完成迁移与重命名。
- `agent_handoff`、`development_plan`、`agent_session_prompts`、`agent_session_rules` 和可选自动工作流都按新边界重写。
- `development_logs` 被确立为唯一的多轮开发历史承载位置，`README` 导航也已补齐。
- 正文说明优先统一为中文，保留分支名、路径、命令和事件 ID 等技术标识不翻译。
验证:
- 已清理旧路径引用，确认仓库中不再残留 `docs/codex_*`、`docs/dev_plan.md`、`plan.md`、`CLAUDE.md` 等旧入口引用。
- `docs/history/development_logs/development_log_001.md` 当前为 `111` 行，低于 `500` 行上限。
提交/推送:
- 本轮将作为文档重构提交推送到当前分支。
下一步:
- 回到内容主线，继续扩充历史事件并推进文本 QA 与发布收口。

## 2026-03-24 第 8 轮
分支: `auto/gameplay_update`
范围: 把补给压力真正接进回合循环
变更:
- 读取 `agent_chat_history` 后，明确把“补给 / 后勤”作为本轮最小可闭环的玩法创新切口，而不是继续停留在纯内容扩写。
- 主菜单顶栏已显示补给值，`GameState` 和 `TurnManager` 也能从 `engine.get_state()` 同步补给状态。
- Rust 侧把补给正式接进核心循环：补给进入 `SaveState`、`get_state()`、休整恢复、战斗补给惩罚、行军后补给刷新和每日行动结算日志。
- 行军补给公式从占位实现改成可用的前线压力模型：高容量后方节点能明显回补，低容量前线节点会持续消耗补给。
- 补了回归测试，覆盖旧存档缺少补给字段、低补给休整更弱、行军会改变补给、高低容量节点补给差异等新行为。
验证:
- `cd cent-jours-core && cargo test` 通过，测试基线从 `168` 提升到 `172`。
- `cd cent-jours-core && cargo build --features godot-extension` 通过，但当前环境只更新了 Linux `.so`。
- Windows Godot 无头主项目启动和 `engine_smoke_test_scene.tscn` 仍能运行。
- 已确认当前环境没有 `x86_64-pc-windows-gnu` target，所以 Windows 无头本轮加载的是旧 `cent_jours_core.dll`，不能把它当作新 Rust 扩展逻辑已验证。
提交/推送:
- 本轮将与文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把补给系统从“后台压力”推进到“明确玩法”：补给来源、前线惩罚、玩家可控补给手段与失败反馈。

## 2026-03-24 第 9 轮
分支: `auto/gameplay_update`
范围: 把补给玩法从“被动承压”推进到“玩家可控”
变更:
- 新增补给政策 `requisition_supplies / 征用沿线仓储`，把“补给短缺时你能做什么”从纯后台计算推进成玩家可执行操作。
- Rust 侧把该政策接入政治表、引擎执行、行动结算、叙事映射和蒙特卡洛策略；政策结算会显式展示补给变化。
- 叙事池补入了这张政策对应的司汤达文本和后果文本，避免新政策落成后只有数值没有氛围。
- UI 元数据侧补齐了政策名称、摘要、图标、卡片效果和托盘顺序。
- 自动工作流规则也被上调：每轮提交后必须先在对话里输出一份完整压缩摘要，然后直接进入下一轮，不能把摘要当停机点。
验证:
- `cargo test` 通过，基线从 `172` 提升到 `174`。
- Windows Godot 无头主项目启动通过。
- Windows Godot smoke scene 仍可运行，但当前环境没有重新产出新的 Windows `cent_jours_core.dll`，因此它不能证明本轮新增 Rust 扩展逻辑已在 Windows 运行时生效。
提交/推送:
- 本轮将与规则和计划文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续补“前置反馈”这一刀：让玩家在行军前就能看到补给压力预测，而不是只在结算后补看数字。

## 2026-03-24 第 10 轮
分支: `auto/gameplay_update`
范围: 给行军加入前置补给预判
变更:
- 地图行军预览现在会根据目标节点的 `supply_capacity` 和当前库存，直接提示“补给压力很高 / 偏高 / 可维持 / 有望回升”。
- 低容量前线节点会在确认前就给出风险提示，不再要求玩家只能等结算后再看补给数字变化。
- 默认的 `march` 侧栏说明也同步补上了补给压力提示，让这套玩法至少有第一层教学。
验证:
- Windows Godot 无头主项目启动通过，说明主入口脚本链和 UI 预览改动没有打断加载。
- 这轮是轻量 UI 预判，没有新增 Rust 权威接口，因此当前提示仍属于近似反馈，不是引擎级精确预测。
提交/推送:
- 本轮将与交接和计划文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 把轻量预判升级成 Rust 权威预测，或者继续增加第二张补给杠杆卡，让后勤玩法不只停留在“看风险提示”。

## 2026-03-24 第 11 轮
分支: `auto/gameplay_update`
范围: 把行军前补给预判升级为 Rust 权威预测
变更:
- Rust 侧新增了 `preview_march()` 只读接口，在不推进回合的前提下直接返回目标节点行军后的预计补给、疲劳和士气。
- `TurnManager` 补上了 GDScript 桥接，主菜单地图控制器会优先读取引擎返回的预测结果，不再只靠前端近似规则猜压力。
- 地图行军反馈现在会明确显示预计补给变化、预计疲劳变化和预计士气变化，风险提示也改为基于真实投影结果判断。
- 计划文档与交接文档已同步到新口径：当前缺口从“把预判做成权威值”转成“把补给反馈做得更可操作、更有教学性”。
验证:
- `cd cent-jours-core && cargo fmt` 通过。
- `cd cent-jours-core && cargo test` 通过，基线从 `174` 提升到 `175`。
- `cd cent-jours-core && cargo build --features godot-extension` 通过，但当前环境只更新了 Linux `.so`。
- Windows Godot 无头主项目启动通过，说明新增接口没有打断项目加载。
- 当前环境仍未安装 `x86_64-pc-windows-gnu` target，所以本轮还不能证明新的 Rust GDExt 行为已经通过新 Windows DLL 进入运行时。
提交/推送:
- 本轮将以“权威行军预判”单独提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把补给玩法从“能看见风险”推进到“能理解风险、能主动反制风险”，优先补失败解释、教学提示和第二层玩家杠杆。

## 2026-03-24 第 12 轮
分支: `auto/gameplay_update`
范围: 把补给风险从“结果提示”推进到“原因拆解”
变更:
- Rust 行军预览新增了仓储容量、补给线效率、预计可得量和需求字段，让 UI 不再只给结果分级，而是能解释风险来源。
- 地图行军反馈现在会同时显示“原因”和“建议”，明确告诉玩家是低容量前线、补给线过长，还是可得量低于部队需求。
- 这轮没有再加新状态机，而是把现有补给系统、已有的 `requisition_supplies` 政策和权威预判串成更可读的决策提示。
- 计划文档与交接文档已同步到新口径：当前主缺口不再是“看不见风险”，而是“第二层补给杠杆”和“前 10 天教学”。
验证:
- `cd cent-jours-core && cargo fmt` 通过。
- `cd cent-jours-core && cargo test` 通过，基线保持 `175/175`。
- `cd cent-jours-core && cargo build --features godot-extension` 通过，但当前环境只更新了 Linux `.so`。
- Windows Godot 无头主项目启动通过，说明新增预览字段没有打断主项目加载。
- 从 WSL 调 Windows `cargo build --features godot-extension` 仍报 `UtilBindVsockAnyPort`，`engine_smoke_test_scene.tscn` 也被同一类宿主互操作错误卡住；因此本轮仍不能宣称新的 Windows DLL 已完成运行时验证。
提交/推送:
- 本轮将以“补给风险解释增强”单独提交并推送到 `auto/gameplay_update`。
下一步:
- 继续补第二层补给杠杆，优先做能和现有补给线效率直接耦合的玩家可控政策，再回头补前 10 天教学。

## 2026-03-24 第 13 轮
分支: `auto/gameplay_update`
范围: 把补给失败归因推进到行动后结算日志，并上调自动工作流禁收尾规则
变更:
- `refresh_supply_after_action()` 现在不仅写补给变化，还会把节点容量、需求 / 可得量和下一步建议一起写入结算日志。
- 侧栏日志里的 `supply` 事件现在被明确标记为“补给结算”，不再混成泛化的行动结算。
- 新增回归测试，保证补给结算会保留“节点容量”和“建议”两类教学信息。
- 自动工作流文档的最高优先级规则新增了一条硬约束：除非项目已经达到可进入 Steam 提审 / 发版收口的程度，否则不允许把压缩摘要、阶段性汇报或提交结果当作收尾。
验证:
- `cd cent-jours-core && cargo fmt` 通过。
- `cd cent-jours-core && cargo test` 通过，基线从 `175` 提升到 `176`。
- Windows Godot 无头主项目启动通过。
- 本轮没有补上 Windows 新 DLL 运行时验证；当前 WSL 宿主互操作仍会阻断 Windows `cargo build` 与 smoke scene。
提交/推送:
- 本轮将以“补给失败归因增强”单独提交并推送到 `auto/gameplay_update`。
下一步:
- 继续补第二层补给杠杆，优先做直接影响补给线效率的玩家可控政策，而不是继续只加说明文字。

## 2026-03-24 第 14 轮
分支: `auto/gameplay_update`
范围: 补上第二层补给杠杆“整顿驿站运输”
变更:
- 新增政策 `stabilize_supply_lines / 整顿驿站运输`，效果是小幅立即回补补给，并在接下来数日提供临时补给线效率加成。
- 这项加成没有另起第二套补给系统，而是直接接入现有 `supply_line_efficiency()`、行军预判、行动后补给结算和存档读写。
- 政策结算会显式写出“补给线效率 +18%（3 天）”，并在后续每日结算中自动衰减归零。
- UI 元数据、叙事映射、Monte Carlo 策略和两份叙事 JSON 都已补齐，新政策不会变成只有数值没有氛围的空壳。
验证:
- `cd cent-jours-core && cargo fmt` 通过。
- `cd cent-jours-core && cargo test` 通过，基线从 `176` 提升到 `178`。
- Windows Godot 无头主项目启动通过。
- 本轮仍未补上 Windows 新 DLL 运行时验证；当前 WSL 宿主互操作错误仍会阻断 Windows `cargo build` 与 smoke scene。
提交/推送:
- 本轮将以“新增补给线整顿政策”单独提交并推送到 `auto/gameplay_update`。
下一步:
- 把补给玩法继续往“前 10 天教学”和“补给来源差异”推进，不再只做单点说明或单张政策。

## 2026-03-24 第 15 轮
分支: `auto/gameplay_update`
范围: 把前 10 天补给教学嵌进政策预览
变更:
- 侧栏政策预览现在会根据当前补给值和前 10 天阶段，分别给 `requisition_supplies`、`stabilize_supply_lines` 和 `rest` 输出不同建议。
- 教学重点不再只是“这张卡做什么”，而是“什么时候该打哪张卡”：危险区先止血、连续北上前先保线、补给过低时休整恢复会打折。
- 这轮没有改 Rust 规则层，只把已有两张补给政策和补给恢复逻辑转成更直接的 UI 指引。
验证:
- Windows Godot 无头主项目启动通过。
- 本轮没有新增 Rust 逻辑，因此没有重跑 `cargo test`；当前 Rust 基线仍是上一轮确认的 `178/178`。
提交/推送:
- 本轮将以“情境化补给教学提示”单独提交并推送到 `auto/gameplay_update`。
下一步:
- 继续补“补给来源差异”，让节点和区域不只是容量不同，而是形成更清楚的阶段性后勤地图。

## 2026-03-24 第 16 轮
分支: `auto/gameplay_update`
范围: 收紧自动工作流规则，强制放大单轮切片并明确子 agent 加速边界
变更:
- 重构了 `agent_autonomous_workflow.md` 的文档结构，把启用条件、最高优先级规则、子 agent 策略、循环步骤、阻塞处理和验证矩阵重新收口。
- 把“单轮默认先做完整功能包”提升到最高优先级，明确规定除主链路阻塞修复外，一轮至少覆盖规则 / UI / 验证 / 文档中的三层。
- 把“任务过小先打包相邻子任务再开工”写成硬规则，避免自动循环退化成连续小修。
- 把子 agent 的适用场景、写入边界、独占文件范围、回收要求写清楚，避免继续出现开了子 agent 却没有形成有效并行收益的情况。
- `agent_handoff` 同步加入了新的接手约束，后续会话可以直接按大切片节奏继续。
验证:
- 本轮是规则与交接文档重构，没有改动运行时代码或测试基线。
- 已人工检查文档结构，确认“禁收尾”“单轮做大”“子 agent 回收”三类规则都位于最高优先级区域。
提交/推送:
- 本轮将以“自动工作流规则收紧与精简”单独提交并推送到 `auto/gameplay_update`。
下一步:
- 按新规则直接做更大的补给玩法切片，优先把“补给来源差异”做成规则层、地图检查器、预判反馈和可视化一起落地的完整功能包。

## 2026-03-24 第 17 轮
分支: `auto/gameplay_update`
范围: 收紧自动工作流验证边界，禁止 Linux / WSL 侧测试补位
变更:
- `agent_autonomous_workflow.md` 新增最高优先级规则：自动工作流不再运行 Linux / WSL 侧测试，不再把 Linux `cargo test` 或 Linux Godot 无头当成默认验证手段。
- `agent_handoff.md` 和 `development_plan.md` 的验证章节同步改口径：Windows 验证不完整时，要明确写“未验证”，不能再用 Linux 结果补位。
- 这一轮把验证策略从“Windows 优先”收紧为“Windows 专用”，避免后续自动循环反复回到错误平台。
验证:
- 本轮是规则文档收紧，没有新增运行时代码变更。
- 后续轮次只接受 Windows 侧构建、Windows 无头和 Windows 真机作为默认验证来源。
提交/推送:
- 本轮将与当前进行中的开发轮次一起提交并推送。
下一步:
- 继续完成当前补给玩法切片的 Windows 侧验证与文档同步，不再追加 Linux / WSL 测试。

## 2026-03-24 第 18 轮
分支: `auto/gameplay_update`
范围: 把补给来源差异做成完整功能包：前沿粮秣站、补给角色、补给枢纽和地图可视化
变更:
- 新增政策 `establish_forward_depot / 建立前沿粮秣站`，它会在当前驻地留下短期容量加成，并把这层状态接进存档、行军预判、行动后补给结算、政策叙事和地图表现。
- Rust 行军层为节点补入补给角色语义，区分前沿消耗点、沿线转运点、区域仓储和战略枢纽；地图检查器和行军预判会直接展示补给角色、有效容量、最近补给枢纽与跳数。
- 地图渲染新增轻量后勤标记，玩家能直接看见前沿粮秣站、高容量枢纽和低容量前线点，不再只从数字猜后勤地形。
- Save / Load 升到 `v3`，前沿粮秣站的地点、容量加成和剩余天数都会保留；计划文档、交接文档和自动工作流规则也同步改成“Windows 专用验证，不接受 Linux / WSL 补位”。
验证:
- Windows 原生 `cargo build --features godot-extension` 已通过。
- Windows Godot 无头主项目启动已通过。
- Windows Godot smoke scene 已通过，并确认新的前沿粮秣站状态字段进入运行时。
- 本轮不使用 Linux / WSL 侧测试结果作为验证结论。
提交/推送:
- 本轮将与当前功能包代码一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把补给系统从“看得见来源差异”推进到“有更强的阶段目标和长线运营感”，优先补状态面板、阶段目标和前线推进节奏。

## 2026-03-24 第 19 轮
分支: `auto/gameplay_update`
范围: 把后勤态势和阶段目标做成引擎权威状态，并统一投到侧栏、决策区和地图副标题
变更:
- `engine/state.rs` 新增后勤态势与阶段目标推导，按补给、疲劳、驻地容量、补给枢纽距离和前沿粮秣站状态，区分止血整补、前沿整补跳板、前线消耗区、运输线拉长和可继续推进等姿态。
- `lib.rs`、`turn_manager.gd` 和 `game_state.gd` 现在会同步 `logistics_posture_*` 与 `logistics_focus_*` 字段，GDScript 不再自己猜当前后勤目标。
- 侧栏态势区现在会直接显示后勤态势、阶段目标、补给与疲劳；决策区提示和地图副标题也会复用同一条简要建议。
- 自动工作流文档补入了 4 条子 agent 硬约束：触发阈值、回传格式、失败回收和无稳定原语时的降级策略。
验证:
- `cargo fmt --manifest-path cent-jours-core/Cargo.toml` 已通过。
- Windows `cargo test` 已通过，基线提升到 `185/185`。
- Windows `cargo build --features godot-extension` 已通过。
- Windows Godot 无头主项目和 smoke scene 已通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与功能代码、规则文档和交接文档一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把补给系统从“知道当下该做什么”推进到“能看见几回合后的代价与窗口”，优先补前线推进节奏和更明确的阶段目标反馈。

## 2026-03-24 第 20 轮
分支: `auto/gameplay_update`
范围: 把前线推进节奏做成补给窗口提示
变更:
- 引擎新增了当前驻地和行军落点的补给窗口推导，直接给出“当前节点可持续维持”“约还能维持 N 天”或“已在战斗惩罚区”等权威结论。
- `lib.rs`、`turn_manager.gd` 和 `game_state.gd` 现在会同步 `logistics_runway_*` 与 `supply_runway_days` 字段；GDScript 不再自己估算前线能撑几天。
- 侧栏态势区、地图检查器和行军预判都接入了补给窗口提示，玩家能在决策前看到当前位置和目标位置的时间余量。
- 这一轮没有新增补给政策，而是把已有三张牌放进更可运营的多回合节奏里。
验证:
- `cargo fmt --manifest-path cent-jours-core/Cargo.toml` 已通过。
- Windows `cargo test` 已通过，基线提升到 `187/187`。
- Windows `cargo build --features godot-extension` 已通过。
- Windows Godot 无头主项目和 smoke scene 已通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与功能代码和文档同步一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把补给系统从“能看见几天后会出事”推进到“会提前提醒哪几步组合最危险”，优先补多回合推进成本和失败归因串联。

## 2026-03-24 第 21 轮
分支: `auto/gameplay_update`
范围: 把第二跳推进风险做成引擎权威预判，并收紧自动工作流收尾约束
变更:
- `engine/state.rs` 新增“单步投影 + 第二跳评估”模型；行军预判现在会直接算出落点后的可继续推进路线总数、其中相对稳妥的路线数、最稳后续节点，以及是否已经走进前线补给陷阱。
- `lib.rs`、`turn_manager.gd` 和 `map_controller.gd` 已接通新字段；地图行军提示不再只显示落点补给窗口，而会直接解释“这一步之后还有没有稳妥第二跳”。
- 新增两条 Rust 回归，分别钉住“高容量落点仍保留第二跳机动余地”和“低容量前线落点会暴露第二跳陷阱”。
- `agent_autonomous_workflow.md` 已精简最高优先级规则，只保留死循环推进和单轮工作范围约束；同时补上“每轮结束前回看 `agent_session_rules.md`”和“压缩摘要必须覆盖整个上下文窗口”。
- `agent_session_rules.md` 也已补上硬要求：每轮结束前必须把整个上下文窗口的压缩摘要输出到对话里，防止后续压缩卡住。
验证:
- `cargo fmt --manifest-path cent-jours-core/Cargo.toml` 已通过。
- Windows `cargo test` 已通过，基线提升到 `189/189`。
- Windows `cargo build --features godot-extension` 已通过。
- Windows Godot 无头主项目和 Windows Godot smoke scene 已通过。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与功能代码、规则文档和当前态文档一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把补给系统从“知道第二跳危险不危险”推进到“主动给出区域整补目标和前线推进节奏”，优先补区域运营目标、前 10 天教程串联和更强的失败归因。

## 2026-03-24 第 22 轮
分支: `auto/gameplay_update`
范围: 把阶段运营目标做成引擎权威状态，并接进侧栏、地图副标题和行军预判
变更:
- `engine/state.rs` 新增阶段运营目标推导：不同日期、补给状态、驻地容量和运输线距离会导向不同的节点层级目标，例如“先抢区域整补点”“把跳板接到战略大仓”“只为决定性前线点付补给代价”。
- `lib.rs`、`game_state.gd`、`turn_manager.gd`、`main_menu.gd`、`sidebar_controller.gd` 和 `map_controller.gd` 已接通新字段；侧栏会显示当前运营目标，地图副标题和决策区提示也会复用这层信息。
- 行军预判现在不只解释风险，还会直接判断这一步是否在朝当前需要的节点层级推进，告诉玩家是“符合阶段目标”“还在铺路”还是“偏离当前更需要的仓储层级”。
- 新增两条 Rust 回归，分别钉住“前10天前线消耗区会要求先抢区域整补点”和“终盘推进窗口会把目标切到决定性前线点”。
验证:
- `cargo fmt --manifest-path cent-jours-core/Cargo.toml` 已通过。
- Windows `cargo test` 已通过，基线提升到 `191/191`。
- Windows `cargo build --features godot-extension` 已通过。
- Windows Godot 无头主项目和 Windows Godot smoke scene 已通过；smoke 输出已确认新 `logistics_objective_*` 字段进入运行时。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与功能代码和当前态文档一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把补给系统从“知道该往哪类节点走”推进到“前 10 天教程会主动串起政策、行军、整补与失败归因”，优先补教程链和失败复盘。

## 2026-03-24 第 23 轮
分支: `auto/gameplay_update`
范围: 把前 10 天后勤教程链和终局后勤复盘接进现有 UI
变更:
- `main_menu.gd` 现在会在前 10 天优先输出教程化的 `tray_hint`，按当前补给窗口、阶段运营目标和补给状态，直接提示“先抢整补点”“先补给/休整”“跳板接好后再考虑战役”。
- `dialogs_controller.gd` 的终局状态快照新增了补给、最后位置、后勤态势、阶段运营目标和补给窗口；终局复盘不再只看合法性、胜场和兵力，也会解释你是不是把后勤节奏压垮了。
- 这一轮没有再扩新规则层，而是把前两轮已经做出的后勤信号真正串成教程和失败归因，避免信息存在但玩家学不会用。
验证:
- Windows Godot 无头主项目已通过。
- Windows Godot smoke scene 已通过。
- 本轮没有改 Rust 代码，因此没有重跑 `cargo test`；当前最近一次 Rust 基线仍是 Windows `191/191`。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 GDScript 改动和当前态文档一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把后勤产品化从“会提示你怎么走”推进到“会提示你该打哪张牌、何时打、为什么输了”，优先补政策级失败复盘和更明确的日内教学步骤。

## 2026-03-24 第 24 轮
分支: `auto/gameplay_update`
范围: 把补给三张牌的即时建议和政策级失败复盘接进现有 UI
变更:
- `sidebar_controller.gd` 现在会给 `requisition_supplies`、`stabilize_supply_lines`、`establish_forward_depot` 和 `rest` 输出“优先 / 可考虑 / 暂缓”的即时建议，不再只解释这张牌做什么，而是直接说明当前该不该打。
- 这层建议会读取当前补给、补给窗口、后勤态势、阶段运营目标和已有粮秣站状态，把“止血”“保线”“铺跳板”拆成不同场景。
- `dialogs_controller.gd` 的终局复盘现在会把失败归因落到具体补给牌和节奏错误，例如征用仓储打晚、运输线该保没保、该铺粮秣站时继续赌前线点。
- 这一轮没有改 Rust 规则层，而是把已有的后勤状态真正翻译成玩家可执行的政策判断。
验证:
- Windows Godot 无头主项目已通过。
- Windows Godot smoke scene 已通过。
- `git diff --check` 已通过。
- 本轮没有改 Rust 代码，因此没有重跑 `cargo test`；当前最近一次 Rust 基线仍是 Windows `191/191`。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与 GDScript 改动和当前态文档一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把后勤产品化从“会告诉你该打哪张牌”推进到“会告诉你为什么这一步输、下一局该如何修正”，优先补更强的失败复盘结构和日内步骤教学。

## 2026-03-24 第 25 轮
分支: `auto/gameplay_update`
范围: 把后勤目标升级成“当日行动计划”，并接进侧栏、行军预判和终局复盘
变更:
- `engine/state.rs` 新增当日行动计划推导：根据后勤态势、阶段目标、相邻节点和当前库存，直接生成“优先动作 / 备选动作 / 推荐行军目标”。
- `lib.rs`、`game_state.gd`、`turn_manager.gd`、`main_menu.gd`、`sidebar_controller.gd`、`map_controller.gd`、`dialogs_controller.gd` 已接通新字段；侧栏会显示完整行动计划，`DecisionTray` 提示和地图副标题会优先复用短建议，行军预判会额外判断这一步是否符合当前主建议，终局复盘也会直接给出“若再多一步，更稳的操作会是什么”。
- 新增三条 Rust 回归，分别钉住“低补给时优先征用仓储”“运输线拉长时优先整顿运输”“前10天开局会直接给出可执行行军目标”。
- `agent_autonomous_workflow.md` 已进一步精简最高优先级规则，并把“自动循环默认不停、每轮结束后都必须立即进入下一轮”写死；`agent_handoff.md` 也同步收口为同一口径。
验证:
- `cargo fmt --manifest-path cent-jours-core/Cargo.toml` 已通过。
- Windows `cargo test` 已通过，基线提升到 `194/194`。
- Windows `cargo build --features godot-extension` 已通过。
- Windows Godot 无头主项目和 Windows Godot smoke scene 已通过；smoke 输出已确认新 `logistics_action_plan_*` 字段进入运行时。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与功能代码、规则文档和当前态文档一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把后勤产品化从“知道今天该怎么做”推进到“知道未来两三天怎么排动作和节点节奏”，优先补更强的区域运营节拍和连续多日补给计划。

## 2026-03-24 第 26 轮
分支: `auto/gameplay_update`
范围: 把单日建议扩成三日后勤节奏，并接进 UI 与终局复盘
变更:
- `engine/state.rs` 新增三日后勤节奏推导：会基于当前后勤态势、阶段目标、推荐行军目标和第二跳承接，直接生成“今天 / 明天 / 后天”的动作顺序。
- `lib.rs`、`game_state.gd`、`turn_manager.gd`、`main_menu.gd`、`sidebar_controller.gd`、`map_controller.gd`、`dialogs_controller.gd` 已接通新字段；侧栏会显示完整三日节奏，`DecisionTray` 提示会优先复用短摘要，行军预判会判断当前选点是否符合这条三日主线，终局复盘也会把“若提前两三天开始修正节奏”写进失败解释。
- 新增两条 Rust 回归，分别钉住“节奏计划会给出完整三日安排”和“低补给时三日节奏会先止血再整补”。
- 本轮还顺手补全了终局弹窗快照，把主建议与三日节奏字段一起传入 `dialogs_controller`，避免运行时读到空值。
验证:
- `cargo fmt --manifest-path cent-jours-core/Cargo.toml` 已通过。
- Windows `cargo test` 已通过，基线提升到 `196/196`。
- Windows `cargo build --features godot-extension` 已通过。
- Windows Godot 无头主项目和 Windows Godot smoke scene 已通过；smoke 输出已确认新 `logistics_tempo_plan_*` 字段进入运行时。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与功能代码和当前态文档一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把补给系统从“三日建议”推进到“区域运营节拍”，优先补更明确的连续多日节点链和阶段性前线推进模板。

## 2026-03-24 第 27 轮
分支: `auto/gameplay_update`
范围: 把三日节奏继续扩成“区域运营链路”，给出连续节点承接线
变更:
- `engine/state.rs` 新增区域运营链路推导：会基于当前驻地、阶段目标、推荐主动作和后续承接点，直接生成“当前节点 -> 下一跳 -> 后续承接点”的推荐节点线；低补给时会先止血，再重新接回链路。
- `lib.rs`、`game_state.gd`、`turn_manager.gd`、`main_menu.gd`、`sidebar_controller.gd`、`map_controller.gd`、`dialogs_controller.gd` 已接通新字段；侧栏会显示完整链路说明，`DecisionTray` 提示和地图副标题会优先复用短摘要，行军预判会判断当前落点是否仍在主运营线上，终局复盘也会给出“如果早几天按这条线铺开”的回看建议。
- 新增两条 Rust 回归，分别钉住“区域运营链路会给出推荐节点线”和“低补给时会先止血再接路线”，把这层线路逻辑固定到状态机测试里。
验证:
- `cargo fmt --manifest-path cent-jours-core/Cargo.toml` 已通过。
- Windows `cargo test` 已通过，基线提升到 `198/198`。
- Windows `cargo build --features godot-extension` 已通过。
- Windows Godot 无头主项目和 Windows Godot smoke scene 已通过；smoke 输出已确认新 `logistics_route_chain_*` 字段进入 Windows 运行时。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将与功能代码和当前态文档一起提交并推送到 `auto/gameplay_update`。
下一步:
- 继续把补给系统从“能看出一条运营线”推进到“能管理一片运营区”，优先补更强的区域压力、阶段任务和中期运营反馈。
