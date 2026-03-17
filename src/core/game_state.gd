## GameState — 全局游戏状态管理（自动加载单例）
## 所有系统通过 GameState 共享数据，通过 EventBus 通信

extends Node

# ── 常量 ──────────────────────────────────────────────
const MAX_DAYS: int = 100
const ELBA_START_DAY: int = 1
const PARIS_ARRIVAL_DAY: int = 20
const WATERLOO_DAY: int = 100

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

## 计算整体合法性（四势力加权平均）
func recalculate_legitimacy() -> void:
	var weights := {"liberals": 0.25, "nobility": 0.20, "populace": 0.30, "military": 0.25}
	var total := 0.0
	for faction_id in weights:
		total += faction_support[faction_id] * weights[faction_id]
	var old_legitimacy := legitimacy
	legitimacy = total
	if abs(legitimacy - old_legitimacy) > 0.01:
		EventBus.legitimacy_changed.emit(old_legitimacy, legitimacy)

## 获取角色当前忠诚度
func get_loyalty(character_id: String) -> float:
	if character_id in characters:
		return float(characters[character_id].get("loyalty", 50))
	return 0.0

## 修改角色忠诚度，并发出信号
func modify_loyalty(character_id: String, delta: float) -> void:
	if not character_id in characters:
		return
	var old_val := float(characters[character_id]["loyalty"])
	var new_val := clampf(old_val + delta, 0.0, 100.0)
	characters[character_id]["loyalty"] = new_val
	EventBus.loyalty_changed.emit(character_id, old_val, new_val)
	_check_loyalty_thresholds(character_id, new_val)

func _check_loyalty_thresholds(character_id: String, loyalty: float) -> void:
	if loyalty < DEFECTION_LOYALTY_THRESHOLD:
		# 触发叛逃风险检查（由 CharacterManager 处理）
		EventBus.loyalty_changed.emit(character_id, loyalty + 1.0, loyalty)

## 修改派系支持度
func modify_faction_support(faction_id: String, delta: float) -> void:
	if not faction_id in faction_support:
		return
	var old_val := faction_support[faction_id]
	faction_support[faction_id] = clampf(old_val + delta, 0.0, 100.0)
	EventBus.faction_support_changed.emit(faction_id, old_val, faction_support[faction_id])
	if faction_support[faction_id] < POLITICAL_CRISIS_THRESHOLD:
		EventBus.political_crisis.emit(faction_id, "critical")
	recalculate_legitimacy()

## Rouge/Noir 指针移动（正值 → 偏Rouge，负值 → 偏Noir）
func shift_rouge_noir(delta: float) -> void:
	rouge_noir_index = clampf(rouge_noir_index + delta, -100.0, 100.0)

## 检查游戏结束条件
func check_game_over() -> String:
	if current_day > MAX_DAYS:
		return "waterloo_historical"
	if legitimacy < 5.0:
		return "political_collapse"
	# 其余结局由事件系统触发
	return ""
