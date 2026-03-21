# ADR-003: GDScript 与 GDExtension 原生类的集成边界

## 状态: 已采纳

## 背景

在 Godot 4.6.1 中首次实际打开项目后，出现两类阻塞性解析错误：

- `CharacterManager` 的 GDScript `class_name` 与 Rust GDExtension 注册的原生类重名
- `TurnManager` 试图将 `CentJoursEngine`（原生 `RefCounted`）声明为 `@export` 字段

这两个问题都不是 Rust 核心逻辑错误，而是 **Godot 全局类名空间** 与
**Inspector 导出类型规则** 的边界不匹配。

同时，用户已在 Godot 中手动执行最小 smoke test，验证：

- `CentJoursEngine.new()` 可实例化
- `current_day()` / `get_state()` / `get_all_loyalties()` / `process_day_rest()` / `get_last_report()` 可调用
- `process_day_rest()` 后 day 1→2、morale 75→77、fatigue 10→2，结果符合预期

## 决策

采用最小修复方案：

1. `src/core/characters/character_manager.gd`
   不再声明 `class_name CharacterManager`
   避免与 Rust 原生 `CharacterManager` 冲突

2. `src/core/turn_manager.gd`
   不再将 `CentJoursEngine` 作为 `@export` 字段暴露给 Inspector
   改为在 `TurnManager` 内部懒初始化并复用单一实例

## 后果

- ✅ Godot 可继续解析项目脚本，不再因类名冲突或非法导出类型而阻塞
- ✅ 保持既有架构：Rust 原生类仍是权威业务层，GDScript 仍是薄层
- ✅ 不需要在场景树中手工接线 `CentJoursEngine`
- ✅ `TurnManager` 生命周期内复用同一个原生引擎实例，不会因重复 `new()` 丢失状态
- ⚠️ 若未来需要在 Inspector 中配置引擎引用，应改为 `Node`/`Resource` 容器模式，而不是直接导出原生 `RefCounted`

## 验证

本次修复后的验证路径：

1. Godot 4.6.1 编辑器成功打开项目
2. `godot-rust` 初始化日志出现，说明 `.gdextension` 与 `.so` 成功加载
3. 用户执行最小 smoke test，验证 `CentJoursEngine` 关键只读接口与单次状态推进闭环成功
4. 2026-03-21 追加执行
   `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot --headless --path /home/user/CentJours --quit`
   成功输出 `day=1` / `state=...` / `after_rest_state=...` / `last_report=...`
   且未再出现 `CharacterManager` 或 `TurnManager` 的 GDScript parse error
