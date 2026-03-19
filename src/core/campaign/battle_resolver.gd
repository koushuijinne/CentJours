## BattleResolver — 战斗结果展示元数据（v2）
## 战斗解算逻辑已由 BattleEngine（Rust GDExtension）负责
## 本文件只保留 UI Tooltip 所需的本地化字符串常量
##
## BattleEngine.resolve() 契约（来自 lib.rs BattleEngine::resolve）:
## 返回键: result(String) ratio(float) attacker_casualties(int) defender_casualties(int)
##         attacker_morale_delta(float) defender_morale_delta(float)
##         attacker_casualty_rate(float) defender_casualty_rate(float) random_factor(float)
##
## result 取值: "decisive_victory" | "marginal_victory" | "stalemate"
##              "marginal_defeat"  | "decisive_defeat"

class_name BattleResolver
extends RefCounted

# ── 战斗结果本地化显示名（UI Tooltip 用）────────────────────
const RESULT_DISPLAY_NAMES: Dictionary = {
	"decisive_victory": "压倒性胜利",
	"marginal_victory": "惨胜",
	"stalemate":        "僵持",
	"marginal_defeat":  "小败",
	"decisive_defeat":  "惨败"
}

# ── 地形本地化显示名（UI Tooltip 用）─────────────────────────
const TERRAIN_DISPLAY_NAMES: Dictionary = {
	"plains":         "平原",
	"hills":          "山地",
	"mountains":      "山岳",
	"forest":         "森林",
	"urban":          "城市",
	"ridgeline":      "高地",
	"river_crossing": "河道",
	"coastal":        "海岸",
	"dirt_road":      "土路",
	"fortress":       "要塞"
}
