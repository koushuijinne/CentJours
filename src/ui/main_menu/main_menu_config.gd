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

const NARRATIVE_CATEGORY_LABELS := {
	"battle_victory": "战役胜利余波",
	"battle_defeat": "战役失利余波",
	"boost_loyalty": "将领接见余波",
	"conscription": "征兵令余波",
	"constitutional_promise": "宪政承诺余波",
	"public_speech": "公开演说余波",
	"grant_titles": "封爵令余波",
	"reduce_taxes": "减税令余波",
	"increase_military_budget": "军费拨款余波",
	"secret_diplomacy": "秘密外交余波",
	"diplomatic_secret": "秘密外交余波",
	"print_money": "印钞令余波"
}

const OUTCOME_TEXT := {
	"napoleon_victory": {
		"title": "拿破仑的凯旋",
		"desc": "合法性与军事胜利兼得，帝国重建。历史被改写。",
		"epilogue": "巴黎暂时接受了你的统治，欧洲也被迫重新计算法国的位置。",
		"epilogue_variants": [
			"巴黎暂时接受了你的统治，欧洲也被迫重新计算法国的位置。",
			"这一次，不是别人把你写进流放名单，而是整个欧洲被迫先来读你的条件。"
		],
		"review_hint": "你同时守住了政治合法性与战场主动权。这类胜局通常来自稳定中盘和至少三场有效胜利。",
		"review_hint_variants": [
			"你同时守住了政治合法性与战场主动权。这类胜局通常来自稳定中盘和至少三场有效胜利。",
			"你不是靠单次奇迹过线，而是在中盘把合法性、兵力恢复和战役节奏同时维持在可持续区间。"
		]
	},
	"waterloo_historical": {
		"title": "滑铁卢 — 历史重演",
		"desc": "合法性尚存但胜场不足，百日王朝以滑铁卢告终。",
		"epilogue": "你把帝国重新带回了巴黎，却没能把胜势带过比利时战场的最后几天。",
		"epilogue_variants": [
			"你把帝国重新带回了巴黎，却没能把胜势带过比利时战场的最后几天。",
			"巴黎仍在你手里，但比利时方向那几天的迟疑，已经足够让历史回到它原本的轨道。"
		],
		"review_hint": "这类结局通常说明政权还站得住，但军事窗口没被及时扩大成决定性优势。",
		"review_hint_variants": [
			"这类结局通常说明政权还站得住，但军事窗口没被及时扩大成决定性优势。",
			"你把局面拖到了终盘，却没有在关键几天里完成足够多的胜利转换。政权 survived，战役没有。"
		]
	},
	"waterloo_defeat": {
		"title": "彻底败亡",
		"desc": "合法性崩塌，军事失利。拿破仑被流放至圣赫勒拿岛。",
		"epilogue": "巴黎没能等来逆转的消息，帝国在战场和议场上同时失去了支点。",
		"epilogue_variants": [
			"巴黎没能等来逆转的消息，帝国在战场和议场上同时失去了支点。",
			"胜负没有倒在最后一小时里，而是倒在此前没能积累起来的余量上。等坏消息传回巴黎时，一切已经来不及了。"
		],
		"review_hint": "如果既没有足够胜场，也没能稳住合法性，百日通常会落向这个结局。",
		"review_hint_variants": [
			"如果既没有足够胜场，也没能稳住合法性，百日通常会落向这个结局。",
			"这类败局往往不是单点失误，而是政治、兵力和士气同时跌到无法互相补位的区间。"
		]
	},
	"political_collapse": {
		"title": "政治崩溃",
		"desc": "派系全面倒戈，帝国从内部瓦解。拿破仑被迫再次退位。",
		"epilogue": "前线还没来得及给出最终判决，巴黎就先决定不再继续承担这场战争。",
		"epilogue_variants": [
			"前线还没来得及给出最终判决，巴黎就先决定不再继续承担这场战争。",
			"议场、街头和内阁不再朝同一个方向用力，帝国因此先在巴黎失去了重心。"
		],
		"review_hint": "这说明政治动员先于军事失败崩掉了。中盘政策和派系平衡比单次战果更关键。",
		"review_hint_variants": [
			"这说明政治动员先于军事失败崩掉了。中盘政策和派系平衡比单次战果更关键。",
			"你没有输在战场最后一击，而是输在长期没人再愿意替帝国承担代价。"
		]
	},
	"military_annihilation": {
		"title": "军事覆灭",
		"desc": "兵力耗尽，法军不复存在。反法联军长驱直入巴黎。",
		"epilogue": "军队先于政权崩解，巴黎之后只剩下接受结果和清点残局。",
		"epilogue_variants": [
			"军队先于政权崩解，巴黎之后只剩下接受结果和清点残局。",
			"部队番号还在，能继续作战的人已经不够了。巴黎之后只剩下撤退、失序和追认失败。"
		],
		"review_hint": "这类败局通常由高损耗战斗、疲劳累积和兵力恢复不足叠加造成。",
		"review_hint_variants": [
			"这类败局通常由高损耗战斗、疲劳累积和兵力恢复不足叠加造成。",
			"如果连续几回合都在用高代价换短期位置，终局就很容易先从兵力和士气上塌掉。"
		]
	}
}

static func narrative_category_label(category: String) -> String:
	return String(NARRATIVE_CATEGORY_LABELS.get(category, category))

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

## 规范化地形 ID：将 map_nodes.json 中的地形别名映射到 Rust 引擎认可的战斗地形类型
## 已知别名: river_junction → river_crossing
## 已知合法值: plains, hills, mountains, forest, urban, coastal, fortress, ridgeline, river_crossing
static func normalize_battle_terrain(terrain_id: String) -> String:
	match terrain_id:
		"river_junction":
			return "river_crossing"
		"plains", "hills", "mountains", "forest", "urban", "coastal", "fortress", "ridgeline":
			return terrain_id
		_:
			return "plains"
