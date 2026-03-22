# ADR-005: Rust 引擎应暴露政策冷却查询接口

## 状态: 已提议

## 背景

Rust 政治系统 (`PoliticsState`) 已完整实现政策冷却机制：

- `cooldowns: HashMap<String, u8>` 记录每条政策的剩余冷却天数
- `enact_policy()` 在执行前检查冷却，冷却中则拒绝（返回错误信息）
- `daily_tick()` 每日递减冷却并清理归零条目

但 GDExtension 接口层 (`lib.rs`) **没有**暴露冷却数据：

- `get_state()` 返回的 Dictionary 不包含 `cooldowns`
- 没有 `get_policy_cooldown()` 或类似方法

这导致前端出现以下问题：

1. **数据重复**：`political_system.gd` 自行硬编码了一份政策表（含 `cooldown` 字段），
   与 Rust `default_policies()` 构成双写
2. **状态不一致**：`main_menu.gd` 用 `_mark_card_cooldown()` / `_reset_card_cooldowns()`
   做"本回合执行后标记 → 新回合全部重置"的视觉反馈，但不知道真实剩余天数。
   例如 `conscription` 冷却 5 天，前端第 2 天就误认为可用，调用 `enact_policy` 才被 Rust 拒绝
3. **UI 空转**：`decision_card.gd` 已预留 `cooldown_remaining` 展示逻辑（锁图标 + 天数），
   但来源数据始终为 0，该功能形同虚设

## 决策

在 GDExtension 接口层暴露冷却数据。具体方案二选一：

### 方案 A（推荐）：扩展现有 `get_state()` 返回值

在 `get_state()` 返回的 Dictionary 中增加 `cooldowns` 字段：

```rust
// lib.rs — get_state() 末尾追加
let mut cds = Dictionary::new();
for (id, remaining) in &self.state.cooldowns {
    cds.insert(id.as_str(), *remaining as i64);
}
d.insert("cooldowns", cds);
```

前端通过 `GameState` 缓存读取，与 ADR-002 数据流一致：

```
Rust get_state().cooldowns → TurnManager._sync_state_from_engine() → GameState → UI
```

### 方案 B：新增独立查询方法

```rust
#[func]
pub fn get_policy_cooldown(&self, policy_id: GString) -> i64;

#[func]
pub fn get_all_cooldowns(&self) -> Dictionary;
```

方案 B 灵活但增加接口面积，且与 `get_state()` 一次同步的现有模式不一致。

**采纳方案 A**，理由：

- 与 ADR-002 确立的"单次同步、只读缓存"模式一致
- 不增加新的 `#[func]` 方法，接口面积不变
- 前端无需额外调用，`_sync_state_from_engine()` 自动携带冷却数据

## 后续清理

暴露接口后，应同步清理前端冗余逻辑：

| 清理项 | 文件 | 说明 |
|--------|------|------|
| 删除硬编码政策表中的 `cooldown` 字段 | `political_system.gd` | 冷却天数改从 Rust 读取 |
| 删除 `_mark_card_cooldown()` | `main_menu.gd` | 不再由前端自行标记 |
| 删除 `_reset_card_cooldowns()` | `main_menu.gd` | 不再由前端自行重置 |
| 改用 `GameState.cooldowns` 驱动 | `decision_card.gd` | `cooldown_remaining` 从缓存取真实值 |

## 后果

- ✅ 消除前端对冷却天数的猜测，`decision_card` 显示真实剩余天数
- ✅ 遵守单一状态源原则（ADR-002），冷却逻辑只在 Rust 层
- ✅ 前端可以在政策卡片上提前灰显不可用项，减少无效点击
- ⚠️ `PoliticsState.cooldowns` 字段目前为 `pub(crate)`，需改为 `pub` 或增加 getter
  → 推荐增加 `pub fn cooldowns(&self) -> &HashMap<String, u8>` getter，保持封装
