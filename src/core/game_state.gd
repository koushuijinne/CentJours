## GameState — 全局游戏状态管理（自动加载单例）
## 所有系统通过 GameState 共享数据，通过 EventBus 通信

extends Node

# ── 常量 ──────────────────────────────────────────────
const MAX_DAYS: int = 100
const ELBA_START_DAY: int = 1
const PARIS_ARRIVAL_DAY: int = 20
const WATERLOO_DAY: int = 100

# 以下阈值与 Rust 层同源，修改时须两处同步：
# POLITICAL_CRISIS_THRESHOLD    → politics/system.rs::CRISIS_THRESHOLD
# DEFECTION_LOYALTY_THRESHOLD   → characters/network.rs::LOYALTY_CRISIS_THRESHOLD
# UNCONDITIONAL_LOYALTY_THRESHOLD→ characters/network.rs::LOYALTY_ABSOLUTE_THRESHOLD
const POLITICAL_CRISIS_THRESHOLD: float = 10.0
const DEFECTION_LOYALTY_THRESHOLD: float = 30.0
const UNCONDITIONAL_LOYALTY_THRESHOLD: float = 80.0

const DATA_PATH: String = "res://src/data/"

# ── 回合状态 ──────────────────────────────────────────
var current_day: int = 1
var current_phase: String = "dawn"  # dawn / action / dusk

# ── 行军与战役状态 ─────────────────────────────────────
var armies: Dictionary = {}         # army_id -> ArmyData
var map_control: Dictionary = {}    # node_id -> controller ("napoleon" / "enemy" / "neutral")
var napoleon_location: String = "golfe_juan"
var available_march_targets: Array[String] = []
var forward_depot_location: String = ""
var forward_depot_capacity_bonus: int = 0
var forward_depot_days: int = 0
var logistics_posture_id: String = ""
var logistics_posture_label: String = ""
var logistics_focus_title: String = ""
var logistics_focus_detail: String = ""
var logistics_focus_short: String = ""
var logistics_runway_days: int = -1
var logistics_runway_label: String = ""

# 军队摘要（从 CentJoursEngine.get_state() 同步，只读缓存）
var total_troops: int   = 6000   # 当前总兵力
var avg_morale:   float = 70.0   # 平均士气 0-100
var avg_fatigue:  float = 20.0   # 平均疲劳 0-100
var supply:       float = 60.0   # 当前补给值 0-100
var victories:    int   = 0      # 已赢得的战役场次

# ── 政治状态 ──────────────────────────────────────────
## rouge_noir: -100（极端革命）到 +100（极端保守），0为均衡
var rouge_noir_index: float = 0.0

var faction_support: Dictionary = {
	"liberals": 45.0,    # 议会自由派
	"nobility":  30.0,   # 旧贵族/教会
	"populace":  65.0,   # 巴黎民众
	"military":  70.0    # 军方
}

var legitimacy: float = 50.0        # 整体合法性，来自四势力的加权平均
var economic_index: float = 50.0    # 经济状况，影响民心和军费
var actions_remaining: int = 2      # 每回合可执行的政策行动数
var policy_cooldowns: Dictionary = {}  # 政策冷却缓存（policy_id → 剩余天数），由 TurnManager 从引擎同步

# ── 将领状态 ──────────────────────────────────────────
var characters: Dictionary = {}     # character_id -> CharacterData（运行时状态）

# ── 叙事状态 ──────────────────────────────────────────
var stendhal_diary: Array = []      # 每日记录
var triggered_events: Array = []    # 已触发的历史事件 id 列表

# ── 难度 ──────────────────────────────────────────────
var difficulty: String = "borodino"  # elba / borodino / austerlitz

# ── 初始化 ────────────────────────────────────────────
func _ready() -> void:
	_load_all_data()

func _load_all_data() -> void:
	_load_characters()
	_load_map()

func _load_characters() -> void:
	var file := FileAccess.open(DATA_PATH + "characters.json", FileAccess.READ)
	if not file:
		push_error("无法加载 characters.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("characters.json 解析失败")
		return
	for char_data in json.data["characters"]:
		characters[char_data["id"]] = char_data.duplicate(true)

func _load_map() -> void:
	var file := FileAccess.open(DATA_PATH + "map_nodes.json", FileAccess.READ)
	if not file:
		push_error("无法加载 map_nodes.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("map_nodes.json 解析失败")
		return
	# 初始化地图控制权
	for node_data in json.data["nodes"]:
		var nid: String = node_data["id"]
		# 法国境内初始为拿破仑/中立，比利时境内为敌方
		if node_data.get("region", "") in ["brabant", "namur", "hainaut"]:
			map_control[nid] = "enemy"
		else:
			map_control[nid] = "neutral"
	map_control["golfe_juan"] = "napoleon"

# ── 辅助方法 ──────────────────────────────────────────

## 获取角色当前忠诚度（只读，供 CharacterManager / UI 查询）
func get_loyalty(character_id: String) -> float:
	if character_id in characters:
		return float(characters[character_id].get("loyalty", 50))
	return 0.0

## [废弃] 合法性由 CentJoursEngine 权威维护，通过 TurnManager._sync_state_from_engine() 同步
## 不应在 GDScript 层自行计算合法性
func recalculate_legitimacy() -> void:
	push_warning("[GameState] recalculate_legitimacy() 已废弃，legitimacy 由 CentJoursEngine 权威维护，请勿直接调用")

## [废弃] 派系支持度由 CentJoursEngine 权威维护，变化须通过 TurnManager.submit_action() 驱动
func modify_faction_support(_faction_id: String, _delta: float) -> void:
	push_warning("[GameState] modify_faction_support() 已废弃，请通过 engine action 驱动派系变化")

## [废弃] rouge_noir 由 CentJoursEngine 权威维护，TurnManager._sync_state_from_engine() 负责同步
func shift_rouge_noir(_delta: float) -> void:
	push_warning("[GameState] shift_rouge_noir() 已废弃，rouge_noir 由 CentJoursEngine 权威维护")

## [废弃] 忠诚度由 CentJoursEngine 权威维护，将通过 engine.get_all_loyalties() 同步（见 task ③④）
func modify_loyalty(_character_id: String, _delta: float) -> void:
	push_warning("[GameState] modify_loyalty() 已废弃，忠诚度变化须通过 engine action 驱动")

## 检查游戏结束条件
func check_game_over() -> String:
	if current_day > MAX_DAYS:
		return "waterloo_historical"
	if legitimacy < 5.0:
		return "political_collapse"
	# 其余结局由事件系统触发
	return ""
