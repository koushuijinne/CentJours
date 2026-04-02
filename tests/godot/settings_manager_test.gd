extends GdUnitTestSuite

const __source = "res://src/core/settings_manager.gd"
const SettingsManagerScript = preload("res://src/core/settings_manager.gd")


func before_test() -> void:
	SettingsManagerScript.clear_settings()
	SettingsManagerScript.apply_settings(SettingsManagerScript.default_settings())


func after_test() -> void:
	SettingsManagerScript.clear_settings()
	SettingsManagerScript.apply_settings(SettingsManagerScript.default_settings())


func test_load_settings_returns_defaults_when_file_missing() -> void:
	var settings := SettingsManagerScript.load_settings()

	assert_str(String(settings.get("window_mode", ""))).is_equal("windowed")
	assert_bool(absf(float(settings.get("ui_scale", 0.0)) - 1.0) < 0.001).is_true()


func test_save_settings_round_trips_display_preferences() -> void:
	assert_bool(SettingsManagerScript.save_settings({
		"window_mode": "fullscreen",
		"ui_scale": 1.1,
	})).is_true()

	var settings := SettingsManagerScript.load_settings()
	assert_str(String(settings.get("window_mode", ""))).is_equal("fullscreen")
	assert_bool(absf(float(settings.get("ui_scale", 0.0)) - 1.1) < 0.001).is_true()


func test_normalize_settings_clamps_invalid_values() -> void:
	var settings := SettingsManagerScript.normalize_settings({
		"window_mode": "broken",
		"ui_scale": 2.8,
	})

	assert_str(String(settings.get("window_mode", ""))).is_equal("windowed")
	assert_bool(absf(float(settings.get("ui_scale", 0.0)) - 1.25) < 0.001).is_true()
