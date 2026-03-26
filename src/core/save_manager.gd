## SaveManager — 存档管理器
## 封装 CentJoursEngine.to_json() / load_from_json() 与 FileAccess 的交互
## 用法：SaveManager.save_game(engine) / SaveManager.load_game(engine)

class_name SaveManager
extends RefCounted

const LEGACY_SAVE_PATH := "user://cent_jours_save.json"
const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3
const SAVE_VERSION := 3

## 存档：序列化引擎状态并写入磁盘
## 返回 true 表示写入成功
static func save_game(engine: CentJoursEngine, slot_id: int = 1) -> bool:
	if not _is_valid_slot(slot_id):
		push_error("[SaveManager] 非法存档槽位: %d" % slot_id)
		return false
	var json_str: String = engine.to_json()
	if json_str.is_empty():
		push_error("[SaveManager] engine.to_json() 返回空字符串")
		return false

	_ensure_save_dir()
	var save_path := _slot_path(slot_id)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] 无法打开存档路径: %s (错误码 %d)" % [save_path, FileAccess.get_open_error()])
		return false

	file.store_string(json_str)
	return true

## 读档：从磁盘加载 JSON 并恢复引擎状态
## 返回 true 表示读取并反序列化成功
static func load_game(engine: CentJoursEngine, slot_id: int = 1) -> bool:
	if not _is_valid_slot(slot_id):
		return false
	var save_path := _resolved_load_path(slot_id)
	if save_path == "":
		return false

	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("[SaveManager] 无法读取存档: %s" % save_path)
		return false

	var json_str: String = file.get_as_text()
	if json_str.is_empty():
		push_error("[SaveManager] 存档文件为空")
		return false

	var ok: bool = engine.load_from_json(json_str)
	if not ok:
		push_error("[SaveManager] JSON 反序列化失败，存档可能已损坏")
	return ok

## 检查是否存在存档文件
static func has_save(slot_id: int = 1) -> bool:
	if not _is_valid_slot(slot_id):
		return false
	return _resolved_load_path(slot_id) != ""

static func has_any_save() -> bool:
	for slot_id in range(1, SLOT_COUNT + 1):
		if has_save(slot_id):
			return true
	return false

## 删除存档文件
static func delete_save(slot_id: int = 1) -> void:
	if not _is_valid_slot(slot_id):
		return
	var save_path := _resolved_load_path(slot_id)
	if save_path == "":
		return
	DirAccess.remove_absolute(save_path)

## 获取存档元信息（不加载完整引擎状态）
## 返回 { "day": int, "outcome": String } 或空字典（读取失败）
static func get_save_meta(slot_id: int = 1) -> Dictionary:
	if not _is_valid_slot(slot_id):
		return {}
	var save_path := _resolved_load_path(slot_id)
	if save_path == "":
		return {}

	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {}

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}

	var data: Dictionary = json.data
	return {
		"slot_id": slot_id,
		"day":     data.get("day", 0),
		"outcome": _normalize_outcome(data.get("outcome", "in_progress"))
	}

static func list_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot_id in range(1, SLOT_COUNT + 1):
		var meta := get_save_meta(slot_id)
		var exists := not meta.is_empty()
		var outcome := _normalize_outcome(meta.get("outcome", "in_progress"))
		slots.append({
			"slot_id": slot_id,
			"exists": exists,
			"day": int(meta.get("day", 0)),
			"outcome": outcome,
			"outcome_label": _outcome_label(outcome),
			"label": _slot_label(slot_id, meta)
		})
	return slots

static func _slot_path(slot_id: int) -> String:
	return "%s/cent_jours_slot_%d.json" % [SAVE_DIR, slot_id]

static func _resolved_load_path(slot_id: int) -> String:
	var slot_path := _slot_path(slot_id)
	if FileAccess.file_exists(slot_path):
		return slot_path
	if slot_id == 1 and FileAccess.file_exists(LEGACY_SAVE_PATH):
		return LEGACY_SAVE_PATH
	return ""

static func _ensure_save_dir() -> void:
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		return
	if not user_dir.dir_exists("saves"):
		user_dir.make_dir("saves")

static func _is_valid_slot(slot_id: int) -> bool:
	return slot_id >= 1 and slot_id <= SLOT_COUNT

static func _slot_label(slot_id: int, meta: Dictionary) -> String:
	if meta.is_empty():
		return "槽位 %d · 空" % slot_id
	return "槽位 %d · Day %d · %s" % [
		slot_id,
		int(meta.get("day", 0)),
		_outcome_label(_normalize_outcome(meta.get("outcome", "in_progress")))
	]

static func _outcome_label(outcome: String) -> String:
	match outcome:
		"in_progress":
			return "进行中"
		"napoleon_victory":
			return "拿破仑胜利"
		"waterloo_historical":
			return "滑铁卢失败"
		"political_collapse":
			return "政治崩溃"
		"military_annihilation":
			return "军事崩溃"
		_:
			return outcome.replace("_", " ")

static func _normalize_outcome(value: Variant) -> String:
	if value == null:
		return "in_progress"
	var outcome := str(value).strip_edges()
	if outcome == "" or outcome == "<null>":
		return "in_progress"
	return outcome
