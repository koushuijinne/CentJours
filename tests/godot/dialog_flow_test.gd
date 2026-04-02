@warning_ignore_start("redundant_await")
extends GdUnitTestSuite

const __source = "res://src/ui/main_menu.gd"
const MAIN_MENU_SCENE := "res://src/ui/main_menu.tscn"
const SettingsManagerScript = preload("res://src/core/settings_manager.gd")


func before_test() -> void:
	_cleanup_settings()
	_reset_audio_manager()
	TurnManager.reset_engine()
	GameState.triggered_events.clear()


func after_test() -> void:
	_cleanup_settings()
	_reset_audio_manager()
	TurnManager.reset_engine()


func test_settings_popup_cancel_restores_action_interactivity() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var settings_button := scene.find_child("SettingsButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(settings_button).is_not_null()
	assert_object(execute_button).is_not_null()

	settings_button.pressed.emit()
	await await_idle_frame()

	var settings_popup := scene.find_child("SettingsPopup", true, false) as PopupPanel
	var cancel_button := scene.find_child("SettingsCancelButton", true, false) as Button
	assert_object(settings_popup).is_not_null()
	assert_object(cancel_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	cancel_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_object(scene.find_child("SettingsPopup", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()


func test_settings_popup_reflects_saved_values() -> void:
	SettingsManagerScript.save_settings({
		"window_mode": "windowed",
		"ui_scale": 1.25,
	})
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var settings_button := scene.find_child("SettingsButton", true, false) as Button
	assert_object(settings_button).is_not_null()

	settings_button.pressed.emit()
	await await_idle_frame()

	var ui_scale_option := scene.find_child("SettingsUiScaleOption", true, false) as OptionButton
	assert_object(ui_scale_option).is_not_null()
	assert_bool(absf(float(ui_scale_option.get_item_metadata(ui_scale_option.get_selected_id())) - 1.25) < 0.001).is_true()


func test_settings_popup_open_does_not_shift_main_layout_geometry() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var settings_button := scene.find_child("SettingsButton", true, false) as Button
	var decision_tray := scene.find_child("DecisionTray", true, false) as PanelContainer
	var map_scroll := scene.find_child("MapScroll", true, false) as ScrollContainer
	assert_object(settings_button).is_not_null()
	assert_object(decision_tray).is_not_null()
	assert_object(map_scroll).is_not_null()

	var tray_rect_before := decision_tray.get_global_rect()
	var map_rect_before := map_scroll.get_global_rect()

	settings_button.pressed.emit()
	await await_idle_frame()

	var settings_popup := scene.find_child("SettingsPopup", true, false) as PopupPanel
	var cancel_button := scene.find_child("SettingsCancelButton", true, false) as Button
	assert_object(settings_popup).is_not_null()
	assert_object(cancel_button).is_not_null()

	var tray_rect_after := decision_tray.get_global_rect()
	var map_rect_after := map_scroll.get_global_rect()
	assert_bool(absf(tray_rect_before.size.y - tray_rect_after.size.y) < 1.0).is_true()
	assert_bool(absf(map_rect_before.size.x - map_rect_after.size.x) < 1.0).is_true()
	assert_bool(absf(map_rect_before.size.y - map_rect_after.size.y) < 1.0).is_true()

	cancel_button.pressed.emit()
	await runner.simulate_frames(2)


func test_settings_popup_uses_modal_lock_copy_instead_of_end_day_copy() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var settings_button := scene.find_child("SettingsButton", true, false) as Button
	var tray_hint := scene.find_child("TrayHint", true, false) as Label
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(settings_button).is_not_null()
	assert_object(tray_hint).is_not_null()
	assert_object(execute_button).is_not_null()

	settings_button.pressed.emit()
	await await_idle_frame()

	assert_str(tray_hint.text).contains("设置已打开")
	assert_bool("正在结束今天" not in tray_hint.text).is_true()
	assert_str(execute_button.text).is_equal("先选择动作")


func test_settings_popup_hidden_externally_restores_action_interactivity() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var settings_button := scene.find_child("SettingsButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(settings_button).is_not_null()
	assert_object(execute_button).is_not_null()

	settings_button.pressed.emit()
	await await_idle_frame()

	var settings_popup := scene.find_child("SettingsPopup", true, false) as PopupPanel
	assert_object(settings_popup).is_not_null()
	assert_bool(settings_popup.exclusive).is_true()
	assert_bool(execute_button.disabled).is_true()

	settings_popup.hide()
	await runner.simulate_frames(2)

	assert_object(scene.find_child("SettingsPopup", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()


func test_settings_apply_persists_ui_scale() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var settings_button := scene.find_child("SettingsButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(settings_button).is_not_null()
	assert_object(execute_button).is_not_null()

	settings_button.pressed.emit()
	await await_idle_frame()

	var ui_scale_option := scene.find_child("SettingsUiScaleOption", true, false) as OptionButton
	var apply_button := scene.find_child("SettingsApplyButton", true, false) as Button
	assert_object(ui_scale_option).is_not_null()
	assert_object(apply_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	_select_option_metadata(ui_scale_option, 1.1)
	apply_button.pressed.emit()
	await runner.simulate_frames(2)

	var settings := SettingsManagerScript.load_settings()
	assert_bool(absf(float(settings.get("ui_scale", 0.0)) - 1.1) < 0.001).is_true()
	assert_bool(absf(scene.get_window().content_scale_factor - 1.1) < 0.001).is_true()
	assert_object(scene.find_child("SettingsPopup", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()


func test_settings_cancel_does_not_persist_unsaved_changes() -> void:
	SettingsManagerScript.save_settings({
		"window_mode": "windowed",
		"ui_scale": 1.0,
	})
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var settings_button := scene.find_child("SettingsButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(settings_button).is_not_null()
	assert_object(execute_button).is_not_null()

	settings_button.pressed.emit()
	await await_idle_frame()

	var ui_scale_option := scene.find_child("SettingsUiScaleOption", true, false) as OptionButton
	var cancel_button := scene.find_child("SettingsCancelButton", true, false) as Button
	assert_object(ui_scale_option).is_not_null()
	assert_object(cancel_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	_select_option_metadata(ui_scale_option, 1.25)
	cancel_button.pressed.emit()
	await runner.simulate_frames(2)

	var settings := SettingsManagerScript.load_settings()
	assert_bool(absf(float(settings.get("ui_scale", 0.0)) - 1.0) < 0.001).is_true()
	assert_bool(absf(scene.get_window().content_scale_factor - 1.0) < 0.001).is_true()
	assert_bool(execute_button.disabled).is_false()


func test_settings_reset_restores_defaults() -> void:
	SettingsManagerScript.save_settings({
		"window_mode": "fullscreen",
		"ui_scale": 1.25,
	})
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var settings_button := scene.find_child("SettingsButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(settings_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(absf(scene.get_window().content_scale_factor - 1.25) < 0.001).is_true()

	settings_button.pressed.emit()
	await await_idle_frame()

	var reset_button := scene.find_child("SettingsResetButton", true, false) as Button
	assert_object(reset_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	reset_button.pressed.emit()
	await runner.simulate_frames(2)

	var settings := SettingsManagerScript.load_settings()
	assert_str(String(settings.get("window_mode", ""))).is_equal("windowed")
	assert_bool(absf(float(settings.get("ui_scale", 0.0)) - 1.0) < 0.001).is_true()
	assert_bool(absf(scene.get_window().content_scale_factor - 1.0) < 0.001).is_true()
	assert_object(scene.find_child("SettingsPopup", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()


func test_settings_popup_exposes_audio_sliders_with_current_values() -> void:
	var audio_manager := _audio_manager()
	assert_object(audio_manager).is_not_null()
	audio_manager.set_music_volume(0.35)
	audio_manager.set_sfx_volume(0.65)

	var runner := await _load_main_menu()
	var scene := runner.scene()
	var settings_button := scene.find_child("SettingsButton", true, false) as Button
	assert_object(settings_button).is_not_null()

	settings_button.pressed.emit()
	await await_idle_frame()

	var music_slider := scene.find_child("SettingsMusicVolumeSlider", true, false) as HSlider
	var sfx_slider := scene.find_child("SettingsSfxVolumeSlider", true, false) as HSlider
	assert_object(music_slider).is_not_null()
	assert_object(sfx_slider).is_not_null()
	assert_bool(absf(music_slider.value - 0.35) < 0.001).is_true()
	assert_bool(absf(sfx_slider.value - 0.65) < 0.001).is_true()


func test_settings_audio_sliders_update_audio_manager_immediately() -> void:
	var audio_manager := _audio_manager()
	assert_object(audio_manager).is_not_null()

	var runner := await _load_main_menu()
	var scene := runner.scene()
	var settings_button := scene.find_child("SettingsButton", true, false) as Button
	assert_object(settings_button).is_not_null()

	settings_button.pressed.emit()
	await await_idle_frame()

	var music_slider := scene.find_child("SettingsMusicVolumeSlider", true, false) as HSlider
	var sfx_slider := scene.find_child("SettingsSfxVolumeSlider", true, false) as HSlider
	assert_object(music_slider).is_not_null()
	assert_object(sfx_slider).is_not_null()

	music_slider.value = 0.45
	sfx_slider.value = 0.55
	await runner.simulate_frames(2)

	assert_bool(absf(audio_manager.get_music_volume() - 0.45) < 0.001).is_true()
	assert_bool(absf(audio_manager.get_sfx_volume() - 0.55) < 0.001).is_true()


func test_battle_popup_cancel_keeps_action_phase() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()

	scene.call("_show_battle_popup")
	await await_idle_frame()

	var battle_popup := scene.find_child("BattlePopup", true, false) as PopupPanel
	var cancel_button := scene.find_child("BattleCancelButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(battle_popup).is_not_null()
	assert_object(cancel_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	cancel_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_object(scene.find_child("BattlePopup", true, false)).is_null()
	assert_str(GameState.current_phase).is_equal("action")
	assert_bool(execute_button.disabled).is_false()


func test_boost_popup_disables_confirm_when_legitimacy_too_low() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()

	GameState.legitimacy = 5.0
	scene.call("_show_boost_popup")
	await await_idle_frame()

	var boost_popup := scene.find_child("BoostPopup", true, false) as PopupPanel
	var confirm_button := scene.find_child("BoostConfirmButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(boost_popup).is_not_null()
	assert_object(confirm_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(confirm_button.disabled).is_true()
	assert_bool(execute_button.disabled).is_true()


func test_boost_popup_cancel_restores_action_interactivity() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()

	scene.call("_show_boost_popup")
	await await_idle_frame()

	var boost_popup := scene.find_child("BoostPopup", true, false) as PopupPanel
	var cancel_button := scene.find_child("BoostCancelButton", true, false) as Button
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(boost_popup).is_not_null()
	assert_object(cancel_button).is_not_null()
	assert_object(execute_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	cancel_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_object(scene.find_child("BoostPopup", true, false)).is_null()
	assert_str(GameState.current_phase).is_equal("action")
	assert_bool(execute_button.disabled).is_false()


func test_battle_submit_failure_restores_action_interactivity() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var dialogs_controller := scene.find_child("DialogsController", true, false)
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(dialogs_controller).is_not_null()
	assert_object(execute_button).is_not_null()

	dialogs_controller.call("set_callbacks", {
		"set_tray_interactive": Callable(scene, "_set_tray_interactive"),
		"submit_action": Callable(self, "_always_fail_submit_action")
	})

	scene.call("_show_battle_popup")
	await await_idle_frame()

	var confirm_button := scene.find_child("BattleConfirmButton", true, false) as Button
	assert_object(confirm_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	confirm_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_object(scene.find_child("BattlePopup", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()
	assert_str(GameState.current_phase).is_equal("action")


func test_battle_submit_success_keeps_day_until_manual_end() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	var end_day_button := scene.find_child("EndDayButton", true, false) as Button
	assert_object(execute_button).is_not_null()
	assert_object(end_day_button).is_not_null()
	assert_int(GameState.current_day).is_equal(1)

	scene.call("_show_battle_popup")
	await await_idle_frame()

	var battle_popup := scene.find_child("BattlePopup", true, false) as PopupPanel
	var confirm_button := scene.find_child("BattleConfirmButton", true, false) as Button
	assert_object(battle_popup).is_not_null()
	assert_object(confirm_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	confirm_button.pressed.emit()
	await runner.simulate_frames(6)

	assert_object(scene.find_child("BattlePopup", true, false)).is_null()
	assert_int(GameState.current_day).is_equal(1)
	assert_str(GameState.current_phase).is_equal("action")
	assert_bool(GameState.maneuver_available).is_false()
	assert_str(tray_controller.get_selected_policy_id()).is_equal("")
	assert_bool(execute_button.disabled).is_false()

	end_day_button.pressed.emit()
	await runner.simulate_frames(8)

	assert_int(GameState.current_day).is_equal(2)
	assert_bool(GameState.maneuver_available).is_true()


func test_boost_submit_success_keeps_day_until_manual_end() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var tray_controller = runner.get_property("_tray_controller")
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	var end_day_button := scene.find_child("EndDayButton", true, false) as Button
	assert_object(execute_button).is_not_null()
	assert_object(end_day_button).is_not_null()
	assert_int(GameState.current_day).is_equal(1)
	assert_bool(GameState.legitimacy >= 10.0).is_true()

	scene.call("_show_boost_popup")
	await await_idle_frame()

	var boost_popup := scene.find_child("BoostPopup", true, false) as PopupPanel
	var confirm_button := scene.find_child("BoostConfirmButton", true, false) as Button
	assert_object(boost_popup).is_not_null()
	assert_object(confirm_button).is_not_null()
	assert_bool(confirm_button.disabled).is_false()
	assert_bool(execute_button.disabled).is_true()

	confirm_button.pressed.emit()
	await runner.simulate_frames(6)

	assert_object(scene.find_child("BoostPopup", true, false)).is_null()
	assert_int(GameState.current_day).is_equal(1)
	assert_str(GameState.current_phase).is_equal("action")
	assert_int(GameState.actions_remaining).is_equal(1)
	assert_str(tray_controller.get_selected_policy_id()).is_equal("")
	assert_bool(execute_button.disabled).is_false()

	end_day_button.pressed.emit()
	await runner.simulate_frames(8)

	assert_int(GameState.current_day).is_equal(2)


func test_boost_submit_failure_restores_action_interactivity() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var dialogs_controller := scene.find_child("DialogsController", true, false)
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(dialogs_controller).is_not_null()
	assert_object(execute_button).is_not_null()

	dialogs_controller.call("set_callbacks", {
		"set_tray_interactive": Callable(scene, "_set_tray_interactive"),
		"submit_action": Callable(self, "_always_fail_submit_action")
	})

	scene.call("_show_boost_popup")
	await await_idle_frame()

	var confirm_button := scene.find_child("BoostConfirmButton", true, false) as Button
	assert_object(confirm_button).is_not_null()
	assert_bool(execute_button.disabled).is_true()

	confirm_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_object(scene.find_child("BoostPopup", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()
	assert_str(GameState.current_phase).is_equal("action")


func test_game_over_overlay_disables_action_and_shows_restart() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	assert_object(execute_button).is_not_null()

	scene.call("_on_game_over", "political_collapse")
	await runner.simulate_frames(2)

	var overlay := scene.find_child("GameOverOverlay", true, false) as ColorRect
	var restart_button := scene.find_child("GameOverRestartButton", true, false) as Button
	var title_label := scene.find_child("GameOverTitleLabel", true, false) as Label
	assert_object(overlay).is_not_null()
	assert_object(restart_button).is_not_null()
	assert_object(title_label).is_not_null()
	assert_bool(execute_button.disabled).is_true()
	assert_str(title_label.text.strip_edges()).is_not_equal("")


func test_game_over_restart_resets_day_and_clears_overlay() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var execute_button := scene.find_child("ExecuteActionButton", true, false) as Button
	var tray_controller = runner.get_property("_tray_controller")

	tray_controller.select_policy("rest")
	await runner.simulate_frames(2)
	runner.invoke("_on_confirm_pressed")
	await runner.simulate_frames(6)
	(scene.find_child("EndDayButton", true, false) as Button).pressed.emit()
	await runner.simulate_frames(8)
	assert_int(GameState.current_day).is_equal(2)

	scene.call("_on_game_over", "political_collapse")
	await runner.simulate_frames(2)
	var restart_button := scene.find_child("GameOverRestartButton", true, false) as Button
	assert_object(restart_button).is_not_null()

	restart_button.pressed.emit()
	await runner.simulate_frames(4)

	assert_int(GameState.current_day).is_equal(1)
	assert_str(GameState.current_phase).is_equal("action")
	assert_object(scene.find_child("GameOverOverlay", true, false)).is_null()
	assert_bool(execute_button.disabled).is_false()


func test_game_over_stats_clamp_display_day_to_100() -> void:
	var runner := await _load_main_menu()
	var scene := runner.scene()
	var dialogs_controller := scene.find_child("DialogsController", true, false)
	assert_object(dialogs_controller).is_not_null()

	dialogs_controller.call(
		"show_game_over",
		"waterloo_historical",
		{
			"current_day": 128,
			"legitimacy": 12.0,
			"victories": 4,
			"total_troops": 21000,
			"avg_morale": 44.0,
			"supply": 21.0
		}
	)
	await runner.simulate_frames(2)

	var stats_label := scene.find_child("GameOverStatsLabel", true, false) as Label
	assert_object(stats_label).is_not_null()
	assert_str(stats_label.text).contains("天数: 100")


func _load_main_menu() -> GdUnitSceneRunner:
	var runner := scene_runner(MAIN_MENU_SCENE)
	await runner.simulate_frames(12)
	var close_button := runner.scene().find_child("TutorialPopupCloseButton", true, false) as Button
	if close_button != null:
		close_button.pressed.emit()
		await runner.simulate_frames(2)
	return runner


func _cleanup_settings() -> void:
	SettingsManagerScript.clear_settings()
	SettingsManagerScript.apply_settings(SettingsManagerScript.default_settings())


func _audio_manager() -> Node:
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop == null:
		return null
	var root: Window = main_loop.root
	if root == null or not root.has_node("AudioManager"):
		return null
	return root.get_node("AudioManager")


func _reset_audio_manager() -> void:
	var audio_manager := _audio_manager()
	if audio_manager == null:
		return
	audio_manager.set_master_volume(1.0)
	audio_manager.set_music_volume(0.8)
	audio_manager.set_sfx_volume(1.0)
	audio_manager.set_muted(false)


func _select_option_metadata(option_button: OptionButton, metadata: Variant) -> void:
	for index in range(option_button.item_count):
		var item_metadata: Variant = option_button.get_item_metadata(index)
		if item_metadata is float and metadata is float:
			if is_equal_approx(float(item_metadata), float(metadata)):
				option_button.select(index)
				return
		elif item_metadata == metadata:
			option_button.select(index)
			return


func _always_fail_submit_action(_action_name: String, _payload: Dictionary) -> bool:
	return false
