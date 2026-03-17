## OrderDeviation — 命令偏差模型
## 实现计划书附录A.2：将领执行命令时的系统性偏差

class_name OrderDeviation
extends RefCounted

# ── 性格偏差参数表 ────────────────────────────────────
## timing > 0 = 更可能延迟行动；timing < 0 = 更可能提前行动
## force_commitment > 0 = 投入更多兵力；< 0 = 保守用兵
const TEMPERAMENT_PROFILES: Dictionary = {
	"cautious": {
		"timing": 0.30,
		"force_commitment": -0.20,
		"description": "谨慎型将领倾向于等待更明确的命令，投入兵力保守"
	},
	"balanced": {
		"timing": 0.0,
		"force_commitment": 0.0,
		"description": "均衡型将领基本按命令执行，偏差最小"
	},
	"impulsive": {
		"timing": -0.20,
		"force_commitment": 0.30,
		"description": "冲动型将领倾向于提前行动，投入超出命令的兵力（如Ney在滑铁卢）"
	},
	"reckless": {
		"timing": -0.30,
		"force_commitment": 0.50,
		"description": "鲁莽型将领几乎必然激进化命令，有时带来奇效，有时造成灾难"
	}
}

const DISTANCE_PENALTY_PER_NODE: float = 0.05  # 每个节点距离增加5%偏差
const MAX_DISTANCE_PENALTY: float = 0.40        # 最大通信距离惩罚40%

# ── 偏差计算主函数 ────────────────────────────────────

## 计算命令执行偏差
## order: {type, target, troops_assigned}
## character: 将领数据字典（含 loyalty, temperament）
## communication_distance: 与拿破仑司令部的节点距离
## battlefield_chaos: 0.0-1.0 战场混乱程度（影响随机扰动）
func calculate(
	order: Dictionary,
	character: Dictionary,
	communication_distance: int,
	battlefield_chaos: float = 0.0
) -> Dictionary:
	var loyalty: float = float(character.get("loyalty", 50))
	var temperament: String = character.get("temperament", "balanced")

	# 基础偏差系数（忠诚度越高偏差越小）
	var base_reliability: float = 1.0 - (loyalty / 100.0) * 0.5
	# 忠诚度100 → base = 0.5；忠诚度0 → base = 1.0

	# 性格偏差
	var profile: Dictionary = TEMPERAMENT_PROFILES.get(temperament, TEMPERAMENT_PROFILES["balanced"])

	# 通信距离惩罚
	var distance_penalty: float = minf(
		communication_distance * DISTANCE_PENALTY_PER_NODE,
		MAX_DISTANCE_PENALTY
	)

	# 战场混乱扰动（随机，范围由chaos决定）
	var chaos_noise: float = randf_range(-battlefield_chaos * 0.1, battlefield_chaos * 0.1)

	# 最终偏差
	var timing_deviation: float = (
		base_reliability * profile["timing"] + distance_penalty + chaos_noise
	)
	var force_deviation: float = (
		base_reliability * profile["force_commitment"] + chaos_noise * 0.5
	)

	var result := {
		"character_id": character.get("id", "unknown"),
		"character_name": character.get("name", "未知将领"),
		"timing_deviation": timing_deviation,       # 正=延迟，负=提前（小时级）
		"force_deviation": force_deviation,         # 正=过度进攻，负=保守
		"order_followed": _should_follow_order(loyalty, battlefield_chaos),
		"base_reliability": base_reliability,
		"distance_penalty": distance_penalty,
		"temperament_note": profile["description"]
	}

	# 生成叙事描述
	result["narrative"] = _generate_deviation_narrative(result, character, order)

	return result

## 判断将领是否会完全违抗命令（极端情况）
func _should_follow_order(loyalty: float, chaos: float) -> bool:
	# 忠诚度<30时有概率完全违抗
	if loyalty < 30.0:
		var defection_chance: float = (30.0 - loyalty) / 30.0 * 0.4  # 最高40%违抗率
		defection_chance += chaos * 0.1
		return randf() > defection_chance
	return true

## 生成偏差叙事文本（占位符，M4阶段用LLM批量生成替换）
func _generate_deviation_narrative(
	deviation: Dictionary,
	character: Dictionary,
	_order: Dictionary
) -> String:
	if not deviation["order_followed"]:
		return "%s 拒绝执行命令。" % character.get("name", "将领")

	var timing := deviation["timing_deviation"]
	var force := deviation["force_deviation"]
	var name: String = character.get("name", "将领")

	if timing < -0.15 and force > 0.2:
		return "%s 比命令提前行动，并投入了远超预期的兵力。" % name
	elif timing > 0.2:
		return "%s 的行动比预期晚了几个小时。" % name
	elif force > 0.3:
		return "%s 按时行动，但投入了额外的预备队。" % name
	elif force < -0.2:
		return "%s 执行了命令，但刻意保留了部分兵力。" % name
	else:
		return "%s 按照命令准确执行。" % name

# ── 历史典型场景 ──────────────────────────────────────

## 模拟内伊在滑铁卢的骑兵冲锋（历史案例）
static func simulate_ney_waterloo_scenario() -> Dictionary:
	var ney_data := {
		"id": "ney",
		"name": "Michel Ney",
		"loyalty": 65,
		"temperament": "impulsive"
	}
	var order := {
		"type": "cavalry_charge",
		"target": "wellington_center",
		"troops_assigned": 5000  # 实际命令：试探性骑兵行动
	}
	var deviation_calc := OrderDeviation.new()
	var result := deviation_calc.calculate(ney_data, order, 0, 0.6)
	# 内伊实际投入了~10,000骑兵进行无步兵支援的冲锋
	result["historical_note"] = "内伊误判英军中路移动为撤退，发动了无步兵支援的大规模骑兵冲锋"
	return result

## 模拟格鲁希的Wavre追击犹豫（历史案例）
static func simulate_grouchy_wavre_scenario() -> Dictionary:
	var grouchy_data := {
		"id": "grouchy",
		"name": "Emmanuel de Grouchy",
		"loyalty": 75,
		"temperament": "cautious"
	}
	var order := {
		"type": "pursue_prussians",
		"target": "prussian_army",
		"troops_assigned": 33000
	}
	var deviation_calc := OrderDeviation.new()
	var result := deviation_calc.calculate(grouchy_data, order, 3, 0.4)
	result["historical_note"] = "格鲁希在Wavre执行追击命令时，听到滑铁卢方向炮声，但坚持字面命令而未回援"
	return result
