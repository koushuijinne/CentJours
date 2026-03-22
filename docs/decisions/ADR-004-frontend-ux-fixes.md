# ADR-004: 前端 UX 修复与视觉质量提升

## 状态: 已采纳

## 背景

回合闭环打通（ADR-003 后）后，对主场景做全面审查，发现三类问题：

### 第一类：功能性 Bug

1. **叙事覆盖 Bug**：`_refresh_ui()` 内部调用 `_refresh_narrative_panel()`，而 `_refresh_ui()` 会被 `legitimacy_changed`、`loyalty_changed` 等多个信号触发。执行顺序为：
   ```
   submit_action()
     → legitimacy_changed → _refresh_ui() → _refresh_narrative_panel()（重置为占位文本）
     → stendhal_diary_entry → _on_stendhal_entry()（写入司汤达文本）
     → turn_ended → _on_turn_ended() → _refresh_ui() → _refresh_narrative_panel()（再次覆盖）
   ```
   玩家永远看不到司汤达日记或行动后果文本。

2. **Hover 动画无效**：`DecisionCard._animate_hover()` 直接修改 `position.y`，但卡片在 `HBoxContainer` 内，容器每帧重新排布子节点，`position` 修改立即被还原。动画代码存在但无视觉效果。

3. **无 Rest 视觉入口**：玩家可在不选任何卡片时点"执行行动"触发休整，但界面上没有对应的可见选项，违反"每一个可操作路径都必须有视觉对应物"的原则。

### 第二类：体验缺口

4. **忠诚度面板固定 3 人**：`LOYALTY_HEROES = ["davout", "ney", "fouche"]` 硬编码，`characters.json` 中的全部将领未展示，忽视了游戏核心内容。`characters.json` 实际包含 15 名将领。

5. **RN Slider 每帧轮询**：`rn_slider.gd` 用 `_process()` 每帧读取 `GameState.rouge_noir_index`。`TurnManager` 已通过 `phase_changed` 信号驱动刷新，轮询多余且低效。

### 第三类：视觉粗糙

6. **地图路线用旋转 ColorRect**：2px 矩形旋转后边缘锯齿明显，`Line2D` 是正确工具。

7. **RN 色调未反映在界面氛围上**：`CentJoursTheme.get_rn_tint()` 已有逻辑，但主场景没有消费它。Rouge/Noir 状态应当微妙影响视觉氛围。

8. **叙事面板单条覆盖**：每次新叙事覆盖旧内容，历史记录丢失，无法感知事件积累。

---

## 决策

### Bug 修复决策

**叙事覆盖**：彻底分离叙事面板的更新路径。

- `_refresh_ui()` **不再调用** `_refresh_narrative_panel()`
- 叙事面板有且仅有两个更新入口：
  1. 玩家选卡片 → `_on_policy_selected()` 显示政策预览（临时，不进日志）
  2. 信号触发 → `_append_narrative()` 追加到滚动日志
- 引入 `_narrative_log: Array` 保存最近 `NARRATIVE_MAX_ENTRIES`（5）条记录，新条目前插，面板显示全部

**Hover 动画**：改用 `scale` 变换替代 `position` 偏移。

- `_animate_hover()` 改为 `tween_property(self, "scale", ...)` 在 1.0 和 1.04 之间过渡
- `pivot_offset` 在 `_ready()` 时设为 `custom_minimum_size / 2.0`，保证以卡片中心为缩放原点
- `scale` 变换不受容器布局约束，HBoxContainer 不干涉此属性

**Rest 视觉入口**：在决策托盘最左侧增加一张固定的"休整"卡片。

- `policy_id = "rest"`，固定不随政策列表变化
- 样式与普通卡片一致，效果列表显示近似值（-10 Fatigue / +3 Morale）作为视觉提示，不驱动引擎
- `_on_confirm_pressed()` 检测到 `_selected_policy_id == "rest"` 时调用 `TurnManager.submit_action("rest", {})`

### 体验缺口决策

**忠诚度面板**：改为遍历 `GameState.characters.keys()`，按忠诚度降序排列，**最多显示 8 位**。

- 侧栏 `LoyaltyList` 是无 `ScrollContainer` 包裹的 `VBoxContainer`，15 人 × ~24px ≈ 360px，加上 SituationPanel 和 NarrativePanel 必然溢出
- 取前 8 位（忠诚度最高，也是玩家最关心的）；若总人数 > 8，底部附加一行"另 N 位将领"提示
- 上限 8 为常量 `MAX_VISIBLE`，便于日后调整或在场景添加 `ScrollContainer` 后移除限制

**RN Slider**：移除 `_process()` 和 `set_process(true)`，在 `_on_phase_changed()` 中调用 `set_value(GameState.rouge_noir_index)`。Phase 变化在每次引擎同步后必然触发，保证时序正确。

### 视觉提升决策

**地图路线**：`_add_map_route()` 改用 `Line2D`，`width = 1.5`，颜色继承 `gold_dim`。`Line2D` 是 `Node2D` 子类，可作为 `Control` 的子节点使用，坐标系相同（相对父控件左上角）。

**RN 氛围叠加**：在 `_ready()` 中动态创建一个全屏 `ColorRect`（`_rn_overlay`），`mouse_filter = IGNORE`，作为主场景最顶层子节点。`_apply_rn_atmosphere()` 在每次状态刷新时将 `CentJoursTheme.get_rn_tint()` 的 `bg_tint` 写入其 `color`。`bg_tint` 的 alpha 最大 0.15，保证文字对比度不受影响。

**叙事滚动日志**：见叙事覆盖修复方案，`_narrative_log` 最多保存 5 条，用 `\n─────\n` 分隔显示。

---

## 替代方案（被否决）

| 方案 | 否决理由 |
|------|---------|
| 叙事：用 `dirty` 标记跳过覆盖 | 逻辑复杂，仍有竞态窗口 |
| Hover：将卡片从 HBoxContainer 中移出用绝对定位 | 破坏响应式布局 |
| RN 氛围：给各面板逐一修改 StyleBox 颜色 | 改动散乱，无法动态过渡 |
| 地图路线：用 `DrawLine` 自定义控件 | 过度工程，Line2D 已足够 |
| 忠诚度：显示全部 15 人 | 侧栏无 ScrollContainer，布局溢出 |
| 忠诚度：在场景文件加 ScrollContainer | 当前迭代不必要，代码限制更轻量 |

---

## 后果

- ✅ 司汤达日记和行动后果文本对玩家可见，叙事系统实际生效
- ✅ 卡片 hover 动效可见，托盘有交互反馈
- ✅ Rest 路径有明确视觉入口，不再依赖玩家猜测
- ✅ 忠诚度最高的 8 位将领在边栏可见，"另 N 位将领"提示保留完整人数感知
- ✅ RN Slider 不再每帧轮询，帧时间消耗减少
- ✅ 地图路线渲染干净，无锯齿
- ✅ Rouge/Noir 状态微妙影响界面氛围，沉浸感提升
- ⚠️ `_narrative_log` 为纯 GDScript 数组，重启后丢失（可接受，叙事是本局运行时内容）
- ⚠️ Rest 卡效果数值（-10 Fatigue / +3 Morale）为 UI 近似值，不代表引擎精确结果
  → 缓解：卡片标注"参考"字样，后续接入 `engine.get_rest_preview()` 时替换
- ⚠️ 忠诚度列表只展示前 8 位，低忠诚度将领（潜在叛变风险）默认不可见
  → 缓解：若日后在场景文件中为 `LoyaltyList` 包裹 `ScrollContainer`，删除 `MAX_VISIBLE` 常量即可展示全员；或改为"前 6 位 + 后 2 位"双端显示策略
