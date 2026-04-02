## AudioManager — 全局音频管理器（自动加载单例）
## 负责 BGM 切换、SFX 播放、音量控制

extends Node

# BGM tracks mapped by context
const BGM_TRACKS := {
	"main_menu": "res://assets/audio/bgm/main_menu.ogg",
	"march": "res://assets/audio/bgm/march.ogg",
	"politics": "res://assets/audio/bgm/politics.ogg",
	"battle": "res://assets/audio/bgm/battle.ogg",
	"victory": "res://assets/audio/bgm/victory.ogg",
	"defeat": "res://assets/audio/bgm/defeat.ogg",
}

# SFX events mapped by action
const SFX_EVENTS := {
	"button_click": "res://assets/audio/sfx/button_click.ogg",
	"turn_advance": "res://assets/audio/sfx/turn_advance.ogg",
	"battle_resolve": "res://assets/audio/sfx/battle_resolve.ogg",
	"event_popup": "res://assets/audio/sfx/event_popup.ogg",
	"save_complete": "res://assets/audio/sfx/save_complete.ogg",
	"achievement": "res://assets/audio/sfx/achievement.ogg",
}

const CROSSFADE_DURATION := 1.0
const SFX_POOL_SIZE := 4

var _bgm_player_a: AudioStreamPlayer
var _bgm_player_b: AudioStreamPlayer
var _active_bgm_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0

var _master_volume: float = 1.0
var _music_volume: float = 0.8
var _sfx_volume: float = 1.0
var _muted: bool = false
var _current_bgm_key: String = ""


func _ready() -> void:
	_setup_audio_buses()
	_setup_bgm_players()
	_setup_sfx_pool()
	_load_audio_settings()


func _setup_audio_buses() -> void:
	# Ensure Music and SFX buses exist at runtime
	# Use default bus if custom buses aren't in the project
	pass


func _setup_bgm_players() -> void:
	_bgm_player_a = AudioStreamPlayer.new()
	_bgm_player_a.name = "BGMPlayerA"
	_bgm_player_a.bus = "Master"
	add_child(_bgm_player_a)

	_bgm_player_b = AudioStreamPlayer.new()
	_bgm_player_b.name = "BGMPlayerB"
	_bgm_player_b.bus = "Master"
	add_child(_bgm_player_b)

	_active_bgm_player = _bgm_player_a


func _setup_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		player.bus = "Master"
		add_child(player)
		_sfx_pool.append(player)


## Play BGM with crossfade. If same track is already playing, do nothing.
func play_bgm(track_key: String) -> void:
	if track_key == _current_bgm_key and _active_bgm_player.playing:
		return
	var path: String = BGM_TRACKS.get(track_key, "")
	if path == "":
		stop_bgm()
		return
	var stream := _load_audio_stream(path)
	if stream == null:
		return
	_current_bgm_key = track_key
	var old_player := _active_bgm_player
	var new_player := _bgm_player_b if _active_bgm_player == _bgm_player_a else _bgm_player_a
	_active_bgm_player = new_player
	new_player.stream = stream
	new_player.volume_db = linear_to_db(0.0)
	new_player.play()
	_crossfade(old_player, new_player)


func stop_bgm() -> void:
	_current_bgm_key = ""
	_bgm_player_a.stop()
	_bgm_player_b.stop()


## Play a one-shot SFX
func play_sfx(sfx_key: String) -> void:
	var path: String = SFX_EVENTS.get(sfx_key, "")
	if path == "":
		return
	var stream := _load_audio_stream(path)
	if stream == null:
		return
	var player := _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.volume_db = _effective_sfx_db()
	player.play()


func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_audio_settings()


func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_audio_settings()


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_audio_settings()


func set_muted(muted: bool) -> void:
	_muted = muted
	_apply_volumes()
	_save_audio_settings()


func get_master_volume() -> float:
	return _master_volume


func get_music_volume() -> float:
	return _music_volume


func get_sfx_volume() -> float:
	return _sfx_volume


func is_muted() -> bool:
	return _muted


func _apply_volumes() -> void:
	var effective_music_db := _effective_music_db()
	if _bgm_player_a.playing:
		_bgm_player_a.volume_db = effective_music_db
	if _bgm_player_b.playing:
		_bgm_player_b.volume_db = effective_music_db


func _effective_music_db() -> float:
	if _muted:
		return -80.0
	return linear_to_db(_master_volume * _music_volume)


func _effective_sfx_db() -> float:
	if _muted:
		return -80.0
	return linear_to_db(_master_volume * _sfx_volume)


func _crossfade(old_player: AudioStreamPlayer, new_player: AudioStreamPlayer) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(new_player, "volume_db", _effective_music_db(), CROSSFADE_DURATION)
	if old_player.playing:
		tween.tween_property(old_player, "volume_db", linear_to_db(0.001), CROSSFADE_DURATION)
		tween.chain().tween_callback(old_player.stop)


func _load_audio_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


## Persist audio settings using the same config file pattern as SettingsManager
const AUDIO_SETTINGS_PATH := "user://cent_jours_audio.cfg"


func _save_audio_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", _master_volume)
	config.set_value("audio", "music_volume", _music_volume)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.set_value("audio", "muted", _muted)
	config.save(AUDIO_SETTINGS_PATH)


func _load_audio_settings() -> void:
	var config := ConfigFile.new()
	if config.load(AUDIO_SETTINGS_PATH) != OK:
		return
	_master_volume = float(config.get_value("audio", "master_volume", 1.0))
	_music_volume = float(config.get_value("audio", "music_volume", 0.8))
	_sfx_volume = float(config.get_value("audio", "sfx_volume", 1.0))
	_muted = bool(config.get_value("audio", "muted", false))
	_apply_volumes()
