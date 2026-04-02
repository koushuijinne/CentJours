# Cent Jours 项目扫描记录

> 日期: 2026-03-21
> 范围: 仓库结构、Rust 核心、Godot 薄层、生成物管理、Godot 交互路径

---

## 1. 项目当前状态

### 1.1 技术栈与结构

- **前端/壳层**: Godot 4.6 + GDScript
- **核心逻辑**: Rust crate `cent-jours-core`
- **桥接方式**: `gdext` / GDExtension
- **当前主入口**: `project.godot` → `res://src/ui/main_menu.tscn`

当前项目的核心架构是合理的：

- Rust 负责战斗、政治、将领网络、事件、叙事、模拟等业务逻辑
- GDScript 负责状态同步、信号发射、UI 展示元数据
- `GameState` 被设计成只读缓存，方向清晰

### 1.2 实测结果

已执行：

- `cargo test`
- `cargo test --features godot-extension`
- `python3 tests/monte_carlo_balance.py --runs 50`

结果：

- Rust 默认测试: **127/127 通过**
- Rust + GDExtension feature 测试: **127/127 通过**
- Python 蒙特卡洛脚本可运行，但结果与 Rust 版本平衡结论明显漂移，不能再作为主基线

---

## 2. 关键问题结论

### 2.1 已确认的问题

#### 问题 A: `process_day_policy()` 没覆盖全部政策

`grant_titles`、`secret_diplomacy`、`print_money` 已经在 Rust 政策表和 GDScript UI 元数据中存在，但 `CentJoursEngine.process_day_policy()` 没有映射它们。

后果：

- UI 可能允许用户选择这些政策
- `TurnManager` 仍然发出 `policy_enacted` 信号
- 但引擎实际会把未知政策静默降级为 `Rest`

这会造成“看上去执行成功，实际上什么都没发生”的假成功。

#### 问题 B: 历史事件的部分效果没有真正进入状态机

`historical.json` 中已经配置了这些效果字段：

- `coalition_troops_bonus`
- `paris_security_bonus`
- `political_stability_bonus`

但 `engine/state.rs::apply_event_effects()` 只处理了其中一部分字段，以上三项当前没有真实状态承接。

后果：

- 事件文本和设计意图存在
- 但很多历史事件只“讲了故事”，没有真正改变战局

#### 问题 C: 历史事件对 Godot/UI 的通知时点滞后一回合

Rust 引擎在 `process_day()` 的 Dawn 阶段内部触发事件；
Godot 侧 `TurnManager` 只有在下一次 `start_new_turn()` 调用时，才会把 `triggered_events` 发成 `historical_event_triggered` 信号。

后果：

- 事件的数值效果已经生效
- 但 UI 可能在下一回合才知道有事件触发
- 展示时点和结算时点错位

#### 问题 D: 命令偏差系统尚未真正接入主战斗流程

项目卖点之一是“命令偏差（Order Deviation）”，但当前主战斗流程 `GameEngine.process_battle()` 还没有把偏差结果注入实际战斗决策。

当前状态更像：

- 偏差系统已实现
- Godot 代理已存在
- 但主循环未消费该结果

这属于“模块完成，但主流程未接线”。

### 2.2 不是阻塞性 bug，但值得注意

#### Python 平衡脚本已经和 Rust 核心漂移

`tests/monte_carlo_balance.py` 仍然保留旧版简化公式，运行结果显示：

- `military` 策略政治崩溃率极高
- `political` / `balanced` 胜率 100%

这和 Rust 侧 `simulation/monte_carlo.rs` 的目标结论不一致。

建议把它明确降级为：

- 历史记录脚本
- 或直接重写为调用 Rust 二进制 / Rust 参数导出后的验证脚本

否则容易误导调参。

#### GDExtension 编译虽通过，但桥接层警告很多

`cargo test --features godot-extension` 通过了，但 `lib.rs` 有大量 `VarDictionary::insert` 的 `unused_must_use` 警告。

这不会立刻导致功能错误，但说明桥接层还没有“收口到干净可发布”的程度。

---

## 3. `.gitignore` 分析

### 3.1 现状

根目录 `.gitignore` 当前只有一行：

```gitignore
/target
```

这对当前仓库明显不够。

### 3.2 建议新增忽略的内容

#### 应该被忽略

1. Godot 编辑器缓存目录

```gitignore
/.godot/
```

原因：

- 这是 Godot 本地缓存、编辑器状态、shader cache、导入缓存
- 高度机器相关
- 变化频繁
- 不适合作为源码提交

#### 建议忽略的构建产物

2. Rust 子 crate 产物

```gitignore
/cent-jours-core/target/
```

原因：

- 当前真实构建输出在 `cent-jours-core/target/`
- 根目录 `/target` 对这个子目录并不起作用

#### 可按团队策略决定是否忽略

3. Godot 导入产物与 UID 文件

可选候选：

```gitignore
*.import
*.uid
```

但这一项**不能直接草率添加**，因为当前仓库里这类文件已经被跟踪，而且 Godot 团队对是否提交这些文件存在两种常见策略：

- **策略 A: 提交 `.import` / `.uid`**
  适合多人协作，减少资源 UID 漂移
- **策略 B: 不提交 `.import` / `.uid`**
  适合保持仓库干净，把这类文件视为派生物

Cent Jours 当前现状是：

- `.godot/` 被跟踪了
- `*.import` 被跟踪了
- `*.uid` 被跟踪了

所以这不是“补一条 ignore”就能解决的问题，而是一次**仓库策略决策**。

### 3.3 当前最值得立即处理的项

如果只做最小、低风险、确定正确的一步，优先级建议是：

1. 把 `/.godot/` 加入 `.gitignore`
2. 把 `/cent-jours-core/target/` 加入 `.gitignore`

### 3.4 当前仓库里已经被跟踪、但很像生成物的内容

已跟踪的典型生成物/缓存：

- `.godot/**`
- `cent-jours-core/target/**`
- `assets/icon.svg.import`
- 多个 `*.uid`

注意：

- 对于**已被 Git 跟踪**的文件，仅添加 `.gitignore` 不会自动停止跟踪
- 如果要真正清理，还需要后续执行一次“保留工作区文件、仅从 Git 索引移除”的清理操作

建议先做决策，再统一清理，不要一边开发一边零散移除。

---

## 4. 接下来如何与 Godot 交互

这里的“与 Godot 交互”可以拆成三层：

- **层 1: 让 Godot 能打开项目**
- **层 2: 让 Godot 能调用 Rust GDExtension**
- **层 3: 在 Godot 里驱动一条最小可验证游戏链路**

### 4.1 第一步: 在 Godot 中打开项目

1. 打开 Godot 4.6
2. `Import` 或 `Scan`
3. 选择仓库根目录 `/home/user/CentJours`
4. 确认 `project.godot` 被识别

如果项目能打开，先验证：

- 主场景 `res://src/ui/main_menu.tscn` 能正常加载
- Autoload 中的 `GameState` / `EventBus` 没有报脚本错误

Linux / WSL 下当前可直接使用的打开命令：

```bash
cd /home/user/CentJours
godot --editor .
```

如果 `godot` 命令暂时不可用，也可以直接调用二进制：

```bash
/home/user/.local/opt/godot-4.6.1/Godot_v4.6.1-stable_linux.x86_64 --editor /home/user/CentJours
```

### 4.2 第二步: 先构建 Rust GDExtension

Godot 真正依赖的是：

- `cent-jours-core/cent_jours_core.gdextension`
- 对应平台下的动态库，例如 Linux 上的 `libcent_jours_core.so`

建议先在仓库里执行：

```bash
cd /home/user/CentJours/cent-jours-core
cargo build --features godot-extension
```

如果你要让 Godot 读 release 版本，则执行：

```bash
cd /home/user/CentJours/cent-jours-core
cargo build --release --features godot-extension
```

构建完成后，Godot 会通过 `cent_jours_core.gdextension` 指向 `target/...` 下的动态库。

### 4.3 第三步: 在 Godot 里先验证最小桥接

最小验证顺序建议是：

1. 新建一个临时测试场景或测试节点
2. 在脚本里直接实例化 `CentJoursEngine`
3. 调用最简单的只读接口

建议先测试这些方法：

- `current_day()`
- `get_state()`
- `get_all_loyalties()`
- `process_day_rest()`
- `get_last_report()`

最小示例思路：

```gdscript
var engine := CentJoursEngine.new()
print(engine.current_day())
print(engine.get_state())
engine.process_day_rest()
print(engine.get_state())
print(engine.get_last_report())
```

如果这一步都通了，说明：

- 动态库加载成功
- GDExtension 类成功注册
- Rust ↔ Godot Dictionary 边界至少能跑通

### 4.4 第四步: 再接入 `TurnManager`

当前架构里，真正的交互入口不是 UI 直接乱调多个模块，而是：

```text
CentJoursEngine -> TurnManager -> GameState -> UI/EventBus
```

所以 Godot 联调的推荐顺序是：

1. 把 `CentJoursEngine` 实例挂到一个持久节点
2. 把该实例赋给 `TurnManager.engine`
3. 调用：
   - `start_new_turn()`
   - `begin_action_phase()`
   - `submit_action("rest")`
   - `submit_action("policy", {"policy_id": "conscription"})`
   - `submit_action("battle", {...})`
4. 检查 `GameState` 是否同步更新
5. 检查 `EventBus` 信号是否按预期发出

### 4.5 第五步: 先验证这 5 条关键链路

建议按以下顺序逐条验证：

#### 链路 1: 状态同步

- `engine.get_state()` 返回值
- `TurnManager._sync_state_from_engine()`
- `GameState` 对应字段是否更新

重点看：

- `legitimacy`
- `rouge_noir_index`
- `total_troops`
- `faction_support`
- `characters[*].loyalty`

#### 链路 2: 政策执行

先测可工作的 5 个政策：

- `conscription`
- `constitutional_promise`
- `public_speech`
- `reduce_taxes`
- `increase_military_budget`

暂时**不要把 `grant_titles` / `secret_diplomacy` / `print_money` 当成已完成功能**，因为当前引擎映射不完整。

#### 链路 3: 历史事件触发

重点验证：

- Day 5-7 的 `ney_defection`
- UI 侧何时收到 `historical_event_triggered`
- 数值变化是否已经先于 UI 提示发生

#### 链路 4: 叙事报告

验证：

- `process_day_policy("conscription")` 后 `get_last_report()`
- `stendhal`
- `consequence`
- `has_narrative`

#### 链路 5: 存档读档

验证：

- `SaveManager.save_game(engine)`
- `SaveManager.load_game(engine)`
- 读档后 `current_day`、`triggered_events`、`loyalty` 是否恢复

### 4.6 推荐的 Godot 联调节奏

最稳妥的开发节奏是：

1. **先 Rust**
   - 写测试
   - `cargo test`
   - `cargo test --features godot-extension`
2. **再 Godot 最小调用**
   - 只验证单个接口是否可见、可返回 Dictionary
3. **再 TurnManager 闭环**
   - 看 `GameState` 和 `EventBus`
4. **最后才做 UI**
   - 不要一开始就追着场景和按钮排查

这样能把问题分层：

- Rust 逻辑错
- GDExtension 边界错
- TurnManager 同步错
- UI 显示错

不会混在一起。

---

## 5. 建议的下一步

如果按价值排序，建议下一轮这样做：

1. 修 `process_day_policy()`，补齐 8 个政策的完整映射
2. 给“未知政策被静默降级为 Rest”加显式错误返回或日志
3. 决定 `.godot/` 与 `cent-jours-core/target/` 的忽略策略，并清理已跟踪生成物
4. 补一条 Godot 侧最小联调脚本/测试场景，用于验证 `CentJoursEngine`
5. 把命令偏差真正接入 `process_battle()`
6. 处理事件效果里未落地的字段，避免“有文案无状态”

---

## 6. 一句话结论

这个项目的**核心架构是对的，Rust 核心质量也不错**；当前主要缺的不是“重写”，而是**把已经写出来的模块接成真实可玩的闭环**，尤其是政策映射、事件效果落地、Godot 联调验证和生成物管理。
