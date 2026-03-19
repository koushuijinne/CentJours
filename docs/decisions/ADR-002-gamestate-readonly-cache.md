# ADR-002: GameState 为只读缓存，不是第二个引擎

## 状态: 已采纳

## 背景

游戏需要一个 Godot 侧的全局单例让所有 UI 节点读取当前状态（兵力、合法性、
忠诚度等）。设计时面临两种选项：

- **A. 双写模式**：GDScript 在 `GameState` 中维护自己的计算逻辑，与 Rust 引擎
  并行运行，两者通过某种方式保持同步
- **B. 只读缓存模式**：`GameState` 不含任何计算逻辑，所有数值通过
  `TurnManager._sync_state_from_engine()` 从 `CentJoursEngine.get_state()` 拷贝，
  UI 只读该缓存

## 决策

采用 **方案 B**：`GameState` 是纯 UI 缓存。

权威数据流方向：
```
CentJoursEngine（Rust）→ TurnManager._sync_state_from_engine() → GameState → UI
```

任何试图从 GDScript 侧写入 `legitimacy`、`rouge_noir_index`、`faction_support`
或将领 `loyalty` 的方法，均视为违规（当前以 `push_warning` 标记）。

## 后果

- ✅ 消除了双写导致的数值漂移 Bug（历史上曾出现 legitimacy 两套值不一致）
- ✅ 架构方向清晰：新增状态只需改 Rust `get_state()` + GDScript 同步代码
- ✅ 单元测试只需测试 Rust 层，GDScript 层无需 mock 状态
- ⚠️ `GameState.characters[id]["loyalty"]` 最初从 JSON 静态加载，
  在 `TurnManager` 同步前可能短暂过时（GATE 3 前可接受）
  → 缓解措施：`TurnManager._sync_state_from_engine()` 每回合首先运行
