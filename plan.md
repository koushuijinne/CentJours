# Cent Jours — 开发计划

> **工作标题**: *Cent Jours*（法语”百日”）
> **一句话**: 你是拿破仑，从厄尔巴岛出逃到滑铁卢，100天内重建帝国或永远流放。每一天都是决策点。
> **Author**: Julien
> **Version**: v0.17 — 2026-03-22
> **Status**: Draft — M0-M4 完成，GATE 2 通过，测试127个；前端 Priority B 全部完成；ADR-005 政策冷却接口暴露，前端卡片显示真实冷却天数

-----

## 1. 产品定义

### 1.1 核心体验

紧凑的回合制策略游戏（turn-based strategy）。每回合 = 1天，100回合 = 完整一局。军事行军 + 政治博弈 + 将领忠诚度管理。2-3小时通关，高重玩价值（replayability）。

核心情感：**紧迫感**——你的时间在流逝，整个欧洲在集结，每一天的选择都不可逆。

### 1.2 商业参数

|参数  |值                             |
|----|------------------------------|
|目标平台|PC (Steam)，后续移植移动端            |
|定价  |$12.99–$14.99                 |
|目标受众|P社玩家、历史策略爱好者、拿破仑迷             |
|竞品定位|比EU/全战轻量，比手游深度，填补”中等复杂度历史策略”空白|
|开发模式|Solo + AI辅助                   |
|引擎  |Godot 4 + GDScript            |
|开发周期|30周（7.5个月），可弹性至40周            |

### 1.3 差异化竞争力

1. **极致的时间压缩** — 100天，每天是一个完整决策回合，没有”跳过”的空转期
1. **政治-军事双线张力** — 不只是打仗，还要同时维系巴黎的政治合法性（legitimacy）
1. **命令偏差系统（Order Deviation）** — 你的命令不会100%被执行，偏差取决于将领个性和条件（受托尔斯泰《战争与和平》启发）
1. **文学叙事层** — 司汤达NPC日记、Rouge/Noir双极系统、微叙事后果片段
1. **Vic3/Anno 1800级视觉品质** — 帝国新古典主义美学 + 现代深色沉浸式UI，拒绝”羊皮纸indie策略游戏”视觉定式

-----

## 2. 核心系统设计

### 2.1 系统架构总览

```
┌─────────────────────────────────────────────┐
│              GAME LOOP（游戏循环）              │
│    Dawn Phase → Action Phase → Dusk Phase    │
│      (情报)        (决策)       (结算)         │
└──────┬──────────────┬──────────────┬─────────┘
       │              │              │
  ┌────▼────┐   ┌─────▼─────┐  ┌────▼────┐
  │ 行军与战役 │   │ 政治与合法性│  │将领忠诚度│
  │ (Rouge)  │◄─►│  (Noir)   │◄►│  网络    │
  └────┬────┘   └─────┬─────┘  └────┬────┘
       │              │              │
       └──────────────┼──────────────┘
                      │
              ┌───────▼───────┐
              │  文学叙事层     │
              │ (Flavor/情感)  │
              └───────────────┘
```

三个核心系统**强耦合**：军事行动消耗政治资本，政治决策影响将领忠诚，将领忠诚决定命令执行的可靠性。

### 2.2 系统①：行军与战役（Rouge）

**地图**: 法国 + 比利时/莱茵区域，节点制（node-based），约30-40个关键节点（城市、要塞、渡口、山口）。不用六角格（hexgrid），降低美术成本，同时更适合表达战略级行军。

**每日行军决策**:

- 选择行军方向（节点间移动）
- 分配部队至各军团（每个军团由一位将领指挥）
- 是否强行军（forced march）：+1节点移动力，但士气-10%、疲劳+20%
- 是否发动战斗或绕行

**战斗解算（auto-resolve）**:
不做战术层。战斗结果由加权模型自动计算：

```
BATTLE_SCORE = Σ(兵力 × 士气 × 将领能力 × 地形加成)
              + RANDOM_FACTOR(-15%, +15%)
              - 疲劳惩罚
              - 补给不足惩罚
```

玩家的决策空间是**战略层**——在哪里打、用多少兵力、谁指挥——而不是微操单位。

**关键历史节点**:

- Day 1-20: 从儒安湾（Golfe-Juan）北上巴黎，沿途争取驻军倒戈
- Day 20-30: 进入巴黎，路易十八出逃
- Day 30-80: 重建军队、应对反法同盟集结
- Day 80-100: 比利时战役（利尼、四臂村、滑铁卢）

**数学建模备注**（利用光伏调度经验）:

- 行军路径优化 ≈ 带时间窗的路径规划问题
- 兵力分配 ≈ 多目标资源分配（MILP简化版）
- 补给线管理 ≈ 储能SOC约束的变体

### 2.3 系统②：政治与合法性（Noir）

**双指针系统**:

```
    革命热情（Rouge）           制度稳定性（Noir）
    ◄━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━►
    极左激进                  0                  极右保守
    (民众狂热                (均衡)              (贵族复辟
     但制度崩溃)                                  但民心尽失)
```

指针位置影响：

- **偏Rouge**: 征兵效率+, 民众支持+, 外国干预意愿+, 贵族叛逃风险+
- **偏Noir**: 行政效率+, 外交空间+, 民众热情-, 革命派失望-

**四势力支持度（0-100）**:

|势力    |核心诉求     |提升手段          |冲突关系  |
|------|---------|--------------|------|
|议会自由派 |宪政、议会权力  |颁布宪法承诺、任命自由派官员|与军方争权 |
|旧贵族/教会|秩序、特权保留  |做出让步、保留旧制度元素  |与民众对立 |
|巴黎民众  |革命遗产、经济改善|发表演说、分配面包、降税  |与贵族对立 |
|军方    |军费、荣誉、征服 |增加军费、授予勋章、许诺胜利|与议会争预算|

**每日政策行动（选1-2项）**:

- 颁布法令（影响双指针 + 特定势力）
- 任命/撤换官员（影响行政效率 + 人际关系）
- 发表公开演说（短期民众支持+，但可能激化对立）
- 秘密外交（尝试分化反法同盟，成功率低但收益高）
- 经济措施（征税/印钞/征用，各有不同的延迟后果）

**核心张力**: 拿破仑需要同时讨好所有势力来维持政权合法性，但四个势力的需求彼此矛盾。这是一个**多目标优化问题，不存在帕累托最优解**——你只能做tradeoff。

### 2.4 系统③：将领忠诚度网络

**人物卡**: 15-20个关键角色，每人有：

```yaml
# 示例：Michel Ney
name: "Michel Ney"
title: "埃尔辛根公爵"
role: marshal  # marshal / general / politician / advisor
loyalty: 65    # 0-100，<30 可能叛变，>80 无条件服从
temperament: impulsive  # cautious / balanced / impulsive / reckless
ambition: 40   # 高野心者在你弱势时更可能背叛
military_skill: 85
political_influence: 60
relationships:
  napoleon: 70
  grouchy: 30
  davout: 55
special_trait: "hot-headed"  # 影响命令偏差方向
historical_note: "曾誓言将拿破仑装在铁笼里带回巴黎，但见面后立即倒戈"
```

**命令偏差系统（Order Deviation）**:

你下达命令，将领执行时有偏差。偏差幅度 = f(忠诚度, 性格, 通信距离, 战场混乱度)

```
DEVIATION = BASE_RELIABILITY(loyalty)
            × TEMPERAMENT_FACTOR(temperament)
            × DISTANCE_PENALTY(communication_distance)
            × FOG_OF_WAR(battlefield_chaos)

# impulsive将领可能提前发动攻击（如Ney在滑铁卢的骑兵冲锋）
# cautious将领可能延迟行动（如Grouchy未能及时增援）
```

这不是纯随机——是**有人格特征的系统性偏差**。玩家需要学会”给Ney保守的命令因为他会自动加码”。

**关键历史决策点**:

- **Ney的倒戈**（Day 5-7）: 路易十八派Ney来抓你，你能否争取他倒戈？取决于你之前的声望和与他的关系
- **Grouchy的任命**（Day 85-90）: 是否派Grouchy追击普鲁士军。如果派了，他的cautious性格意味着他可能追得太慢
- **Davout的角色**（Day 20-30）: 最可靠但最不擅长政治的将领，你把他放在战场还是巴黎？

-----

## 3. 文学叙事层

> 设计原则：文学元素是**发现的惊喜**，不是**被迫的阅读**。玩家首先在玩策略游戏，文学层为体验增加深度但不阻断核心循环。

### 3.1 司汤达NPC日记

- 司汤达（Marie-Henri Beyle）作为NPC存在于游戏中，身份为”帝国审计官/业余作家”
- 每天结算阶段（Dusk Phase），司汤达写一段日记评论当天事件
- 日记内容**离线批量生成**：为每个关键决策分支预生成3-5个文本变体，运行时根据玩家行动选取匹配版本
- 文风：冷峻、讽刺、带有司汤达式的心理分析（“皇帝今天的微笑里有一种计算过的温暖”）
- 日记可通过UI侧边栏查看，不打断主循环

### 3.2 Rouge et Noir 视觉主题

- UI配色随双指针实时变化：偏Rouge时界面暖红调，偏Noir时冷黑灰调
- 背景音乐跟随变化：Rouge状态下激昂铜管为主，Noir状态下弦乐和钢琴为主
- 这不是彩蛋，而是**核心机制的直觉式反馈**——玩家不需要看数值就能感知政治状态

### 3.3 微叙事后果片段（Les Misérables 层）

- 关键决策后弹出一段短文（2-3句），展示一个普通人视角的后果：
  - 征兵令 → “里昂郊外，一个面包师的妻子目送第三个儿子走向集结点。”
  - 降税 → “巴黎市场上，鱼贩第一次在周三卖出了所有的鱼。”
  - 强行军 → “一个掉队的步兵在路边坐下，再也没有站起来。”
- 内容池：为每种决策类型预生成20-30个变体，随机抽取
- 可选关闭（设置中），不影响gameplay

### 3.4 结局文学引用

根据不同结局路径，显示不同的收尾引文：

|结局类型       |引用来源 |示例方向       |
|-----------|-----|-----------|
|滑铁卢大胜（架空）  |司汤达  |关于野心与幸福的张力 |
|滑铁卢惜败（史实近似）|托尔斯泰 |关于个人意志与历史洪流|
|未到滑铁卢即政治崩溃 |雨果   |关于民众与权力的关系 |
|完美胜利但法国精疲力竭|夏多布里昂|关于胜利的代价    |

### 3.5 隐藏彩蛋

- 某个随机生成的低级军官姓 “Valjean”
- 司汤达日记中偶尔出现一个叫 “Julien S.” 的年轻军官（他在观察拿破仑）
- 在特定条件下（如你在格勒诺布尔做出特定选择），触发一段关于”红与黑”——军装与教士袍——之间选择的隐喻文本
- 最高难度名称：“Austerlitz”；最低难度名称：“Elba”

### 3.6 BGM策略

- **不使用**任何现有音乐剧/电影原声（版权风险）
- 使用AI音乐工具（AIVA / Suno）生成原创BGM，指定情感调性：
  - 主菜单：庄严、命运感、铜管 + 弦乐
  - Rouge状态：紧张、激昂、军鼓节奏
  - Noir状态：阴郁、算计、钢琴 + 大提琴
  - 滑铁卢战役：史诗、悲壮、全管弦
  - 结局（胜）：短暂辉煌后的空虚
  - 结局（败）：尊严、不屈、渐弱至寂静
- 人工筛选 + 简单后期处理，确保音乐品质
- 目标：6-8首核心曲目，总时长30-40分钟

### 3.7 视觉美术风格指南（Visual Art Direction）

> 视觉标杆：Victoria 3 + Anno 1800。拒绝2010年代的”羊皮纸+棕色边框”老派策略游戏风格，对标2022-2025年AAA策略游戏的现代视觉标准。

#### 3.7.1 总体风格定位

**帝国新古典主义（Empire Neoclassical）+ 现代沉浸式UI框架**

视觉参考源：

- **绘画**: Jacques-Louis David（大卫）、Jean-Auguste-Dominique Ingres（安格尔）的新古典主义肖像画——深色背景、侧光、戏剧性构图
- **UI框架**: Victoria 3的深色半透明面板系统 + Anno 1800的金色边框卡片设计
- **地图**: Victoria 3的带地形纹理政治地图——深色基调、国境金色描边、区域色彩叠加
- **情绪**: 不是”古老的”，而是”庄严的、精密的、有权力感的”

#### 3.7.2 核心调色板

```
┌─────────────────────────────────────────────────────┐
│  CENT JOURS — MASTER PALETTE                        │
├─────────────────────────────────────────────────────┤
│                                                     │
│  主背景         #1A1A2E   ██  深海军蓝              │
│  面板背景       rgba(30, 30, 50, 0.85)  半透明深色   │
│  面板边框       #3A3A5C   ██  暗紫灰                │
│                                                     │
│  帝国金(强调)   #C9A84C   ██  金色高光/边框/图标      │
│  帝国金(暗)     #8B7332   ██  次级金色/悬停态         │
│                                                     │
│  Rouge红        #8B2500   ██  革命/军事/热情          │
│  Rouge红(发光)  #D4421E   ██  Rouge指针高光          │
│  Noir蓝黑       #2C2C3A   ██  保守/制度/秩序          │
│  Noir蓝(发光)   #4A6FA5   ██  Noir指针高光           │
│                                                     │
│  正面效果       #C9A84C   ██  金色文字               │
│  负面效果       #A03020   ██  暗红文字               │
│  中性信息       #A09880   ██  暗金灰                 │
│                                                     │
│  文字主色       #E8E0D0   ██  暖白(正文)             │
│  文字次色       #A09880   ██  暗金灰(说明文字)        │
│  文字标题       #F0E6C8   ██  亮金白(标题)            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

Rouge/Noir状态影响全局色调：

- **偏Rouge时**: 界面暗红暖色调渐浓，金色偏铜，背景微红
- **偏Noir时**: 界面冷蓝灰调加深，金色偏银，背景微蓝
- **过渡**: 用shader或tween平滑渐变，玩家无意识感知政治状态变化

#### 3.7.3 UI组件库规范

```
┌─────────────────────────────────────────────────┐
│  UI COMPONENT LIBRARY                           │
├─────────────────────────────────────────────────┤
│                                                 │
│  Panel（面板）                                   │
│  ├── 背景: rgba(30,30,50,0.85) 高斯模糊底层      │
│  ├── 边框: 1px #3A3A5C + 内侧0.5px #C9A84C      │
│  ├── 圆角: 4px（微圆角，不过度圆润）              │
│  └── 阴影: 0 4px 16px rgba(0,0,0,0.4)           │
│                                                 │
│  Button（按钮）                                  │
│  ├── 默认: 暗金渐变底(#3A3520→#2A2518)           │
│  ├── 悬停: 金色边框发光 + 底色提亮               │
│  ├── 按下: 内凹阴影 + 底色压暗                   │
│  ├── 文字: #E8E0D0 衬线字体                      │
│  └── 禁用: 50%透明度                             │
│                                                 │
│  Card（决策卡片）— 参考Anno 1800模式选择卡片      │
│  ├── 背景: 深色 + 顶部插图区(AI生成场景缩略图)    │
│  ├── 边框: 2px金色描边，选中时发光                │
│  ├── 标题: 衬线字体，金色                        │
│  ├── 效果数值: 正面金色/负面暗红                  │
│  └── 悬停: 整体微提亮 + 边框光晕                 │
│                                                 │
│  Portrait（肖像框）— 参考Anno 1800角色选择       │
│  ├── 形状: 圆形裁切                              │
│  ├── 边框: 双层金色描边(外粗内细)                 │
│  ├── 底部: 名牌条(深色底+金色文字)                │
│  ├── 选中: 外圈发光环                            │
│  └── 忠诚度: 弧形进度条围绕头像外圈              │
│                                                 │
│  ProgressBar（进度条）                           │
│  ├── Rouge/Noir双向条: 中心零点，左红右蓝        │
│  ├── 填充: 渐变色 + 微发光                       │
│  └── 背景槽: 深色凹陷质感                        │
│                                                 │
│  Tooltip（提示框）                               │
│  ├── 深色面板 + 金色标题 + 暖白正文              │
│  ├── 三角箭头指向触发元素                        │
│  └── 出现动画: 0.15s fade-in + 微上移            │
│                                                 │
│  IconBadge（图标徽章）                           │
│  ├── 风格: 金属浮雕/烫金感（非平面色块）         │
│  ├── 底座: 圆形深色底 + 金色描边                 │
│  └── 参考: Vic3资源图标 + Anno 1800标志选择界面   │
│                                                 │
│  Divider（分隔线）                               │
│  ├── 金色细线 + 中央装饰元素                     │
│  └── 装饰: 帝国鹰 / 百合花 / 月桂叶（轮换使用）  │
│                                                 │
└─────────────────────────────────────────────────┘
```

#### 3.7.4 逐区域视觉设计

**顶栏（Top Bar）**

```
┌──────────────────────────────────────────────────────────────┐
│ 🦅 Jour 21/100     ◄━━Rouge━━━━━━●━━━━━━Noir━━►    💰1.2M  │
│    Le Vol de l'Aigle     70           30            👥95k    │
└──────────────────────────────────────────────────────────────┘
```

- 深色半透明底条（非羊皮纸）
- 天数用大号衬线字体（Playfair Display / Cormorant Garamond）
- 副标题（阶段名）用手写体（italic script）
- Rouge/Noir滑条带发光效果：Rouge端暗红光晕，Noir端冷蓝光晕
- 资源图标用金属浮雕风微型图标

**地图区域（Map Area）**

- **底图**: 深色基调法国地形图（AI生成高分辨率底图）
  - 海洋: 深蓝黑渐变
  - 陆地: 深绿褐色调，带微妙地形起伏纹理（丘陵有柔和高光）
  - 河流: 暗银色细线，微发光
  - 国境线: 金色描边（2px）
- **节点城市**: 发光标记点（小型金色菱形/圆形），重要城市更大更亮
- **行军路线**: 金色虚线 + 行进动画（点光沿路线移动）
- **军团标记**: 帝国鹰徽 + 将领微型肖像 + 兵力数字浮层
- **敌军**: 红色标记（已知位置）/ 灰色问号（未确认位置，战争迷雾）
- **整体参考**: Victoria 3的政治地图模式——深色、信息密度高、但不杂乱

**司汤达日记面板（Side Panel）**

- 半透明深色面板（非羊皮纸卷轴）
- 顶部: 金色书本图标 + “司汤达日记” 衬线标题
- 头像: 小圆框 + 金色描边（Anno 1800风格）
- 日记文字: 衬线字体（Cormorant Garamond），#E8E0D0色，微透纸张纹理叠加
- 底部: “Jour 21” 日期标注，暗金灰色
- 可折叠: 点击收起为侧边小标签

**决策托盘（Decision Tray）**

- 底部深色面板，水平排列2-4张决策卡片
- 每张卡片: 深色底 + 顶部小型场景插图（AI生成，64x64px缩略图）
- 卡片结构:
  
  ```
  ┌──────────────┐
  │  [场景缩图]   │
  │              │
  │ 颁布自由派宪法 │  ← 衬线字体标题
  │              │
  │ +15 议会  📜  │  ← 金色 = 正面
  │ -10 旧贵族 ⚜  │  ← 暗红 = 负面
  │ Rouge +5     │  ← 红色
  └──────────────┘
  ```
- 选中态: 金色边框加粗 + 外发光
- 不可选态: 灰暗 + 锁链图标覆盖

**将领网络面板（General Panel）**

- 默认: 右下角折叠态，仅显示2-3个关键将领小圆框
- 展开: 覆盖地图右侧的大面板
- 人物圆框: Anno 1800风格双层金色描边
- 忠诚度: 弧形进度条围绕头像（绿→黄→红渐变）
- 关系线: 金色(友好) / 暗红(敌对) / 灰色(中立)，线宽反映强度
- 性格标签: 小型金属徽章图标（⚡冲动 / 🛡谨慎 / ⚖均衡 / 🔥鲁莽）
- 点击将领: 弹出详情卡（全屏15%宽度的侧面板）

#### 3.7.5 字体系统

```
标题层（H1/H2）:
  英文: Playfair Display Bold / Cormorant Garamond Bold
  中文: 思源宋体 Bold（Noto Serif CJK SC Bold）
  用途: 天数显示、面板标题、结局文字

正文层（Body）:
  英文: Source Serif 4 / Libre Baskerville
  中文: 思源宋体 Regular
  用途: 司汤达日记、事件描述、微叙事文本

UI信息层（Label）:
  英文: Inter / Source Sans 3
  中文: 思源黑体 Regular（Noto Sans CJK SC）
  用途: 资源数值、按钮文字、提示信息、效果数值

手写/签名层（Script）:
  英文: Dancing Script / Great Vibes
  用途: 阶段副标题、司汤达签名、信件落款
  注: 极少量使用，仅用于装饰性文字
```

#### 3.7.6 人物肖像生成策略

**风格**: 新古典主义数字油画，对标David/Ingres画风——不是卡通插画，不是照片写实3D渲染，而是介于两者之间的**高质量数字绘画**。

**Stable Diffusion / Midjourney 核心Prompt模板**:

```
[人物描述], neoclassical portrait, oil painting style,
dark moody background, dramatic chiaroscuro lighting,
Napoleonic era [military uniform / formal attire / civilian dress],
Jacques-Louis David influence, museum quality,
warm golden undertones, detailed fabric texture,
bust portrait, three-quarter view,
--ar 1:1 --style raw
```

**后期统一处理**:

1. 统一调色: 偏暖金色调（色温6200K左右）
1. 统一背景: 深褐/深蓝灰渐变
1. 统一光源方向: 左侧45度主光
1. 圆形裁切 + 双层金色描边
1. 批量检查面部比例和风格一致性

**数量**: 20-25张（15-20将领/政客 + 司汤达 + 3-5随机NPC池），每张2-3次迭代，预计总工作量40-60次生成+筛选。

#### 3.7.7 地图底图生成策略

**方法**: AI生成1张高分辨率（4096x3072px）深色调法国地形底图，游戏中所有节点、路线、标记用Godot 2D渲染叠加。

**底图Prompt方向**:

```
France topographic map, dark navy blue and deep green palette,
subtle terrain elevation shading, rivers in silver,
Mediterranean and Atlantic coastline detail,
no text no labels no borders, painterly style,
birds eye view, --ar 4:3
```

**Godot叠加层**（从底到顶）:

1. 底图纹理（静态，AI生成）
1. 国境线层（金色描边，矢量）
1. 河流高亮层（银色线条，矢量）
1. 区域着色层（半透明政治色彩叠加）
1. 节点标记层（城市/要塞/渡口图标）
1. 行军路线层（动画虚线）
1. 军团标记层（将领头像+兵力数值浮层）
1. 战争迷雾层（半透明黑色遮罩，随侦察解除）

-----

## 4. 技术选型

|层面      |选型                                      |理由                                                          |
|--------|----------------------------------------|------------------------------------------------------------|
|前端引擎   |Godot 4 + GDScript                      |开源、轻量、2D友好、可视化编辑器大幅降低UI开发成本                                 |
|**核心逻辑**|**Rust + gdext (godot-rust)**           |**编译期类型安全、100倍于GDScript的模拟速度、完全可移植；GDExtension接口与Godot通信** |
|数据驱动   |JSON/YAML配置文件                           |所有历史事件/人物/政策外部配置，不硬编码，便于迭代和mod支持                            |
|版本控制   |Git + GitHub                            |标准流程                                                        |
|LLM集成  |**离线批量生成**                              |文本内容（司汤达日记/微叙事/事件描述）全部预生成存入JSON，运行时不调用API                   |
|美术      |Stable Diffusion / Midjourney + Godot 2D|新古典主义数字油画肖像 + AI生成深色地形底图 + Godot矢量叠加层，对标Vic3/Anno 1800品质  |
|音乐      |AIVA / Suno生成 → 人工筛选                    |指定情感调性生成候选 → 筛选 → 简单后期                                       |
|测试      |`cargo test` + Python蒙特卡洛脚本             |Rust单元测试覆盖核心逻辑；蒙特卡洛1000局平衡验证（Rust版比GDScript快100倍以上）        |

### 4.1 Rust-Godot 分层架构

```
┌────────────────────────────────────────────────────┐
│              Godot 4 前端（GDScript）                │
│  scene树 / UI组件 / 动画 / 音频 / 输入处理           │
│  turn_manager.gd  game_state.gd  event_bus.gd       │
└─────────────────────┬──────────────────────────────┘
                      │  GDExtension API（gdext）
                      │  Dictionary / Array / Variant
┌─────────────────────▼──────────────────────────────┐
│          cent-jours-core（Rust crate）               │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │  battle/    │  │  politics/   │  │characters/ │ │
│  │ 战斗解算    │  │ Rouge/Noir   │  │ 忠诚度网络  │ │
│  │ 行军系统    │  │ 四势力模型   │  │ 命令偏差    │ │
│  └─────────────┘  └──────────────┘  └────────────┘ │
│  ┌──────────────────────────────────────────────┐   │
│  │  simulation/ — 蒙特卡洛平衡测试（独立可执行）   │   │
│  └──────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────┘

职责边界：
  Rust  ← 所有数值计算、状态转移、概率模型、平衡验证
  Godot ← 所有UI渲染、用户输入、场景管理、音频、动画
```

**选择依据**：

- **UI交互留在Godot**：策略游戏80%开发时间花在UI上；Godot可视化编辑器、信号系统、Tween动画远比用代码手写高效
- **核心逻辑用Rust**：战斗解算/政治模型/命令偏差全是纯算法，Rust编译器是天然的质检员（类型错误编译期暴露，不是运行时）
- **蒙特卡洛速度**：Rust版跑1000局<1秒，GDScript版需要数分钟；M2/M3阶段可以实时调参、即时验证平衡

### 4.2 代码架构

```
cent-jours/
├── project.godot
├── cent-jours-core/              # Rust crate（核心逻辑）
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs                # GDExtension 绑定入口
│       ├── battle/               # 战斗解算 + 行军系统
│       │   ├── mod.rs
│       │   ├── resolver.rs       # 战斗加权模型
│       │   └── march.rs          # 行军/疲劳/补给
│       ├── politics/             # Rouge/Noir + 四势力
│       │   ├── mod.rs
│       │   └── system.rs
│       ├── characters/           # 将领忠诚度网络 + 命令偏差
│       │   ├── mod.rs
│       │   └── order_deviation.rs
│       └── simulation/           # 蒙特卡洛平衡测试
│           └── monte_carlo.rs
├── src/                          # GDScript（UI层）
│   ├── core/
│   │   ├── game_state.gd         # Godot autoload（薄包装层）
│   │   ├── turn_manager.gd       # 回合编排
│   │   └── event_bus.gd          # 信号总线
│   ├── ui/                       # 纯展示组件
│   │   ├── theme/
│   │   └── components/
│   └── data/                     # JSON 数据文件
│       ├── characters.json
│       ├── map_nodes.json
│       ├── design_tokens.json
│       └── narratives/
├── assets/                       # 美术素材
├── tests/                        # Python 辅助脚本（快速原型）
└── docs/                         # 设计文档 + UI原型
```

**编码规范**：

- Rust：snake_case 函数/变量，SCREAMING_SNAKE_CASE 常量，每个公开函数有 doc comment
- Rust 核心模块与 GDExtension 绑定严格分离（`src/lib.rs` 只做类型转换，不含业务逻辑）
- GDScript：保持现有规范（中文注释，事件驱动，不持有 Rust 对象的直接引用）
- 数据驱动：Rust 从 JSON 加载配置，修改 JSON 即可调整平衡，无需重编译 Godot 项目

-----

## 5. 开发里程碑

### 总览（30周 / 7.5个月）

```
W1──W2──W3────W7────W11────W14────W19────W23────W30
│ M0 │M0.5│  M1  │  M2  │  M3  │  M4   │  M5  │  M6  │
│预研 │视觉 │核心循环│政治  │将领  │内容填充│美术  │打磨  │
│    │定调 │      │系统  │网络  │      │音乐  │发布  │
│         │GATE1       │GATE2       │GATE3       │
│         │核心循环    │三系统耦合   │wishlist    │
│         │好玩吗？    │能平衡吗？   │达标了吗？  │
```

### M0: 预研（W1-W2）✅ 完成

**目标**: 验证技术可行性，建立开发环境

**交付物**:

- [ ] Godot 4项目初始化 + Git仓库（仓库已建，Godot场景待安装后初始化）
- [x] **Rust开发环境：`rustup` + `cargo` + `gdext` crate，GDExtension绑定层已实现**
- [x] **`cent-jours-core` crate骨架：全模块结构 + 33个单元测试通过（`cargo test`）**
- [x] 核心系统数学建模文档（附录A.1战斗模型/A.2命令偏差已Rust实现）
- [x] 法国地图节点设计（`src/data/map_nodes.json`：42节点 + 41条边）
- [x] 美术风格参考板：§3.7视觉指南 + `docs/ai_prompts.md`（15人物肖像+地图提示词）
- [x] 人物数据初稿（`src/data/characters.json`：15个历史人物完整数据）

**内容同步**: devlog #1 —「一个光伏算法工程师为什么要做拿破仑游戏」

### M0.5: 视觉定调（W3）✅ 完成

**目标**: 在编码前锁定视觉语言，建立UI组件库基础，避免M5阶段返工

**交付物**:

- [x] 高保真UI概念图：`docs/ui_prototype.html`（自包含HTML/CSS，可直接浏览器打开）
- [x] 核心调色板确认（`src/data/design_tokens.json`：颜色/字体/间距/动画完整设计令牌系统）
- [x] 字体选型确认（Playfair Display / Cormorant Garamond / 思源宋体 已纳入设计令牌）
- [x] Godot UI组件模板（GDScript）：`cent_jours_theme.gd` / `rn_slider.gd` / `decision_card.gd`
- [x] 人物肖像风格测试提示词：`docs/ai_prompts.md`（15角色 David/Ingres 油画风SD/MJ提示词）
- [x] 地图底图风格测试提示词：深色地形底图方向已锁定（docs/ai_prompts.md 第6节）

**原则**: 此阶段产出的UI组件模板将贯穿M1-M4全部开发阶段。即使是占位符UI，也必须使用正确的配色、字体和面板风格，确保最终美术填充时只需替换纹理和细节，不需重构布局。

**内容同步**: devlog素材积累（AI生成美术的工作流截图/对比图）

### M1: 核心循环（W4-W7）🔶 Rust层完成，Godot 联调已打通，主场景骨架已可见

**目标**: 最小可玩原型（minimum playable prototype），验证100天行军的节奏感

**交付物**:

- [x] **Rust：`battle::resolver` 战斗解算模块（7个单元测试）**
- [x] **Rust：`battle::march` 行军/疲劳/补给/Dijkstra路径（6个单元测试）**
- [x] **Rust：GDExtension 绑定层（`BattleEngine` + GDScript Dictionary接口，`src/lib.rs`）**
- [x] Godot 编辑器成功打开项目（2026-03-21，WSL / Linux）
- [x] `CentJoursEngine` 最小 smoke test（`new()` / `get_state()` / `get_all_loyalties()` / `process_day_rest()` / `get_last_report()`）
- [x] Godot 解析修复：`character_manager.gd` 去除冲突 `class_name`，`turn_manager.gd` 改为懒初始化原生引擎（见 ADR-003）
- [x] 跨平台仓库清理：忽略 `.godot/`、`cent-jours-core/target/` 与原生构建产物，并将已跟踪 `.godot` 缓存移出 Git 索引
- [x] 主场景骨架：`main_menu.tscn` 已具备 Top Bar / Map Area / Sidebar / Decision Tray 四区布局
- [x] 正式入口与 smoke test 分离：`src/dev/engine_smoke_test_scene.tscn`
- [ ] 地图节点系统（Godot节点间移动 + 路径选择，调用Rust Dijkstra）→ 需要Godot
- [x] 回合流程架构（`src/core/turn_manager.gd` GDScript编排框架已建立）
- [ ] 简易AI对手（反法同盟自动集结逻辑，Rust实现）→ **可开发（无需Godot）**
- [x] **占位符UI**（`RougeNoirSlider` / `DecisionCard` / `GameState` HUD 已接入正式入口）

**⛳ GATE 1（W7结束）**: 核心循环是否好玩？

- ✅ 通过条件：纯行军+战斗的100天流程有节奏感，“再来一天”的吸引力存在
- ❌ 失败处理：重新评估回合粒度（也许不是每天一回合，而是每周？），或调整地图规模
- 🛑 止损条件：如果根本不好玩且看不到修复方向 → 项目终止或转向备选方案（黑死病）

**内容同步**: devlog #2-3 — 算法设计过程（行军路径优化、战斗模型）

### M2: 政治系统（W8-W11）✅ Rust层完成，平衡达标

**目标**: Rouge/Noir双指针 + 四势力系统，与行军系统耦合

**交付物**:

- [x] **Rust：`politics::system` Rouge/Noir双指针 + 四势力完整模型（8个单元测试）**
- [x] **Rust：`simulation::monte_carlo` 平衡测试（`cargo run --bin balance-test`，500局<1秒）**
- [x] **Rust：政治-战役耦合接口（`PoliticsEngine` via GDExtension，`src/lib.rs`）**
- [ ] 每日政策行动选择界面（Godot UI）→ 需要Godot
- [x] 政治崩溃触发条件（`is_collapsed()` Rust实现，≥2势力低于阈值）
- [x] **平衡调试完成** — Military 24.2% ✅ / Political 21.2% ✅ / Balanced 22.4% ✅（目标15-35%）

**内容同步**: devlog #4 —「如何用优化模型做政治博弈」

### M3: 将领网络（W12-W14）✅ 完成，GATE 2 通过
### M1 补充：EventPool → GameEngine 集成 ✅（2026-03-18）
> `process_day()` Dawn 阶段自动触发历史事件，89 tests 全通过。`.gdextension` 描述符已就位。

**目标**: 人物系统 + 关系网络 + 命令偏差模型

**交付物**:

- [x] **Rust：`characters::order_deviation` 命令偏差模型（6个单元测试，含Ney/Grouchy历史场景）**
- [x] **Rust：`characters::network` 将领关系网络（23个单元测试）** — 含 `from_json()` 从 characters.json 动态加载
- [x] **Rust：`engine::state` 三系统耦合状态机（13个单元测试）** — battle+politics+characters联动，Dawn→Action→Dusk
- [x] **Rust：`events::pool` JSON驱动历史事件池（13个单元测试）** — 30个历史事件（+6新增），触发条件+叙事文本
- [x] **Rust：`simulation::run_engine_simulation()` 三系统+EventPool 耦合蒙特卡洛（8个单元测试）** — 1000局 < 2s
- [x] **characters.json → CharacterNetwork** 数据集成，历史关系数据（-30敌对/正值友好）已修正
- [x] **数据驱动化重构**（2026-03-19）：将领技能值 `general_skill()` 改为从 `CharacterNetwork.skills` 读取（修复 davout 82→92、soult 72→80 数据错误）；`EventEffects` / `EventTrigger` 改为通用 HashMap（`loyalty_deltas` / `loyalty_min` / `loyalty_max`）；`coalition_not_defeated` 触发条件 Bug 修复；**113/113 单元测试通过**
- [x] **测试覆盖全面提升**（2026-03-20）：历史事件填充 Day10-19（+3事件：里昂/勃艮第/枫丹白露）；`rest_army()` 4个直接测试；`narratives` 键名契约验证 +2 测试；`resolver.rs` 边界值 +5 测试；**127/127 单元测试通过**

**⛳ GATE 2（W14结束）**: 三系统耦合后复杂度是否可控？

- ✅ 通过条件：三个系统交互产生有趣的涌现决策，平衡可调
- ❌ 失败处理：简化将领网络为固定参数（去掉关系矩阵和动态忠诚度），保留命令偏差作为简化随机系统
- 🛑 止损条件：不适用（此阶段不会终止项目，只会简化scope）

**内容同步**: 历史科普视频 —「拿破仑百日的真实决策：Ney为什么倒戈？」

### M4: 内容填充（W15-W19）🔶 进行中 82%

**目标**: 用LLM批量生成所有文本内容，填充100天的完整事件池

**交付物**:

- [x] 历史事件池（当前33条，含5条叙事/事件）`src/data/events/historical.json` ← 仍需扩充至300-500条，Day10-19已填充
- [x] 司汤达日记文本池（8类决策 × 5变体）`src/data/narratives/stendhal_diary.json`
- [x] 微叙事后果片段池（6类 × 5条）`src/data/narratives/consequences.json`
- [x] **叙事引擎**：`NarrativePool` 接入 `GameEngine`，`process_day()` 后提供 `DayReport`
- [ ] 政策描述 + 后果文本
- [ ] 结局文本（4-6个主要结局路径 × 2-3个变体）
- [ ] 文本质量审核（人工检查LLM输出的历史准确性和文风一致性）

**内容同步**: devlog #5-6 —「用AI写历史叙事：方法和陷阱」

### M5: 美术与音乐（W20-W23）

**目标**: 将占位符UI升级为Vic3/Anno 1800品质的完整视觉体验

**交付物**:

- [ ] 法国地图底图（AI生成4096x3072深色地形图 + Godot 7层叠加渲染）
- [ ] 15-20个角色肖像（新古典主义数字油画风格，SD/MJ生成 + 统一调色 + 圆框裁切）
- [ ] UI组件精修（将M0.5基础组件升级：添加纹理、光效、动画细节）
- [ ] Rouge/Noir动态配色shader（全局色调随政治指针实时渐变）
- [ ] 决策卡片插图（每种决策类型1张缩略图，共15-20张，AI批量生成）
- [ ] 主菜单界面（深色+帝国鹰+金色标题，参考Anno 1800模式选择界面品质）
- [ ] 战斗结算界面 + 结局画面
- [ ] 图标徽章系统（资源/性格/势力图标，金属浮雕风，参考Vic3/Anno 1800）
- [ ] 6-8首原创BGM（AI生成 → 筛选 → 后期）
- [ ] 音效（行军、战斗、政治事件提示音）
- [ ] **Steam商店页面上线**，开始收集wishlist

**⛳ GATE 3（发布前2个月，约W23）**: Wishlist是否达标？

- ✅ 通过条件：wishlist ≥ 500 → 按计划发布
- ⚠️ 警告区：wishlist 200-500 → 加强市场推广，考虑延期1-2个月
- ❌ 不足：wishlist < 200 → 重新评估市场策略、定位、发布时机

**内容同步**: Steam页面上线推广 + devlog发布节奏加快

### M6: 打磨与发布（W24-W30）

**目标**: 平衡调试、bug修复、发布

**交付物**:

- [ ] 系统平衡最终调试（蒙特卡洛模拟1000局 + 人工测试）
- [ ] 难度分级（3档：Elba / Borodino / Austerlitz）
- [ ] 成就系统（15-20个Steam成就）
- [ ] 新手引导（前10天作为隐式教程）
- [ ] Bug修复 + 性能优化
- [ ] Launch trailer制作
- [ ] Steam审核提交
- [ ] **发布**

**内容同步**: devlog #7 — 发布倒计时 + launch day社交媒体推广

-----

## 6. 止损条件汇总

|时间点        |检查项           |止损动作                 |
|-----------|--------------|---------------------|
|W7（GATE 1） |核心循环是否好玩      |不好玩 → 终止或转向黑死病方案     |
|W14（GATE 2）|三系统耦合能否平衡     |失控 → 砍掉将领网络复杂度       |
|W23（GATE 3）|Wishlist ≥ 500|不达标 → 重评市场策略         |
|任何时间       |连续2周零进度       |评估是否工作/生活压力过大，调整节奏或暂停|

-----

## 7. 内容创作计划（与开发同步）

开发过程本身就是内容引擎。三条内容线并行：

### 7.1 Devlog系列（B站 + YouTube）

|期号|时间    |主题                        |目标       |
|--|------|--------------------------|---------|
|#1|W1-2  |一个光伏算法工程师为什么要做拿破仑游戏       |建立叙事，吸引关注|
|#2|W4-5  |行军系统：当能源调度算法遇到拿破仑         |技术差异化展示  |
|#3|W6-7  |100天的节奏感：回合制设计的数学         |游戏设计思考   |
|#4|W8-11 |Rouge et Noir：如何用优化模型做政治博弈|系统设计深度   |
|#5|W15-17|用AI写历史叙事：司汤达会怎么评价你的决策     |AI应用展示   |
|#6|W18-19|用AI画拿破仑：游戏美术的AI工作流        |美术制作过程   |
|#7|W27-30|发布倒计时 + 幕后花絮              |发布造势     |

### 7.2 历史科普短视频（抖音/TikTok/Shorts）

- 拿破仑百日的真实时间线
- Ney元帅：历史上最戏剧性的倒戈
- 滑铁卢：如果Grouchy早到两小时
- 为什么说百日王朝是一场赌博

### 7.3 技术博客（知乎/Medium）

- 从光伏调度到游戏AI：约束优化的跨域迁移
- Godot 4做回合制策略游戏的经验
- 用蒙特卡洛模拟做游戏平衡性测试

-----

## 8. 商业化路径

### 8.1 发布策略

```
Steam页面上线（W19）
    │
    ├──► wishlist积累期（W19-W28）
    │    - devlog推广
    │    - 历史/游戏社区互动
    │    - 发送review keys给策略游戏YouTuber/UP主
    │
    ▼
正式发布（W28）—— $12.99
    │
    ├──► 发布后1个月：收集反馈，快速修bug
    │
    ├──► 发布后3个月：根据数据决定是否做DLC
    │    候选DLC方向：
    │    - 埃及远征（1798，同引擎新场景）
    │    - 第一次意大利战役（1796，同引擎新场景）
    │    - 莫斯科撤退（1812，"衰败管理"变体）
    │
    └──► 发布后6个月：评估移动端移植可行性
```

### 8.2 收入预期（保守估算）

|场景|首年销量         |首年收入（税后）         |
|--|-------------|-----------------|
|悲观|1,000-3,000  |$8,000-$25,000   |
|基准|5,000-10,000 |$40,000-$80,000  |
|乐观|15,000-30,000|$120,000-$250,000|


> 注：独立策略游戏的Steam中位销量约2,000-5,000份。拿破仑题材+独特定位可能推高至基准以上。

### 8.3 成功标准

- **最低成功（Minimum Viable Success）**: 覆盖开发期间的机会成本（约5万RMB） + 建立个人品牌 + 验证开发pipeline
- **商业成功**: 首年收入覆盖一年生活成本（约8-10万RMB） + Steam评价 ≥ “多半好评”
- **超预期**: 成为独立策略游戏品类的话题产品 + DLC/续作有商业基础

-----

## 9. 风险登记簿

|风险           |概率|影响|缓解措施               |
|-------------|--|--|-------------------|
|核心循环不好玩      |中 |致命|GATE 1在W6强制检查，尽早暴露 |
|Scope失控（功能膨胀）|高 |严重|严格遵守3系统上限，YAGNI原则  |
|美术质量不达标      |中 |中等|选择手绘/插画风格降低写实要求    |
|工作精力冲突       |高 |中等|设定每周最低开发时间，接受进度弹性  |
|历史准确性被质疑     |中 |低 |标注”历史启发的策略游戏”，不宣称模拟|
|AI生成文本质量波动   |中 |低 |人工审核全部文本，LLM只做初稿   |
|Steam审核/上架问题 |低 |中等|提前研究Steam政策，避免敏感内容 |

-----

## 附录A：核心数学模型速写

### A.1 战斗解算

```python
# 简化版战斗解算（Python伪代码，最终用GDScript实现）
def resolve_battle(attacker, defender, terrain):
    """
    自动解算战斗结果
    attacker/defender: {troops, morale, fatigue, general_skill}
    terrain: {defense_bonus, attrition_rate}
    """
    ATK_SCORE = (attacker.troops
                 * attacker.morale
                 * (1 + attacker.general_skill * 0.01)
                 * (1 - attacker.fatigue * 0.5))

    DEF_SCORE = (defender.troops
                 * defender.morale
                 * (1 + defender.general_skill * 0.01)
                 * terrain.defense_bonus)

    # 托尔斯泰式不确定性
    RANDOM_FACTOR = uniform(-0.15, 0.15)
    RATIO = ATK_SCORE / DEF_SCORE * (1 + RANDOM_FACTOR)

    if RATIO > 1.5:
        return DECISIVE_VICTORY
    elif RATIO > 1.1:
        return MARGINAL_VICTORY
    elif RATIO > 0.9:
        return STALEMATE
    elif RATIO > 0.6:
        return MARGINAL_DEFEAT
    else:
        return DECISIVE_DEFEAT
```

### A.2 命令偏差模型

```python
def calculate_deviation(order, general, distance):
    """
    计算将领执行命令时的偏差
    order: 玩家下达的命令
    general: 将领数据（含性格参数）
    distance: 通信距离（节点数）
    """
    BASE = 1.0 - (general.loyalty / 100) * 0.5  # 忠诚度越高偏差越小

    TEMPERAMENT_MAP = {
        "cautious":  {"delay": 0.3, "aggression": -0.2},
        "balanced":  {"delay": 0.0, "aggression": 0.0},
        "impulsive": {"delay": -0.2, "aggression": 0.3},
        "reckless":  {"delay": -0.3, "aggression": 0.5},
    }

    DISTANCE_PENALTY = distance * 0.05  # 每个节点增加5%偏差

    deviation = {
        "timing": BASE * TEMPERAMENT_MAP[general.temperament]["delay"]
                  + DISTANCE_PENALTY,
        "force_commitment": BASE * TEMPERAMENT_MAP[general.temperament]["aggression"],
    }

    return deviation
```

-----

## 附录B：参考资料

### 历史资料

- Chandler, David. *The Campaigns of Napoleon*. 1966.
- Roberts, Andrew. *Napoleon: A Life*. 2014.
- Zamoyski, Adam. *1815: Napoleon’s Last Gamble*. (百日王朝专著)
- Dallas, Gregor. *The Final Act: The Roads to Waterloo*. 1997.

### 文学参考

- 司汤达.《红与黑》/ *Le Rouge et le Noir*. 1830.
- 雨果.《悲惨世界》/ *Les Misérables*. 1862.（第二卷”滑铁卢”章节）
- 托尔斯泰.《战争与和平》/ *War and Peace*. 1869.

### 游戏设计参考

- Crusader Kings III — 人物关系网络设计
- Europa Universalis V — 政治合法性系统
- Into the Breach — 紧凑回合制的信息透明度设计
- Slay the Spire — roguelike式replay value的实现方式

### 技术参考

- Godot 4 官方文档: https://docs.godotengine.org
- GDScript风格指南: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html

-----

*La beauté est une promesse de bonheur. — Stendhal*
