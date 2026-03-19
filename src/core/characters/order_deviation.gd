## OrderDeviation — 命令偏差代理层（v2）
## 实际计算委托给 CharacterManager GDExtension 节点（Rust）
## 本脚本保留 UI 描述数据和历史场景示例

class_name OrderDeviation
extends RefCounted

# ── 性格描述（UI 展示用，与 Rust Temperament 枚举一致）────
const TEMPERAMENT_PROFILES: Dictionary = {
	"cautious": {
		"label":       "谨慎",
		"timing_hint": "倾向延迟执行，等待更明确的命令",
		"force_hint":  "投入兵力保守，通常低于命令要求",
		"icon":        "🛡",
		"example":     "格鲁希在Wavre，听炮声而不回援"
	},
	"balanced": {
		"label":       "均衡",
		"timing_hint": "基本按命令时间执行",
		"force_hint":  "按命令兵力执行，偏差最小",
		"icon":        "⚖",
		"example":     "达武，执行命令精确，极少逾矩"
	},
	"impulsive": {
		"label":       "冲动",
		"timing_hint": "倾向提前行动，不等确认信号",
		"force_hint":  "投入超出命令的兵力",
		"icon":        "⚡",
		"example":     "内伊在滑铁卢，误判英军撤退发动骑兵冲锋"
	},
	"reckless": {
		"label":       "鲁莽",
		"timing_hint": "几乎必然提前激进化命令",
		"force_hint":  "倾向全力投入，保留极少预备队",
		"icon":        "🔥",
		"example":     "极端情形下可能带来奇效，也可能带来灾难"
	}
}

# ── CharacterManager GDExtension 节点引用 ──────────────
## 在场景中通过 @export 或代码连接
var _character_manager: CharacterManager

func _init(character_manager_node: CharacterManager = null) -> void:
	_character_manager = character_manager_node

# ── 核心计算（委托给 Rust）────────────────────────────────

## 计算命令执行偏差
## character: 将领数据字典 {id, name, loyalty, temperament, military_skill}
## communication_distance: 与拿破仑司令部的节点距离
## battlefield_chaos: 0.0-1.0 战场混乱程度
## 返回: DeviationResult 字典（与 Rust calculate_deviation 输出一致）
func calculate(
	character: Dictionary,
	communication_distance: int,
	battlefield_chaos: float = 0.0
) -> Dictionary:
	if _character_manager:
		return _character_manager.calculate_deviation(
			character,
			communication_distance,
			battlefield_chaos
		)
	# GDExtension 未加载时的降级回退（维持开发可运行性）
	push_warning("[OrderDeviation] CharacterManager 未连接，使用降级回退")
	return _fallback_calculate(character, communication_distance, battlefield_chaos)

## GDExtension 未加载时的简化回退实现
func _fallback_calculate(
	character: Dictionary,
	communication_distance: int,
	battlefield_chaos: float
) -> Dictionary:
	const DISTANCE_PENALTY_PER_NODE := 0.05
	const MAX_DISTANCE_PENALTY := 0.40

	var loyalty: float         = float(character.get("loyalty", 50))
	var temperament: String    = character.get("temperament", "balanced")
	var base_reliability: float = 1.0 - (loyalty / 100.0) * 0.5
	var distance_penalty: float = minf(
		communication_distance * DISTANCE_PENALTY_PER_NODE,
		MAX_DISTANCE_PENALTY
	)
	var chaos_noise: float = randf_range(-battlefield_chaos * 0.1, battlefield_chaos * 0.1)

	var timing_bias: float
	var force_bias: float
	match temperament:
		"cautious":   timing_bias =  0.30; force_bias = -0.20
		"impulsive":  timing_bias = -0.20; force_bias =  0.30
		"reckless":   timing_bias = -0.30; force_bias =  0.50
		_:            timing_bias =  0.0;  force_bias =  0.0

	var timing_dev: float = base_reliability * timing_bias + distance_penalty + chaos_noise
	var force_dev: float  = base_reliability * force_bias + chaos_noise * 0.5
	var order_followed: bool = loyalty >= 30.0 or randf() > (30.0 - loyalty) / 30.0 * 0.4

	return {
		"general_id":        character.get("id", "unknown"),
		"general_name":      character.get("name", "未知将领"),
		"timing_deviation":  timing_dev,
		"force_deviation":   force_dev,
		"order_followed":    order_followed,
		"base_reliability":  base_reliability,
		"distance_penalty":  distance_penalty,
		"narrative":         _simple_narrative(character.get("name", "将领"), timing_dev, force_dev, order_followed)
	}

func _simple_narrative(name: String, timing: float, force: float, followed: bool) -> String:
	if not followed:
		return "%s 拒绝执行命令。" % name
	if timing < -0.15 and force > 0.2:
		return "%s 比命令提前行动，并投入了远超预期的兵力。" % name
	elif timing > 0.2:
		return "%s 的行动比预期晚了几个小时。" % name
	elif force > 0.3:
		return "%s 按时行动，但投入了额外的预备队。" % name
	elif force < -0.2:
		return "%s 执行了命令，但刻意保留了部分兵力。" % name
	return "%s 按照命令准确执行。" % name

# ── 性格 UI 辅助 ──────────────────────────────────────

func get_temperament_label(temperament: String) -> String:
	return TEMPERAMENT_PROFILES.get(temperament, TEMPERAMENT_PROFILES["balanced"])["label"]

func get_temperament_description(temperament: String) -> Dictionary:
	return TEMPERAMENT_PROFILES.get(temperament, TEMPERAMENT_PROFILES["balanced"])

# ── 历史典型场景（用于教程/展示）─────────────────────────

static func get_ney_waterloo_example() -> Dictionary:
	return {
		"character": {
			"id": "ney", "name": "Michel Ney",
			"loyalty": 65, "temperament": "impulsive", "military_skill": 85
		},
		"distance": 0,
		"chaos": 0.6,
		"historical_note": "内伊误判英军中路移动为撤退，发动了无步兵支援的大规模骑兵冲锋"
	}

static func get_grouchy_wavre_example() -> Dictionary:
	return {
		"character": {
			"id": "grouchy", "name": "Emmanuel de Grouchy",
			"loyalty": 75, "temperament": "cautious", "military_skill": 70
		},
		"distance": 3,
		"chaos": 0.4,
		"historical_note": "格鲁希在Wavre执行追击命令时，听到滑铁卢方向炮声，但坚持字面命令而未回援"
	}
