## PoliticalSystem — 政治与合法性系统（Rouge/Noir + 四势力）

class_name PoliticalSystem
extends Node

# ── Rouge/Noir 效果配置 ──────────────────────────────
## 每10点偏移对应的加成/惩罚（线性插值）
const ROUGE_BONUSES: Dictionary = {
	"conscription_efficiency": 0.03,    # 征兵效率
	"populace_support_gain":   0.02,    # 民众支持获取速度
	"foreign_intervention_risk": 0.04,  # 外国干预意愿增加（负面）
	"nobility_defection_risk": 0.03     # 贵族叛逃风险增加（负面）
}

const NOIR_BONUSES: Dictionary = {
	"admin_efficiency":     0.03,  # 行政效率
	"diplomatic_space":     0.02,  # 外交谈判空间
	"populace_enthusiasm":  -0.03, # 民众热情（负面）
	"military_cost_base":   0.02   # 军费基础效率
}

# ── 政策定义 ──────────────────────────────────────────
## 从 policies.json 加载，这里是结构定义
## policy: {id, name, cost_actions, rouge_noir_delta, faction_deltas, economic_delta,
##          loyalty_deltas, duration, cooldown, conditions, consequences}

var _available_policies: Dictionary = {}   # policy_id -> policy_data
var _active_effects: Array = []            # 持续效果列表
var _policy_cooldowns: Dictionary = {}     # policy_id -> remaining_cooldown_days

func _ready() -> void:
	_load_policies()

func _load_policies() -> void:
	var file := FileAccess.open("res://src/data/policies.json", FileAccess.READ)
	if not file:
		push_warning("policies.json 未找到，使用内置默认政策")
		_load_default_policies()
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		for policy in json.data.get("policies", []):
			_available_policies[policy["id"]] = policy
	file.close()

func _load_default_policies() -> void:
	## 内置的基础政策集（用于开发早期无 JSON 时）
	_available_policies = {
		"conscription_decree": {
			"id": "conscription_decree",
			"name": "颁布征兵令",
			"cost_actions": 1,
			"rouge_noir_delta": 5.0,
			"faction_deltas": {"military": 10.0, "populace": -8.0, "liberals": -3.0},
			"economic_delta": -5.0,
			"cooldown": 5
		},
		"constitutional_promise": {
			"id": "constitutional_promise",
			"name": "承诺宪政改革",
			"cost_actions": 1,
			"rouge_noir_delta": -8.0,
			"faction_deltas": {"liberals": 15.0, "nobility": -5.0, "populace": 5.0},
			"cooldown": 10
		},
		"public_speech": {
			"id": "public_speech",
			"name": "发表公开演说",
			"cost_actions": 1,
			"rouge_noir_delta": 3.0,
			"faction_deltas": {"populace": 12.0, "nobility": -3.0},
			"economic_delta": 0.0,
			"cooldown": 3
		},
		"grant_titles": {
			"id": "grant_titles",
			"name": "授予贵族头衔",
			"cost_actions": 1,
			"rouge_noir_delta": -5.0,
			"faction_deltas": {"nobility": 12.0, "liberals": -5.0, "populace": -3.0},
			"cooldown": 7
		},
		"reduce_taxes": {
			"id": "reduce_taxes",
			"name": "减税措施",
			"cost_actions": 1,
			"rouge_noir_delta": 0.0,
			"faction_deltas": {"populace": 10.0, "liberals": 3.0},
			"economic_delta": -8.0,
			"cooldown": 8
		},
		"increase_military_budget": {
			"id": "increase_military_budget",
			"name": "增加军费",
			"cost_actions": 1,
			"rouge_noir_delta": 4.0,
			"faction_deltas": {"military": 15.0, "liberals": -5.0},
			"economic_delta": -10.0,
			"cooldown": 5
		},
		"secret_diplomacy": {
			"id": "secret_diplomacy",
			"name": "秘密外交（分化反法同盟）",
			"cost_actions": 2,
			"rouge_noir_delta": -3.0,
			"faction_deltas": {},
			"success_chance": 0.25,
			"cooldown": 15
		},
		"print_money": {
			"id": "print_money",
			"name": "印钞应急",
			"cost_actions": 1,
			"rouge_noir_delta": 8.0,
			"faction_deltas": {"populace": -5.0, "liberals": -8.0, "nobility": -5.0},
			"economic_delta": 15.0,   # 短期经济+，长期通胀
			"economic_delay_penalty": -20.0,
			"delay_days": 10,
			"cooldown": 20
		}
	}

# ── 政策执行 ──────────────────────────────────────────

## 执行一个政策行动
## action_data: {policy_id, optional_target}
func enact_policy(action_data: Dictionary) -> Dictionary:
	var policy_id: String = action_data.get("policy_id", "")
	if not policy_id in _available_policies:
		return {"success": false, "reason": "未知政策 %s" % policy_id}

	var policy: Dictionary = _available_policies[policy_id]

	# 检查行动点
	var cost: int = policy.get("cost_actions", 1)
	if GameState.actions_remaining < cost:
		return {"success": false, "reason": "行动点不足"}

	# 检查冷却
	if policy_id in _policy_cooldowns and _policy_cooldowns[policy_id] > 0:
		return {"success": false, "reason": "政策冷却中 (%d天)" % _policy_cooldowns[policy_id]}

	GameState.actions_remaining -= cost

	# 应用效果
	var results := _apply_policy_effects(policy)
	_policy_cooldowns[policy_id] = policy.get("cooldown", 0)

	EventBus.policy_enacted.emit(policy_id)
	return {"success": true, "results": results, "policy_name": policy.get("name", policy_id)}

func _apply_policy_effects(policy: Dictionary) -> Dictionary:
	var results := {}

	# Rouge/Noir 变化
	var rn_delta: float = policy.get("rouge_noir_delta", 0.0)
	if rn_delta != 0.0:
		GameState.shift_rouge_noir(rn_delta)
		results["rouge_noir_delta"] = rn_delta

	# 派系支持度变化
	var faction_deltas: Dictionary = policy.get("faction_deltas", {})
	for faction_id in faction_deltas:
		var delta: float = float(faction_deltas[faction_id])
		# Rouge/Noir 状态会放大或缩小某些效果
		delta = _apply_rouge_noir_modifier(faction_id, delta)
		GameState.modify_faction_support(faction_id, delta)

	# 经济变化
	var eco_delta: float = policy.get("economic_delta", 0.0)
	if eco_delta != 0.0:
		GameState.economic_index = clampf(GameState.economic_index + eco_delta, 0.0, 100.0)
		results["economic_delta"] = eco_delta

	# 将领忠诚度影响（如授予勋章）
	var loyalty_deltas: Dictionary = policy.get("loyalty_deltas", {})
	for char_id in loyalty_deltas:
		GameState.modify_loyalty(char_id, float(loyalty_deltas[char_id]))

	return results

## Rouge/Noir 状态对政策效果的修正
func _apply_rouge_noir_modifier(faction_id: String, base_delta: float) -> float:
	var rn := GameState.rouge_noir_index
	# 偏Rouge时，民众效果放大；偏Noir时，贵族效果放大
	match faction_id:
		"populace":
			if rn > 0:
				return base_delta * (1.0 + rn / 200.0)  # 最多+50%
		"nobility":
			if rn < 0:
				return base_delta * (1.0 + (-rn) / 200.0)
		"military":
			if rn > 0:
				return base_delta * (1.0 + rn / 300.0)
	return base_delta

# ── 每日更新 ──────────────────────────────────────────

## 每回合结算时调用
func daily_update() -> void:
	_update_cooldowns()
	_apply_active_effects()
	_apply_economic_drift()
	_check_faction_reactions()

func _update_cooldowns() -> void:
	for policy_id in _policy_cooldowns.keys():
		if _policy_cooldowns[policy_id] > 0:
			_policy_cooldowns[policy_id] -= 1

func _apply_active_effects() -> void:
	var expired: Array = []
	for effect in _active_effects:
		effect["remaining_days"] -= 1
		if effect["remaining_days"] <= 0:
			expired.append(effect)
	for e in expired:
		_active_effects.erase(e)

func _apply_economic_drift() -> void:
	## 经济缓慢自然恢复/下滑，受Rouge/Noir影响
	var drift := 0.5  # 基础每日微弱恢复
	if GameState.rouge_noir_index > 30:
		drift -= 0.3  # 过于激进的革命政策损害经济
	GameState.economic_index = clampf(GameState.economic_index + drift, 0.0, 100.0)

func _check_faction_reactions() -> void:
	## 极端Rouge/Noir状态下，各势力会产生自然的支持度变化
	var rn := GameState.rouge_noir_index
	if rn > 60:
		GameState.modify_faction_support("nobility", -0.5)
		GameState.modify_faction_support("populace", 0.3)
	elif rn < -60:
		GameState.modify_faction_support("populace", -0.5)
		GameState.modify_faction_support("nobility", 0.3)

# ── 信息查询 ──────────────────────────────────────────

## 获取可用政策列表（排除冷却中的）
func get_available_policies() -> Array:
	var result: Array = []
	for policy_id in _available_policies:
		var policy: Dictionary = _available_policies[policy_id]
		var on_cooldown: bool = _policy_cooldowns.get(policy_id, 0) > 0
		result.append({
			"id": policy_id,
			"name": policy.get("name", policy_id),
			"cost": policy.get("cost_actions", 1),
			"available": not on_cooldown and GameState.actions_remaining >= policy.get("cost_actions", 1),
			"cooldown_remaining": _policy_cooldowns.get(policy_id, 0)
		})
	return result

## 获取各势力趋势（用于情报阶段）
func get_faction_trends() -> Dictionary:
	var trends := {}
	for faction_id in GameState.faction_support:
		var support: float = GameState.faction_support[faction_id]
		var trend: String = "stable"
		if support < 20.0:
			trend = "critical"
		elif support < 35.0:
			trend = "declining"
		elif support > 75.0:
			trend = "strong"
		trends[faction_id] = {"support": support, "trend": trend}
	return trends
