# ADR-007: 地图 hover 与空白点击应采用统一状态机

## 状态: 已采纳（已实现）

## 背景

第二轮地图交互完成后，主场景已经具备：

- 节点 `hover` 预览
- 节点 `click` 锁定详情
- 地图右上角 `Map Inspector`

但在 Windows Godot 真机运行中，地图交互仍然存在两个不一致点：

1. **Godot 默认黑底 tooltip 与 `Map Inspector` 预览重复**
   - 地图热点节点仍设置了 `tooltip_text`
   - `hover` 时会同时出现 Godot 黑底 tooltip 和自定义 `Map Inspector`
   - 玩家会收到两套并列反馈，层级混乱

2. **空白点击对 hover 的清理语义不稳定**
   - 当前空白点击只在“已有 selected”时才清空状态
   - 仅有 `hover`、没有 `selected` 时，空白点击不一定主动清掉悬停预览
   - 实际体验会出现“有时空白点击生效，有时不生效”的错觉

从代码路径上看，当前状态来自两条不同分支：

- `mouse_exited` 会清理 `_hovered_map_node_id`
- `_on_map_canvas_gui_input()` 只在 `_selected_map_node_id != ""` 时才清理

这意味着“空白点击清理成功”有时其实只是先触发了 `mouse_exited`，而不是空白点击本身提供了稳定语义。

## 当前状态机

### 状态

- `idle`
  - `_hovered_map_node_id == ""`
  - `_selected_map_node_id == ""`
- `hovering(node)`
  - `_hovered_map_node_id == node`
  - `_selected_map_node_id == ""`
- `selected(node)`
  - `_selected_map_node_id == node`
  - `_hovered_map_node_id == node`

### 当前转移

1. `idle -> hovering(node)`
   - 条件：鼠标进入热点节点
   - 结果：高亮节点 / 路线，显示悬停预览

2. `hovering(node) -> idle`
   - 条件：鼠标离开热点节点
   - 结果：清理 hover，隐藏悬停预览

3. `hovering(node) -> selected(node)`
   - 条件：点击该节点
   - 结果：锁定详情面板

4. `selected(node) -> idle`
   - 条件：点击地图空白
   - 结果：清理 selected 与 hover

5. `hovering(node) --点击空白--> ?`
   - 当前并无稳定定义
   - 若点击前已经先触发 `mouse_exited`，会表现为“好像空白点击生效了”
   - 若没有触发 `mouse_exited`，则 hover 可能继续保留

## 问题判断

当前问题的根因不是“某个 if 条件写错了”，而是：

- **地图交互没有一套显式声明的状态机语义**
- `hover` 与 `selected` 的优先级、退出条件、空白点击行为没有被正式定义
- Godot 默认 tooltip 仍在参与反馈链路，打破了单一反馈源

## 决策

地图交互统一采用 **单一反馈源 + 显式状态机** 规则。

### 规则 1：`Map Inspector` 是唯一详情反馈源

- 禁止地图热点继续使用 Godot 默认 `tooltip_text`
- 地图节点的详情反馈统一由 `Map Inspector` 承担
- 若需要轻量提示，应作为 `Map Inspector` 的悬停态或未来自定义 tooltip 实现，而不是复用 Godot 黑底 tooltip

### 规则 2：空白点击必须始终能清理地图交互状态

无论当前处于：

- `selected(node)`
- `hovering(node)`
- 或 `selected(node)` + 鼠标仍停留在节点附近

只要点击地图空白区域，都应统一回到：

- `idle`

即：

- `_selected_map_node_id = ""`
- `_hovered_map_node_id = ""`
- `Map Inspector` 恢复默认提示

### 规则 3：`selected` 优先于 `hover`

采用以下固定优先级：

`selected > hovered > default`

含义：

- 只要节点已被选中，详情面板以 selected 内容为准
- 其他节点 hover 不得抢占已锁定详情
- 只有在没有 selected 时，hover 才驱动预览

### 规则 4：空白点击的语义不依赖 `mouse_exited`

点击地图空白必须是一个**独立、显式、可预测**的状态转移：

- 不允许把“先触发 `mouse_exited` 再清理”当作空白点击生效的前提
- 空白点击应直接触发 `idle` 收口

## 目标状态机

### 状态

- `idle`
- `hovering(node)`
- `selected(node)`

### 目标转移

1. `idle -> hovering(node)`
   - 鼠标进入节点

2. `hovering(node) -> idle`
   - 鼠标离开节点
   - 或点击地图空白

3. `hovering(node) -> selected(node)`
   - 点击该节点

4. `selected(node) -> idle`
   - 再次点击同一节点
   - 或点击地图空白

5. `selected(node_a) -> selected(node_b)`
   - 点击另一个节点

### 统一表现

- `idle`
  - 无 hover / selected 高亮
  - `Map Inspector` 显示默认提示

- `hovering(node)`
  - 高亮当前节点及相邻路线
  - 默认隐藏标签可临时显名
  - `Map Inspector` 显示“悬停预览”

- `selected(node)`
  - 维持锁定高亮
  - `Map Inspector` 显示锁定详情
  - 其他 hover 不抢占详情

## 对本项目的直接含义

- 已移除 `src/ui/main_menu.gd` 中地图热点的 `tooltip_text`
- 已把空白点击清理逻辑从“仅清 selected”升级为“统一收口到 idle”
- 该修复应作为 **解耦前的收尾小任务**，或在 `map_controller.gd` 抽离时一并实现
- 后续任何地图交互扩展（如路径预览、驻军弹层、战斗点选）都必须先遵守这套状态机

## 后果

- ✅ 玩家只会收到一套详情反馈，交互语义更清晰
- ✅ 空白点击行为稳定、可预期，不再依赖偶发的 `mouse_exited`
- ✅ 为后续地图控制器抽离提供明确契约
- ⚠️ 需要在实现时再次验证：空白点击不会误伤托盘、Sidebar 和地图热点内部点击
- ⚠️ 若未来引入右键、拖拽或框选，还需要在此状态机上扩展更多状态
