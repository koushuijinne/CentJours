# ADR-001: 游戏逻辑层选用 Rust + GDExtension

## 状态: 已采纳

## 背景

Cent Jours 的核心机制包括：战斗解算（含随机因子）、政治派系加权计算、将领
忠诚度网络、蒙特卡洛平衡验证。这些逻辑复杂、数值密集，需要可测试性和确定性。

可选方案：
- **A. 纯 GDScript**：上手快，但缺乏类型安全，无独立单元测试框架，性能有限
- **B. Rust + GDExtension**：编译期类型检查，`cargo test` 提供完整单元测试，
  性能充裕，逻辑与 Godot 渲染完全解耦
- **C. C# + GDExtension**：.NET 生态，但跨平台部署复杂，热重载受限

## 决策

采用 **方案 B**：所有业务逻辑写在 `cent-jours-core`（Rust crate）中，
通过 `gdext` 0.4.5 暴露为 GDExtension 节点供 GDScript 调用。

GDScript 层严格遵守"薄层原则"：只做 UI 驱动和信号转发，零业务逻辑。

## 后果

- ✅ 103 单元测试完全在 Rust 层运行，不依赖 Godot 环境
- ✅ 蒙特卡洛平衡验证（10000 次模拟）可在 CI 中自动执行
- ✅ 数值参数修改只需改 Rust，GDScript 无需同步
- ⚠️ GDScript ↔ Rust 边界通过 `VarDictionary` 传递，键名无编译期检查
  → 缓解措施：每个 GDExtension 方法旁注释契约键名（见各 .gd 文件顶部注释）
- ⚠️ 无 Godot 环境时无法测试 GDExtension 集成（GATE 3 阻塞于此）
