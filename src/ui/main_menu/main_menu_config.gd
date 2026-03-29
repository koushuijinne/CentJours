extends RefCounted
class_name MainMenuConfig

const PRIORITY_POLICY_IDS := [
	"conscription",
	"public_speech",
	"constitutional_promise",
	"increase_military_budget",
	"requisition_supplies",
	"stabilize_supply_lines",
	"establish_forward_depot",
	"secure_regional_corridor",
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
	"requisition_supplies": "🚚",
	"stabilize_supply_lines": "🛤️",
	"establish_forward_depot": "📦",
	"secure_regional_corridor": "🧱",
	"grant_titles": "👑",
	"reduce_taxes": "🪙",
	"secret_diplomacy": "🕵️",
	"print_money": "🏦"
}

const POLICY_EFFECTS := {
	"conscription": [
		{"label": "兵力", "value": 8, "type": "positive"},
		{"label": "民众", "value": -3, "type": "negative"},
		{"label": "红派", "value": 5, "type": "rn"}
	],
	"public_speech": [
		{"label": "民众", "value": 5, "type": "positive"},
		{"label": "贵族", "value": -2, "type": "negative"},
		{"label": "红派", "value": 3, "type": "rn"}
	],
	"constitutional_promise": [
		{"label": "自由派", "value": 7, "type": "positive"},
		{"label": "贵族", "value": -3, "type": "negative"},
		{"label": "黑派", "value": -8, "type": "rn"}
	],
	"increase_military_budget": [
		{"label": "军方", "value": 6, "type": "positive"},
		{"label": "经济", "value": -4, "type": "negative"},
		{"label": "红派", "value": 4, "type": "rn"}
	],
	"requisition_supplies": [
		{"label": "补给", "value": 18, "type": "positive"},
		{"label": "军方", "value": 6, "type": "positive"},
		{"label": "民众", "value": -6, "type": "negative"},
		{"label": "红派", "value": 4, "type": "rn"}
	],
	"stabilize_supply_lines": [
		{"label": "补给", "value": 6, "type": "positive"},
		{"label": "线路", "value": 18, "type": "positive"},
		{"label": "军方", "value": 5, "type": "positive"},
		{"label": "民众", "value": -3, "type": "negative"},
		{"label": "黑派", "value": -2, "type": "rn"}
	],
	"establish_forward_depot": [
		{"label": "补给", "value": 4, "type": "positive"},
		{"label": "粮站", "value": 4, "type": "positive"},
		{"label": "军方", "value": 4, "type": "positive"},
		{"label": "民众", "value": -2, "type": "negative"},
		{"label": "黑派", "value": -1, "type": "rn"}
	],
	"secure_regional_corridor": [
		{"label": "补给", "value": 8, "type": "positive"},
		{"label": "线路", "value": 12, "type": "positive"},
		{"label": "粮站", "value": 3, "type": "positive"},
		{"label": "军方", "value": 5, "type": "positive"},
		{"label": "民众", "value": -4, "type": "negative"},
		{"label": "黑派", "value": -1, "type": "rn"}
	],
	"grant_titles": [
		{"label": "贵族", "value": 12, "type": "positive"},
		{"label": "自由派", "value": -5, "type": "negative"},
		{"label": "民众", "value": -3, "type": "negative"},
		{"label": "黑派", "value": -5, "type": "rn"}
	],
	"reduce_taxes": [
		{"label": "民众", "value": 10, "type": "positive"},
		{"label": "自由派", "value": 3, "type": "positive"},
		{"label": "经济", "value": -8, "type": "negative"}
	],
	"secret_diplomacy": [
		{"label": "代价", "value": 2, "type": "negative"},
		{"label": "黑派", "value": -3, "type": "rn"}
	],
	"print_money": [
		{"label": "经济", "value": 15, "type": "positive"},
		{"label": "民众", "value": -5, "type": "negative"},
		{"label": "自由派", "value": -8, "type": "negative"},
		{"label": "贵族", "value": -5, "type": "negative"},
		{"label": "红派", "value": 8, "type": "rn"}
	]
}

const BATTLE_CARD_META := {
	"policy_id": "battle",
	"name": "发动战役",
	"emoji": "⚔️",
	"effects": [
		{"label": "风险", "value": 0, "type": "negative"}
	]
}

const MARCH_CARD_META := {
	"policy_id": "march",
	"name": "行军",
	"emoji": "🧭",
	"effects": [
		{"label": "行军", "value": 1, "type": "positive"},
		{"label": "疲劳", "value": -10, "type": "positive"}
	]
}

const BOOST_CARD_META := {
	"policy_id": "boost_loyalty",
	"name": "亲自接见将领",
	"emoji": "🤝",
	"effects": [
		{"label": "合法性", "value": -5, "type": "negative"},
		{"label": "忠诚", "value": 8, "type": "positive"}
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
	"requisition_supplies": "征用仓储余波",
	"stabilize_supply_lines": "驿站整顿余波",
	"establish_forward_depot": "粮秣站余波",
	"secure_regional_corridor": "区域走廊余波",
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
	},
	"diplomatic_settlement": {
		"title": "外交斡旋",
		"desc": "通过外交途径迫使联军承认既成事实，欧洲接受了谈判桌上的拿破仑。",
		"epilogue": "不是每场战争都需要在战场上分出胜负。这一次，你让欧洲先坐到了谈判桌前。",
		"epilogue_variants": [
			"不是每场战争都需要在战场上分出胜负。这一次，你让欧洲先坐到了谈判桌前。",
			"维也纳的外交官们最终承认，武力解决法国问题的代价已经超出了他们愿意承受的范围。"
		],
		"review_hint": "外交结局需要同时维持高合法性和持续推进外交进程，通常在第60天之后才有可能达成。",
		"review_hint_variants": [
			"外交结局需要同时维持高合法性和持续推进外交进程，通常在第60天之后才有可能达成。",
			"你没有靠决战定天下，而是用政治筹码和外交信号让联军自己算出了停火比继续打更划算。"
		]
	},
	"military_dominance": {
		"title": "军事霸权",
		"desc": "以压倒性的军事胜利碾碎联军，但政治根基并不稳固。帝国靠剑而立。",
		"epilogue": "战场上没有人能挡住你，但巴黎的议场和街头对这种胜利的热情远不如军营。",
		"epilogue_variants": [
			"战场上没有人能挡住你，但巴黎的议场和街头对这种胜利的热情远不如军营。",
			"五场以上的胜利让联军不得不后撤，但帝国的未来取决于你能否把军事优势转化为持久的政治秩序。"
		],
		"review_hint": "军事霸权说明你在战场上表现出色，但忽视了政治合法性的积累。帝国能走多远取决于剑以外的东西。",
		"review_hint_variants": [
			"军事霸权说明你在战场上表现出色，但忽视了政治合法性的积累。帝国能走多远取决于剑以外的东西。",
			"你用连胜证明了军事能力，但合法性不够高意味着这个帝国更像是一个军事独裁而非稳定的政权重建。"
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

const DIFFICULTY_OPTIONS := {
	"elba": {
		"label": "厄尔巴 (简单)",
		"desc": "更多补给，更高初始合法性，敌军较弱。适合首次游玩。",
	},
	"borodino": {
		"label": "博罗季诺 (普通)",
		"desc": "历史标准参数。推荐难度。",
	},
	"austerlitz": {
		"label": "奥斯特里茨 (困难)",
		"desc": "更少补给，更低合法性，敌军更强。挑战你的极限。",
	}
}

const REST_CARD_META := {
	"policy_id": "rest",
	"name": "休整",
	"emoji": "🌙",
	"effects": [
		{"label": "疲劳", "value": -10, "type": "positive"},
		{"label": "士气", "value": 3, "type": "positive"}
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
