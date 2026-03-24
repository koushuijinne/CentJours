## SaveManager — 存档管理器
## 封装 CentJoursEngine.to_json() / load_from_json() 与 FileAccess 的交互
## 用法：SaveManager.save_game(engine) / SaveManager.load_game(engine)

class_name SaveManager
extends RefCounted

const SAVE_PATH    := "user://cent_jours_save.json"
const SAVE_VERSION := 2

## 存档：序列化引擎状态并写入磁盘
## 返回 true 表示写入成功
static func save_game(engine: CentJoursEngine) -> bool:
	var json_str: String = engine.to_json()
	if json_str.is_empty():
		push_error("[SaveManager] engine.to_json() 返回空字符串")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] 无法打开存档路径: %s (错误码 %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false

	file.store_string(json_str)
	return true

## 读档：从磁盘加载 JSON 并恢复引擎状态
## 返回 true 表示读取并反序列化成功
static func load_game(engine: CentJoursEngine) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[SaveManager] 无法读取存档: %s" % SAVE_PATH)
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
static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## 删除存档文件
static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

## 获取存档元信息（不加载完整引擎状态）
## 返回 { "day": int, "outcome": String } 或空字典（读取失败）
static func get_save_meta() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}

	var data: Dictionary = json.data
	return {
		"day":     data.get("day", 0),
		"outcome": data.get("outcome", "in_progress")
	}
