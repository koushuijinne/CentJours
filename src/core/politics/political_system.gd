## PoliticalSystem — 政治状态显示层（v2）
## 执行逻辑已移至 CentJoursEngine（Rust）
## 本脚本只提供 UI 所需的展示数据：政策列表、派系趋势、R/N 效果说明

class_name PoliticalSystem
extends Node

# ── Rouge/Noir 效果说明（UI 展示用，与 Rust 引擎参数一致）────
const ROUGE_EFFECTS: Dictionary = {
	"conscription_efficiency": "征兵效率 +3%/10点",
	"populace_support_gain":   "民众支持获取 +2%/10点",
	"foreign_intervention_risk": "外国干预意愿 +4%/10点（负面）",
	"nobility_defection_risk": "贵族叛逃风险 +3%/10点（负面）"
}

const NOIR_EFFECTS: Dictionary = {
	"admin_efficiency":    "行政效率 +3%/10点",
	"diplomatic_space":    "外交谈判空间 +2%/10点",
	"populace_enthusiasm": "民众热情 -3%/10点（负面）",
	"military_cost_base":  "军费基础效率 +2%/10点"
}

# ── 政策元数据（仅用于 UI 展示名称、描述、费用）────────────
## 与 Rust 侧 default_policies() 的 ID 保持一致
const POLICY_META: Dictionary = {
	"conscription": {
		"name": "颁布征兵令",
		"cost": 1,
		"rouge_noir_hint": "+5 Rouge",
		"summary": "增加军事支持，削弱民众和自由派"
	},
	"constitutional_promise": {
		"name": "承诺宪政改革",
		"cost": 1,
		"rouge_noir_hint": "-8 Noir",
		"summary": "大幅提升自由派支持，削弱贵族"
	},
	"public_speech": {
		"name": "发表公开演说",
		"cost": 1,
		"rouge_noir_hint": "+3 Rouge",
		"summary": "提升民众支持，小幅削弱贵族"
	},
	"grant_titles": {
		"name": "授予贵族头衔",
		"cost": 1,
		"rouge_noir_hint": "-5 Noir",
		"summary": "提升贵族支持，削弱自由派和民众"
	},
	"reduce_taxes": {
		"name": "减税措施",
		"cost": 1,
		"rouge_noir_hint": "±0",
		"summary": "提升民众和自由派支持，经济损耗"
	},
	"increase_military_budget": {
		"name": "增加军费",
		"cost": 1,
		"rouge_noir_hint": "+4 Rouge",
		"summary": "大幅提升军队支持，削弱自由派，经济重度损耗"
	},
	"requisition_supplies": {
		"name": "征用沿线仓储",
		"cost": 1,
		"rouge_noir_hint": "+4 Rouge",
		"summary": "快速回补补给，代价是激怒沿线民众与自由派"
	},
	"secret_diplomacy": {
		"name": "秘密外交（分化反法同盟）",
		"cost": 2,
		"rouge_noir_hint": "-3 Noir",
		"summary": "花费2行动点，有概率延缓反法同盟集结"
	},
	"print_money": {
		"name": "印钞应急",
		"cost": 1,
		"rouge_noir_hint": "+8 Rouge",
		"summary": "短期经济救急，长期通胀削弱所有派系"
	}
}

# ── 查询接口（供 UI 调用）────────────────────────────────

## 获取政策显示列表，冷却剩余天数从 GameState.policy_cooldowns 读取（Rust 权威数据）
func get_policy_list(actions_remaining: int) -> Array:
	var result: Array = []
	for policy_id in POLICY_META:
		var meta: Dictionary = POLICY_META[policy_id]
		# 从 GameState 缓存读取真实冷却剩余天数（由 TurnManager 从 Rust 引擎同步）
		var cd_remaining: int = int(GameState.policy_cooldowns.get(policy_id, 0))
		result.append({
			"id":               policy_id,
			"name":             meta["name"],
			"cost":             meta["cost"],
			"cooldown_remaining": cd_remaining,
			"rouge_noir_hint":  meta["rouge_noir_hint"],
			"summary":          meta["summary"],
			"affordable":       actions_remaining >= meta["cost"] and cd_remaining == 0
		})
	return result

## 获取各派系趋势（从 GameState 读取，TurnManager 已同步引擎数据）
func get_faction_trends() -> Dictionary:
	var trends := {}
	for faction_id in GameState.faction_support:
		var support: float = GameState.faction_support[faction_id]
		var trend: String
		if support < 20.0:
			trend = "critical"
		elif support < 35.0:
			trend = "declining"
		elif support > 75.0:
			trend = "strong"
		else:
			trend = "stable"
		trends[faction_id] = {"support": support, "trend": trend}
	return trends

## 获取当前 Rouge/Noir 状态对应的效果描述（供 UI 工具提示）
func get_rouge_noir_tooltip() -> Dictionary:
	var rn: float = GameState.rouge_noir_index
	var active_effects: Array = []

	if rn > 0:
		for effect_key in ROUGE_EFFECTS:
			active_effects.append(ROUGE_EFFECTS[effect_key])
		return {
			"direction": "rouge",
			"value": rn,
			"label": "倾向革命（Rouge +%.0f）" % rn,
			"effects": active_effects
		}
	elif rn < 0:
		for effect_key in NOIR_EFFECTS:
			active_effects.append(NOIR_EFFECTS[effect_key])
		return {
			"direction": "noir",
			"value": -rn,
			"label": "倾向保守（Noir +%.0f）" % -rn,
			"effects": active_effects
		}
	return {
		"direction": "neutral",
		"value": 0.0,
		"label": "政治中立",
		"effects": []
	}
