## ContentBuilder — 纯文本内容构建器
## 负责构建百科、策略目标、叙事日志、教程提示等文本内容
## 不持有 UI 节点引用，所有函数依赖 GameState 和 Config
extends RefCounted

const MainMenuConfigData = preload("res://src/ui/main_menu/main_menu_config.gd")


static func build_map_context_subtitle(hint_text: String, strategy_context: Dictionary) -> String:
	var lines: Array[String] = []
	var route_source := ""
	for candidate_variant in [
		GameState.logistics_route_chain_short,
		GameState.logistics_objective_short,
		GameState.logistics_regional_task_short,
		GameState.logistics_regional_pressure_short
	]:
		var candidate := String(candidate_variant).strip_edges()
		if candidate != "":
			route_source = candidate
			break
	var tutorial_prefix := TranslationServer.translate("UI_POPUP_TUTORIAL_FIRST10")
	if hint_text.begins_with(tutorial_prefix):
		lines.append(hint_text)
	elif route_source != "":
		lines.append(TranslationServer.translate("UI_STRATEGY_ROUTE_PREFIX").replace("{0}", route_source))
	elif hint_text.strip_edges() != "":
		lines.append(hint_text)

	var focus_title := String(strategy_context.get("focus_title", "")).strip_edges()
	var next_step := String(strategy_context.get("focus_next_step", "")).strip_edges()
	if focus_title != "":
		var strategy_line := TranslationServer.translate("UI_STRATEGY_LINE_PREFIX").replace("{0}", focus_title)
		if next_step != "":
			strategy_line += "。%s" % next_step
		lines.append(strategy_line)

	if hint_text.begins_with(tutorial_prefix):
		lines.append(TranslationServer.translate("UI_MAP_OPERATION_HINT"))
	return "\n".join(lines)


static func build_tutorial_hint_text(tutorial_stages: Array) -> String:
	if GameState.current_day > 10:
		return ""
	if GameState.logistics_runway_days == 0:
		return "前10天教程：你已经跌进战斗惩罚区。下一步优先休整或补给，不要继续硬顶。"
	if GameState.logistics_runway_days == 1 or GameState.supply < 55.0:
		return "前10天教程：补给开始见底时，先打补给牌或休整，不要连续站在低容量节点。"
	var stage := get_tutorial_stage_for_day(GameState.current_day, tutorial_stages)
	if stage.is_empty():
		return ""
	var topic: String = stage.get("topic", "")
	match topic:
		"supply":
			if GameState.supply < 55.0:
				return "前10天教程：补给偏低，试试使用补给类政策牌。"
			return "前10天教程：留意顶栏补给数值，它是你的生命线。"
		"politics":
			if GameState.legitimacy < 40.0:
				return "前10天教程：合法性偏低，考虑做政治决策巩固支持。"
			return "前10天教程：四个派系的支持决定你的合法性。"
		"command_deviation":
			return "前10天教程：保持补给和士气，减少命令偏差。"
		"diplomacy":
			return "前10天教程：外交进度由合法性和控制区域推动。"
		_:
			if GameState.logistics_regional_pressure_short.strip_edges() != "":
				return "前10天教程：%s" % GameState.logistics_regional_pressure_short
			return "前10天教程：查看侧栏了解当前建议。"


static func get_tutorial_stage_for_day(day: int, tutorial_stages: Array) -> Dictionary:
	for stage in tutorial_stages:
		var day_range: Array = stage.get("day_range", [0, 0])
		if day >= int(day_range[0]) and day <= int(day_range[1]):
			return stage
	return {}


static func build_strategy_context() -> Dictionary:
	var focus := build_primary_route_snapshot()
	var risk := build_primary_risk_snapshot()
	var faction_pressure := build_faction_pressure_snapshot()
	return {
		"focus_title": String(focus.get("title", "")).strip_edges(),
		"focus_reason": String(focus.get("reason", "")).strip_edges(),
		"focus_next_step": String(focus.get("next_step", "")).strip_edges(),
		"risk_title": String(risk.get("title", "")).strip_edges(),
		"risk_detail": String(risk.get("detail", "")).strip_edges(),
		"faction_title": String(faction_pressure.get("title", "")).strip_edges(),
		"faction_detail": String(faction_pressure.get("detail", "")).strip_edges()
	}


static func build_primary_route_snapshot() -> Dictionary:
	var outcome_id := "napoleon_victory"
	var reason := "当前局面还在塑形期，最值钱的路线仍然是同时把政治、补给和胜场养成能改写历史的组合。"
	if GameState.legitimacy < 15.0:
		outcome_id = "political_collapse"
		reason = "合法性已经压到即时失败区，巴黎可能会先于前线停止承担这场战争。"
	elif GameState.total_troops < 12000 or (GameState.supply < 30.0 and GameState.victories <= 1):
		outcome_id = "military_annihilation"
		reason = "兵力和续航都在危险区，继续用高损耗换位置会更接近军事覆灭。"
	elif GameState.current_day >= 60 and GameState.legitimacy >= 65.0 and GameState.diplomatic_progress >= 70:
		outcome_id = "diplomatic_settlement"
		reason = "你已经跨进外交兑现窗口，当前最接近的是把高合法性和外交进度守到停火落地。"
	elif GameState.victories >= 3 and GameState.legitimacy >= 50.0:
		outcome_id = "napoleon_victory"
		reason = "战场和政治都还站得住，现在最接近的是把中盘优势滚成改写历史的胜局。"
	elif GameState.victories >= 3:
		outcome_id = "military_dominance"
		reason = "你的战果已经跑在政治线前面，当前更像一条靠军功硬压出来的军事霸权路线。"
	elif GameState.current_day >= 45 and GameState.diplomatic_progress >= 45 and GameState.legitimacy >= 55.0:
		outcome_id = "diplomatic_settlement"
		reason = "中盘政治基础还稳，外交进度也已经成形，继续经营外交比硬赌决战更近。"
	elif GameState.victories >= 2 and GameState.legitimacy >= 45.0:
		outcome_id = "napoleon_victory"
		reason = "你已经有了翻盘骨架，只差把优势滚成足够多的有效胜利。"
	elif GameState.current_day >= 80:
		outcome_id = "waterloo_historical"
		reason = "终盘已经逼近，若再不把胜场或外交进度推上去，局面会更像守到滑铁卢。"
	elif GameState.victories <= 0 and GameState.legitimacy < 40.0:
		outcome_id = "waterloo_defeat"
		reason = "战场和政治都没有起色，继续硬顶更像是在滑向彻底败亡。"

	var info: Dictionary = MainMenuConfigData.OUTCOME_TEXT.get(outcome_id, {})
	return {
		"id": outcome_id,
		"title": String(info.get("title", outcome_id)),
		"reason": reason,
		"next_step": String(info.get("next_step", "")).strip_edges()
	}


static func build_primary_risk_snapshot() -> Dictionary:
	if GameState.legitimacy < 15.0:
		return {
			"title": "政治崩溃",
			"detail": "合法性 %.1f，任何继续消耗派系或合法性的动作都可能让巴黎先倒向退位。" % GameState.legitimacy
		}
	if GameState.total_troops < 12000:
		return {
			"title": "军事覆灭",
			"detail": "兵力只剩 %s，再用高损耗战斗硬换位置，军队会先于政权崩掉。" % _format_number(GameState.total_troops)
		}
	if GameState.supply < 45.0:
		return {
			"title": "补给透支",
			"detail": "当前补给 %.0f，前线已经接近或跌入惩罚区。先保线再推进，否则任何路线都会一起变窄。" % GameState.supply
		}
	if GameState.current_day >= 75 and GameState.victories < 2:
		return {
			"title": "终盘战果不足",
			"detail": "已到第 %d 天，胜场只有 %d。若这一段还没有决定性战果，终盘会更像守到历史败局。" % [GameState.current_day, GameState.victories]
		}
	var faction_pressure := build_faction_pressure_snapshot()
	return {
		"title": String(faction_pressure.get("title", "派系失衡")),
		"detail": String(faction_pressure.get("detail", "当前最大的风险来自内部支持失衡。"))
	}


static func build_faction_pressure_snapshot() -> Dictionary:
	var weakest_id := ""
	var weakest_support := 101.0
	var strongest_id := ""
	var strongest_support := -1.0
	for faction_id in GameState.faction_support.keys():
		var support := float(GameState.faction_support.get(faction_id, 0.0))
		if support < weakest_support:
			weakest_support = support
			weakest_id = String(faction_id)
		if support > strongest_support:
			strongest_support = support
			strongest_id = String(faction_id)

	var weakest_label: String = String(MainMenuConfigData.FACTION_LABELS.get(weakest_id, weakest_id))
	var strongest_label: String = String(MainMenuConfigData.FACTION_LABELS.get(strongest_id, strongest_id))
	var pressure_reason := ""
	match weakest_id:
		"military":
			pressure_reason = "军方正在变脆，继续战败或压缩军费会直接反噬前线调度。"
		"populace":
			pressure_reason = "民众正在变脆，征用、印钞和长期战损都会让巴黎压力继续累积。"
		"liberals":
			pressure_reason = "自由派正在变脆，若还想保住议会和行政面的支持，就别长期只靠强压。"
		"nobility":
			pressure_reason = "贵族和保守秩序正在变脆，继续冲红线会让政治基础变得更窄。"
		_:
			pressure_reason = "当前内部支持并不均衡，别把最脆的一派继续往危险线推。"

	return {
		"title": "派系压力 · %s最脆" % weakest_label,
		"detail": "当前最脆的是%s %.0f，最稳的是%s %.0f。%s" % [
			weakest_label,
			weakest_support,
			strongest_label,
			strongest_support,
			pressure_reason
		]
	}


static func build_strategy_goals_overview() -> String:
	var lines: Array[String] = []
	lines.append(TranslationServer.translate("UI_STRATEGY_OVERVIEW_HEADER"))
	lines.append(TranslationServer.translate("UI_STRATEGY_SITUATION_FORMAT") \
		.replace("{0}", str(GameState.current_day)) \
		.replace("{1}", str(snapped(GameState.legitimacy, 0.1))) \
		.replace("{2}", str(GameState.victories)) \
		.replace("{3}", str(GameState.diplomatic_progress)) \
		.replace("{4}", str(int(GameState.supply))))
	lines.append("")
	lines.append(TranslationServer.translate("UI_STRATEGY_NEAREST_ROUTE"))
	for summary in build_strategy_priority_lines():
		lines.append("• %s" % summary)
	lines.append("")
	lines.append(TranslationServer.translate("UI_STRATEGY_OUTCOME_ROUTES"))
	for outcome_id in [
		"napoleon_victory",
		"diplomatic_settlement",
		"military_dominance",
		"waterloo_historical",
		"waterloo_defeat",
		"political_collapse",
		"military_annihilation"
	]:
		var info: Dictionary = MainMenuConfigData.OUTCOME_TEXT.get(outcome_id, {})
		if info.is_empty():
			continue
		lines.append("【%s】" % String(info.get("title", outcome_id)))
		lines.append(String(info.get("desc", "暂无说明。")))
		var status_lines := build_strategy_status_lines(outcome_id)
		if not status_lines.is_empty():
			lines.append(TranslationServer.translate("UI_STRATEGY_CURRENT_STATUS"))
			for status_line in status_lines:
				lines.append("- %s" % status_line)
		var goal_line := String(info.get("goal_line", "")).strip_edges()
		if goal_line != "":
			lines.append(TranslationServer.translate("UI_STRATEGY_REQUIREMENTS"))
			lines.append(goal_line)
		var watch_for := String(info.get("watch_for", "")).strip_edges()
		if watch_for != "":
			lines.append(TranslationServer.translate("UI_STRATEGY_WATCH_FOR"))
			lines.append(watch_for)
		var next_step := String(info.get("next_step", "")).strip_edges()
		if next_step != "":
			lines.append(TranslationServer.translate("UI_STRATEGY_NEXT_STEP"))
			lines.append(next_step)
		lines.append("")
	lines.append(TranslationServer.translate("UI_STRATEGY_ADVICE_HEADER"))
	lines.append("优先同时考虑机动节奏、合法性、补给、外交进度和胜场，不要只盯一项数值。")
	return "\n".join(lines)


static func build_glossary_overview() -> String:
	var rn_tooltip := PoliticalSystem.get_rouge_noir_tooltip()
	var lines: Array[String] = []
	lines.append(TranslationServer.translate("UI_GLOSSARY_RN_HEADER"))
	lines.append("红越高，说明你更依赖动员、强硬和短期压力；黑越高，说明你更依赖秩序、妥协和保守支持。这个指数不会单独决定胜负，但会放大不同派系对政策的反应。")
	lines.append("当前倾向：%s。" % String(rn_tooltip.get("label", "政治中立")))
	var rn_effects: Array = rn_tooltip.get("effects", [])
	if not rn_effects.is_empty():
		var rn_effect_labels: Array[String] = []
		for effect_variant in rn_effects:
			rn_effect_labels.append(String(effect_variant))
		lines.append("当前主要影响：%s。" % "；".join(rn_effect_labels))
	else:
		lines.append("当前主要影响：你还在中间区，两侧加成和副作用都不明显。")
	lines.append("怎么理解：红不是绝对正确，黑也不是绝对安全。红线更容易换来短期兵力和动员，黑线更容易稳住秩序与保守支持，但两边走得太极端都会让另一头的派系代价越来越高。")
	lines.append("")
	lines.append(TranslationServer.translate("UI_GLOSSARY_LEGITIMACY_HEADER"))
	lines.append("合法性是四个派系支持度的加权结果，代表这个政权还能不能继续让法国承受战争。它会影响每日决策点、部分行动门槛、结局判断，以及你还能不能用政治方式稳住局面。")
	lines.append("合法性高于 70 时，每天会多 1 个决策点；低于 10 时，连「亲自接见将领」都会失效。")
	lines.append("")
	lines.append(TranslationServer.translate("UI_GLOSSARY_IMPROVE_LEGITIMACY"))
	lines.append("最直接的方法是打胜仗、稳住军方和民众支持，并避免把某一派系长期压到危险线。")
	lines.append("偏保守政策更容易稳住贵族和行政面，偏动员政策更容易拉升民众和军方，但两边走得太极端都会带来新的副作用。")
	lines.append("接见将领会立刻消耗 5 点合法性；战败、补给崩盘和连续把派系推向敌对区，都会让合法性更难回升。")
	lines.append("")
	lines.append(TranslationServer.translate("UI_GLOSSARY_DIPLOMACY_HEADER"))
	lines.append("外交进度代表你是否把联军逼到了谈判桌前。它不会自己增长，必须靠外交相关的政策、事件和中盘政治信誉慢慢积累。")
	lines.append("当前外交进度：%d / 100。外交线不是临门一脚，它要求你在第 60 天之后仍然保持足够高的合法性，同时把外交进度推满。" % GameState.diplomatic_progress)
	lines.append("")
	lines.append(TranslationServer.translate("UI_GLOSSARY_SUPPLY_HEADER"))
	lines.append("补给不是单纯库存，而是你维持帝国战争机器的「生命线」。它取决于你当前节点容量、补给线稳定性，以及区域走廊的链路质量。")
	lines.append("影响：补给充足时（>60），行军损耗更低，战斗有加成；补给匮乏时（<45），不仅战斗力受损，还会引发合法性持续流失，甚至导致军队逃兵。")
	lines.append("补救方法：在容量高的城市节点「休整」，或使用补给相关政策牌。不要在低容量的前沿节点长期逗留。")
	lines.append("")
	lines.append(TranslationServer.translate("UI_GLOSSARY_DAILY_RHYTHM"))
	lines.append("当前日内模型是：1 次机动槽（行军 / 战役 / 休整）+ 2 次决策点。机动区和决策区分开看，通常先决定位置，再决定当天政策。")
	lines.append("")
	lines.append(TranslationServer.translate("UI_GLOSSARY_COMMAND_DEVIATION"))
	lines.append("行军和战役的实际结果可能偏离你的预期。偏差来源有三个：")
	lines.append("• 疲劳：疲劳越高，部队越可能走不到目标或战斗力打折。")
	lines.append("• 补给：补给不足时，行军消耗加倍，战斗惩罚叠加。")
	lines.append("• 将领忠诚：忠诚度低于 30 的将领可能抗命甚至叛逃。")
	lines.append("管理偏差的核心是：不要同时让疲劳、补给和忠诚度都处于危险区。")
	lines.append("")
	lines.append(TranslationServer.translate("UI_GLOSSARY_OUTCOME_READING"))
	lines.append("结局是政治、军事与外交共同博弈的结果：")
	lines.append("• 军事覆灭：补给或兵力降至极值，军队将先于政权瓦解。补给长期低于 30 会加速这一结局。")
	lines.append("• 政治崩溃：合法性跌破临界点（10），巴黎将由于内部动荡强制你退位。连续忽视派系支持是最常见的原因。")
	lines.append("• 外交调停：第 60 天后，高合法性（≥65）搭配满额的外交进度（≥70），可达成体面的停火。")
	lines.append("• 拿破仑胜利：胜场足够多（≥3）且合法性稳定（≥50），历史将由你改写。")
	lines.append("• 军事霸权：战果跑在政治线前面（≥3 胜但合法性不足），靠军功硬压出来的局面。")
	lines.append("若合法性或兵力先崩，游戏会提前结束，不会等到百日终盘。")
	lines.append("")
	lines.append(TranslationServer.translate("UI_GLOSSARY_CURRENT_HINT"))
	lines.append("第 %d 天 · 合法性 %.1f · 补给 %.0f · 外交进度 %d/100 · 机动%s · 决策点 %d" % [
		GameState.current_day,
		GameState.legitimacy,
		GameState.supply,
		GameState.diplomatic_progress,
		"可用" if GameState.maneuver_available else "已用",
		GameState.actions_remaining
	])
	return "\n".join(lines)


static func build_strategy_priority_lines() -> Array[String]:
	var strategy_context := build_strategy_context()
	var lines: Array[String] = []
	if String(strategy_context.get("focus_title", "")).strip_edges() != "":
		lines.append("当前最接近%s：%s" % [
			strategy_context.get("focus_title", ""),
			strategy_context.get("focus_reason", "")
		])
	if String(strategy_context.get("risk_title", "")).strip_edges() != "":
		lines.append("当前主要风险是%s：%s" % [
			strategy_context.get("risk_title", ""),
			strategy_context.get("risk_detail", "")
		])
	if String(strategy_context.get("faction_title", "")).strip_edges() != "":
		lines.append("%s：%s" % [
			strategy_context.get("faction_title", ""),
			strategy_context.get("faction_detail", "")
		])
	if GameState.current_day <= 10:
		lines.append("前 10 天不要急着追单一路线，先把补给线和跳板节点稳住，避免教程期就把终盘余量交掉。")
	if lines.is_empty():
		lines.append("当前局面还在塑形期。先决定今天的位置和补给节奏，再决定要押政治、外交还是战场。")
	return lines


static func build_strategy_status_lines(outcome_id: String) -> Array[String]:
	var lines: Array[String] = []
	match outcome_id:
		"napoleon_victory":
			lines.append("政治线：当前合法性 %.1f。它需要你把巴黎的支持撑到终盘。" % GameState.legitimacy)
			lines.append("战场线：当前胜场 %d。你需要的不只是活到终盘，而是把关键战役转成有效胜利。" % GameState.victories)
		"diplomatic_settlement":
			lines.append("时间线：外交结局只会在第 60 天之后真正兑现，现在是第 %d 天。" % GameState.current_day)
			lines.append("外交线：当前进度 %d/100。若中盘不持续经营，这条线不会自己长出来。" % GameState.diplomatic_progress)
			lines.append("政治线：当前合法性 %.1f。外交解法要求你一直像个还能谈判的政权。" % GameState.legitimacy)
		"military_dominance":
			lines.append("战场线：当前胜场 %d。它接受政治基础一般，但要求你把战果滚成碾压态势。" % GameState.victories)
			lines.append("风险线：当前合法性 %.1f。若政治线再掉得太狠，军队再强也可能先被内部否决。" % GameState.legitimacy)
		"waterloo_historical":
			lines.append("这是拖到终盘但没改写历史的路线。当前胜场 %d、合法性 %.1f，都还不够让局面彻底翻盘。" % [GameState.victories, GameState.legitimacy])
		"waterloo_defeat":
			lines.append("这条线代表政治和军事都没守住。当前胜场 %d、合法性 %.1f，若继续一起下滑就会落到这里。" % [GameState.victories, GameState.legitimacy])
		"political_collapse":
			lines.append("即时失败风险：当前合法性 %.1f。它越低，巴黎越可能先于前线否决整场战争。" % GameState.legitimacy)
		"military_annihilation":
			lines.append("即时失败风险：当前兵力 %d、补给 %.0f。若连续高损耗并硬顶低补给，军队会先崩。" % [GameState.total_troops, GameState.supply])
	return lines


static func build_narrative_log_overview(current_log_body: String, strategy_context: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(TranslationServer.translate("UI_NARRATIVE_LOG_HEADER"))
	lines.append("这里会保留教程、历史事件、行动结算和日记摘录。你可以把它当成回看窗口：先看当前局势，再往下翻最近发生了什么。")
	lines.append("")
	lines.append(TranslationServer.translate("UI_NARRATIVE_LOG_SNAPSHOT"))
	lines.append(TranslationServer.translate("UI_STRATEGY_SITUATION_FORMAT") \
		.replace("{0}", str(GameState.current_day)) \
		.replace("{1}", str(snapped(GameState.legitimacy, 0.1))) \
		.replace("{2}", str(GameState.victories)) \
		.replace("{3}", str(GameState.diplomatic_progress)) \
		.replace("{4}", str(int(GameState.supply))))
	if String(strategy_context.get("focus_title", "")).strip_edges() != "":
		lines.append("当前最接近%s：%s" % [
			strategy_context.get("focus_title", ""),
			strategy_context.get("focus_reason", "")
		])
	if String(strategy_context.get("risk_title", "")).strip_edges() != "":
		lines.append("当前主要风险：%s" % strategy_context.get("risk_detail", ""))
	lines.append("")
	lines.append(TranslationServer.translate("UI_NARRATIVE_LOG_RECENT"))
	if current_log_body == "":
		lines.append(TranslationServer.translate("UI_NARRATIVE_LOG_EMPTY"))
	else:
		lines.append(current_log_body)
	return "\n".join(lines)


static func _format_number(value: int) -> String:
	var s := str(value)
	if value >= 10000:
		var head := s.substr(0, s.length() - 3)
		var tail := s.substr(s.length() - 3)
		return "%s,%s" % [head, tail]
	return s
