## SettingsManager — 最小玩家设置持久化
## 这一层只负责默认值、归一化、读写和应用，不负责弹窗 UI。

extends RefCounted
class_name SettingsManager

const SETTINGS_PATH := "user://cent_jours_settings.cfg"
const SECTION_DISPLAY := "display"
const KEY_WINDOW_MODE := "window_mode"
const KEY_UI_SCALE := "ui_scale"

const DEFAULT_WINDOW_MODE := "windowed"
const DEFAULT_UI_SCALE := 1.0

const WINDOW_MODE_OPTIONS := [
	{"id": "windowed", "label": "窗口"},
	{"id": "maximized", "label": "最大化"},
	{"id": "fullscreen", "label": "全屏"},
]

const UI_SCALE_OPTIONS := [
	{"value": 0.9, "label": "90%"},
	{"value": 1.0, "label": "100%"},
	{"value": 1.1, "label": "110%"},
	{"value": 1.25, "label": "125%"},
]

const WINDOW_MODE_VALUES := {
	"windowed": Window.MODE_WINDOWED,
	"maximized": Window.MODE_MAXIMIZED,
	"fullscreen": Window.MODE_FULLSCREEN,
}


static func default_settings() -> Dictionary:
	return {
		KEY_WINDOW_MODE: DEFAULT_WINDOW_MODE,
		KEY_UI_SCALE: DEFAULT_UI_SCALE,
	}


static func normalize_settings(raw: Dictionary) -> Dictionary:
	var normalized := default_settings()
	var window_mode := String(raw.get(KEY_WINDOW_MODE, DEFAULT_WINDOW_MODE))
	if not WINDOW_MODE_VALUES.has(window_mode):
		window_mode = DEFAULT_WINDOW_MODE
	normalized[KEY_WINDOW_MODE] = window_mode
	normalized[KEY_UI_SCALE] = _normalize_ui_scale(raw.get(KEY_UI_SCALE, DEFAULT_UI_SCALE))
	return normalized


static func load_settings() -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		return default_settings()
	return normalize_settings({
		KEY_WINDOW_MODE: config.get_value(SECTION_DISPLAY, KEY_WINDOW_MODE, DEFAULT_WINDOW_MODE),
		KEY_UI_SCALE: config.get_value(SECTION_DISPLAY, KEY_UI_SCALE, DEFAULT_UI_SCALE),
	})


static func save_settings(settings: Dictionary) -> bool:
	var normalized := normalize_settings(settings)
	var config := ConfigFile.new()
	config.set_value(SECTION_DISPLAY, KEY_WINDOW_MODE, normalized[KEY_WINDOW_MODE])
	config.set_value(SECTION_DISPLAY, KEY_UI_SCALE, normalized[KEY_UI_SCALE])
	return config.save(SETTINGS_PATH) == OK


static func apply_settings(settings: Dictionary, target_window: Window = null) -> void:
	var normalized := normalize_settings(settings)
	var window := _resolve_window(target_window)
	if window == null:
		return
	window.content_scale_factor = float(normalized[KEY_UI_SCALE])
	var window_mode: Window.Mode = WINDOW_MODE_VALUES.get(
		String(normalized[KEY_WINDOW_MODE]),
		Window.MODE_WINDOWED
	) as Window.Mode
	window.mode = window_mode


static func clear_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


static func find_window_mode_index(window_mode: String) -> int:
	for index in range(WINDOW_MODE_OPTIONS.size()):
		if String(WINDOW_MODE_OPTIONS[index].get("id", "")) == window_mode:
			return index
	return 0


static func find_ui_scale_index(ui_scale: float) -> int:
	for index in range(UI_SCALE_OPTIONS.size()):
		if is_equal_approx(float(UI_SCALE_OPTIONS[index].get("value", DEFAULT_UI_SCALE)), ui_scale):
			return index
	return 1


static func _normalize_ui_scale(candidate: Variant) -> float:
	var scale := float(candidate)
	var best_value := DEFAULT_UI_SCALE
	var best_delta := INF
	for option in UI_SCALE_OPTIONS:
		var option_value := float(option.get("value", DEFAULT_UI_SCALE))
		var delta := absf(option_value - scale)
		if delta < best_delta:
			best_delta = delta
			best_value = option_value
	return best_value


static func _resolve_window(target_window: Window = null) -> Window:
	if target_window != null:
		return target_window
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root
	return null
