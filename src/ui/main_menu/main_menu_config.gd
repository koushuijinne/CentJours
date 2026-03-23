extends RefCounted
class_name MainMenuConfig

const PRIORITY_POLICY_IDS := [
	"conscription",
	"public_speech",
	"constitutional_promise",
	"increase_military_budget",
	"grant_titles",
	"reduce_taxes",
	"secret_diplomacy",
	"print_money"
]

const POLICY_EMOJIS := {
	"conscription": "🪖",
	"public_speech": "📣",
	"constitutional_promise": "📜",
	"increase_military_budget": "💰",
	"grant_titles": "👑",
	"reduce_taxes": "🪙",
	"secret_diplomacy": "🕵️",
	"print_money": "🏦"
}

const POLICY_EFFECTS := {
	"conscription": [
		{"label": "Troops", "value": 8, "type": "positive"},
		{"label": "Populace", "value": -3, "type": "negative"},
		{"label": "Rouge", "value": 5, "type": "rn"}
	],
	"public_speech": [
		{"label": "Populace", "value": 5, "type": "positive"},
		{"label": "Nobility", "value": -2, "type": "negative"},
		{"label": "Rouge", "value": 3, "type": "rn"}
	],
	"constitutional_promise": [
		{"label": "Liberals", "value": 7, "type": "positive"},
		{"label": "Nobility", "value": -3, "type": "negative"},
		{"label": "Noir", "value": -8, "type": "rn"}
	],
	"increase_military_budget": [
		{"label": "Military", "value": 6, "type": "positive"},
		{"label": "Economy", "value": -4, "type": "negative"},
		{"label": "Rouge", "value": 4, "type": "rn"}
	],
	"grant_titles": [
		{"label": "Nobility", "value": 12, "type": "positive"},
		{"label": "Liberals", "value": -5, "type": "negative"},
		{"label": "Populace", "value": -3, "type": "negative"},
		{"label": "Noir", "value": -5, "type": "rn"}
	],
	"reduce_taxes": [
		{"label": "Populace", "value": 10, "type": "positive"},
		{"label": "Liberals", "value": 3, "type": "positive"},
		{"label": "Economy", "value": -8, "type": "negative"}
	],
	"secret_diplomacy": [
		{"label": "Cost", "value": 2, "type": "negative"},
		{"label": "Noir", "value": -3, "type": "rn"}
	],
	"print_money": [
		{"label": "Economy", "value": 15, "type": "positive"},
		{"label": "Populace", "value": -5, "type": "negative"},
		{"label": "Liberals", "value": -8, "type": "negative"},
		{"label": "Nobility", "value": -5, "type": "negative"},
		{"label": "Rouge", "value": 8, "type": "rn"}
	]
}

const BATTLE_CARD_META := {
	"policy_id": "battle",
	"name": "发动战役",
	"emoji": "⚔️",
	"effects": [
		{"label": "Risk", "value": 0, "type": "negative"}
	]
}

const MARCH_CARD_META := {
	"policy_id": "march",
	"name": "行军",
	"emoji": "🧭",
	"effects": [
		{"label": "Move", "value": 1, "type": "positive"},
		{"label": "Fatigue", "value": -10, "type": "positive"}
	]
}

const BOOST_CARD_META := {
	"policy_id": "boost_loyalty",
	"name": "亲自接见将领",
	"emoji": "🤝",
	"effects": [
		{"label": "Legitimacy", "value": -5, "type": "negative"},
		{"label": "Loyalty", "value": 8, "type": "positive"}
	]
}

const OUTCOME_TEXT := {
	"napoleon_victory": {
		"title": "拿破仑的凯旋",
		"desc": "合法性与军事胜利兼得，帝国重建。历史被改写。"
	},
	"waterloo_historical": {
		"title": "滑铁卢 — 历史重演",
		"desc": "合法性尚存但胜场不足，百日王朝以滑铁卢告终。"
	},
	"waterloo_defeat": {
		"title": "彻底败亡",
		"desc": "合法性崩塌，军事失利。拿破仑被流放至圣赫勒拿岛。"
	},
	"political_collapse": {
		"title": "政治崩溃",
		"desc": "派系全面倒戈，帝国从内部瓦解。拿破仑被迫再次退位。"
	},
	"military_annihilation": {
		"title": "军事覆灭",
		"desc": "兵力耗尽，法军不复存在。反法联军长驱直入巴黎。"
	}
}

const TERRAIN_OPTIONS := {
	"plains": "平原",
	"hills": "丘陵",
	"mountains": "山地",
	"forest": "森林",
	"urban": "城镇",
	"coastal": "海岸",
	"river_crossing": "河口",
	"fortress": "要塞",
	"ridgeline": "山脊"
}

const MAP_LABEL_ANCHORS := ["right_up", "right_down", "left_up", "left_down"]
const MAP_LABEL_GAP := 6.0
const MAP_HOTSPOT_MIN_SIZE := 24.0
const MAP_LABEL_PADDING_X := 8.0
const MAP_LABEL_PADDING_Y := 4.0
const MAP_RESERVED_TOP_LEFT := Vector2(360.0, 42.0)

const NODE_LABEL_POLICY := {
	"capital": {
		"dot": 16,
		"font": 13,
		"always_show": false,
		"default_visible": true,
		"hover_only": false,
		"label_priority": 100
	},
	"major_city": {
		"dot": 12,
		"font": 11,
		"always_show": false,
		"default_visible": true,
		"hover_only": false,
		"label_priority": 90
	},
	"fortress_city": {
		"dot": 10,
		"font": 10,
		"always_show": false,
		"default_visible": true,
		"hover_only": false,
		"label_priority": 82
	},
	"regional_capital": {
		"dot": 8,
		"font": 9,
		"always_show": false,
		"default_visible": true,
		"hover_only": false,
		"label_priority": 72
	},
	"royal_palace": {
		"dot": 8,
		"font": 10,
		"always_show": false,
		"default_visible": true,
		"hover_only": false,
		"label_priority": 78
	},
	"coastal_landing": {
		"dot": 6,
		"font": 9,
		"always_show": false,
		"default_visible": true,
		"hover_only": false,
		"label_priority": 70
	},
	"fortress_town": {
		"dot": 7,
		"font": 9,
		"always_show": false,
		"default_visible": false,
		"hover_only": true,
		"label_priority": 58
	},
	"fortress": {
		"dot": 7,
		"font": 9,
		"always_show": false,
		"default_visible": false,
		"hover_only": true,
		"label_priority": 56
	},
	"small_town": {
		"dot": 5,
		"font": 8,
		"always_show": false,
		"default_visible": false,
		"hover_only": true,
		"label_priority": 36
	},
	"village": {
		"dot": 5,
		"font": 9,
		"always_show": false,
		"default_visible": false,
		"hover_only": true,
		"label_priority": 40
	},
	"crossroads": {
		"dot": 4,
		"font": 8,
		"always_show": false,
		"default_visible": false,
		"hover_only": true,
		"label_priority": 34
	},
	"palace_town": {
		"dot": 6,
		"font": 9,
		"always_show": false,
		"default_visible": false,
		"hover_only": true,
		"label_priority": 46
	}
}

const FACTION_LABELS := {
	"military": "军方",
	"populace": "民众",
	"liberals": "自由派",
	"nobility": "旧贵族"
}

const REST_CARD_META := {
	"policy_id": "rest",
	"name": "休整",
	"emoji": "🌙",
	"effects": [
		{"label": "Fatigue", "value": -10, "type": "positive"},
		{"label": "Morale", "value": 3, "type": "positive"}
	]
}

const NARRATIVE_MAX_ENTRIES: int = 5
