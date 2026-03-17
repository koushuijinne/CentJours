## BattleResolver — 战斗自动解算模块
## 实现计划书附录A.1的加权战斗模型

class_name BattleResolver
extends RefCounted

# ── 结果常量 ──────────────────────────────────────────
enum BattleResult {
	DECISIVE_VICTORY,   # 压倒性胜利，敌军溃败
	MARGINAL_VICTORY,   # 惨胜，双方均有损失
	STALEMATE,          # 僵持，各自保持阵线
	MARGINAL_DEFEAT,    # 小败，有序撤退
	DECISIVE_DEFEAT     # 惨败，军队崩溃
}

const RESULT_NAMES: Dictionary = {
	BattleResult.DECISIVE_VICTORY: "decisive_victory",
	BattleResult.MARGINAL_VICTORY: "marginal_victory",
	BattleResult.STALEMATE:        "stalemate",
	BattleResult.MARGINAL_DEFEAT:  "marginal_defeat",
	BattleResult.DECISIVE_DEFEAT:  "decisive_defeat"
}

# 战损比率（占参战兵力百分比）
const CASUALTIES_TABLE: Dictionary = {
	BattleResult.DECISIVE_VICTORY:  {"attacker": 0.05, "defender": 0.35},
	BattleResult.MARGINAL_VICTORY:  {"attacker": 0.15, "defender": 0.20},
	BattleResult.STALEMATE:         {"attacker": 0.12, "defender": 0.12},
	BattleResult.MARGINAL_DEFEAT:   {"attacker": 0.20, "defender": 0.15},
	BattleResult.DECISIVE_DEFEAT:   {"attacker": 0.35, "defender": 0.05}
}

# ── 地形加成系数 ──────────────────────────────────────
const TERRAIN_MODIFIERS: Dictionary = {
	"plains":        1.0,
	"hills":         1.15,
	"mountains":     1.30,
	"forest":        1.20,
	"urban":         1.25,
	"ridgeline":     1.35,   # 高地防守优势（如滑铁卢圣让山脊）
	"river_junction": 1.40,
	"coastal":       1.10,
	"dirt_road":     1.0,
	"fortress":      1.60
}

# ── 主解算函数 ────────────────────────────────────────

## 解算一场战斗
## attacker_data / defender_data: {troops, morale, fatigue, general_skill, supply_ok}
## terrain_type: 地形类型字符串
## 返回 BattleOutcome 字典
func resolve(attacker_data: Dictionary, defender_data: Dictionary, terrain_type: String) -> Dictionary:
	var atk_score := _calculate_force_score(attacker_data, false)
	var def_score := _calculate_force_score(defender_data, true, terrain_type)

	# 托尔斯泰式不确定性：±15%随机浮动
	var random_factor := randf_range(-0.15, 0.15)
	var ratio := (atk_score / maxf(def_score, 1.0)) * (1.0 + random_factor)

	var result := _ratio_to_result(ratio)
	var casualties := _calculate_casualties(result, attacker_data["troops"], defender_data["troops"])
	var morale_impact := _calculate_morale_impact(result)

	return {
		"result": result,
		"result_name": RESULT_NAMES[result],
		"ratio": ratio,
		"attacker_casualties": casualties["attacker"],
		"defender_casualties": casualties["defender"],
		"attacker_morale_delta": morale_impact["attacker"],
		"defender_morale_delta": morale_impact["defender"],
		"random_factor": random_factor
	}

# ── 内部计算 ──────────────────────────────────────────

## 计算一方的战斗得分
func _calculate_force_score(data: Dictionary, is_defender: bool, terrain_type: String = "plains") -> float:
	var troops: float = float(data.get("troops", 0))
	var morale: float = float(data.get("morale", 50)) / 100.0      # 归一化到 0-1
	var fatigue: float = float(data.get("fatigue", 0)) / 100.0     # 归一化到 0-1
	var general_skill: float = float(data.get("general_skill", 50)) / 100.0
	var supply_ok: bool = data.get("supply_ok", true)

	var score := troops * morale * (1.0 + general_skill * 0.5)

	# 疲劳惩罚：疲劳100%时战斗力降低50%
	score *= (1.0 - fatigue * 0.5)

	# 补给不足惩罚
	if not supply_ok:
		score *= 0.75

	# 地形加成（仅防守方受益）
	if is_defender:
		var terrain_bonus: float = TERRAIN_MODIFIERS.get(terrain_type, 1.0)
		score *= terrain_bonus

	return score

## 根据比率判断战斗结果
func _ratio_to_result(ratio: float) -> BattleResult:
	if ratio > 1.5:
		return BattleResult.DECISIVE_VICTORY
	elif ratio > 1.1:
		return BattleResult.MARGINAL_VICTORY
	elif ratio > 0.9:
		return BattleResult.STALEMATE
	elif ratio > 0.6:
		return BattleResult.MARGINAL_DEFEAT
	else:
		return BattleResult.DECISIVE_DEFEAT

## 计算具体伤亡人数
func _calculate_casualties(result: BattleResult, attacker_troops: int, defender_troops: int) -> Dictionary:
	var rates: Dictionary = CASUALTIES_TABLE[result]
	return {
		"attacker": int(attacker_troops * rates["attacker"]),
		"defender": int(defender_troops * rates["defender"])
	}

## 计算士气变化
func _calculate_morale_impact(result: BattleResult) -> Dictionary:
	match result:
		BattleResult.DECISIVE_VICTORY:
			return {"attacker": 15.0, "defender": -35.0}
		BattleResult.MARGINAL_VICTORY:
			return {"attacker": 5.0, "defender": -15.0}
		BattleResult.STALEMATE:
			return {"attacker": -5.0, "defender": -5.0}
		BattleResult.MARGINAL_DEFEAT:
			return {"attacker": -15.0, "defender": 5.0}
		BattleResult.DECISIVE_DEFEAT:
			return {"attacker": -35.0, "defender": 15.0}
		_:
			return {"attacker": 0.0, "defender": 0.0}
