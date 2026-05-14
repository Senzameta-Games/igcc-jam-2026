class_name AudioManager
extends Node

@export var audio_offset_db: float = 4.0
@export var audio_fade_duration: float = 1.0

const DUCK_DB: float = -8.0
const DUCK_ATTACK: float = 0.1
const DUCK_RELEASE: float = 0.6

@onready var _bgm: AudioStreamPlayer = $BGM
@onready var _room_tone: AudioStreamPlayer = $RoomTone
@onready var _screen_up_sfx: AudioStreamPlayer = $ScreenUp
@onready var _screen_down_sfx: AudioStreamPlayer = $ScreenDown
@onready var _level_complete: AudioStreamPlayer = $LevelComplete
@onready var _level_start: AudioStreamPlayer = $LevelStart

var _audio_tween: Tween = null
var _duck_tween: Tween = null
var _prev_mode: ConsoleMode.Mode = ConsoleMode.Mode.CONSOLE
var _mode_ready: bool = false
var _bgm_base_db: float = 0.0
var _bgm_target_db: float = 0.0
var _room_tone_base_db: float = 0.0
var _level_complete_base_db: float = 0.0

func _ready() -> void:
	_bgm_base_db = _bgm.volume_db
	_bgm_target_db = _bgm_base_db
	_room_tone_base_db = _room_tone.volume_db
	_level_complete_base_db = _level_complete.volume_db

func on_mode_changed(mode: ConsoleMode.Mode) -> void:
	if _mode_ready:
		var prev_rank := _mode_rank(_prev_mode)
		var new_rank := _mode_rank(mode)
		if new_rank > prev_rank:
			_screen_up_sfx.play()
		elif new_rank < prev_rank:
			_screen_down_sfx.play()
	_prev_mode = mode
	_mode_ready = true
	var bgm_offset: float = _mode_rank(mode) * audio_offset_db - audio_offset_db
	_bgm_target_db = _bgm_base_db + bgm_offset
	if _duck_tween != null and _duck_tween.is_running():
		_duck_tween.kill()
	if _audio_tween != null and _audio_tween.is_running():
		_audio_tween.kill()
	_audio_tween = create_tween().set_parallel(true)
	_audio_tween.tween_property(_bgm, "volume_db", _bgm_target_db, audio_fade_duration)
	_audio_tween.tween_property(_room_tone, "volume_db", _room_tone_base_db - bgm_offset, audio_fade_duration)

func fade_for_completion() -> void:
	var bgm_offset: float = _mode_rank(ConsoleMode.Mode.LEVEL_SELECT) * audio_offset_db - audio_offset_db
	_bgm_target_db = _bgm_base_db + bgm_offset
	if _duck_tween != null and _duck_tween.is_running():
		_duck_tween.kill()
	if _audio_tween != null and _audio_tween.is_running():
		_audio_tween.kill()
	_audio_tween = create_tween().set_parallel(true)
	_audio_tween.tween_property(_bgm, "volume_db", _bgm_target_db, audio_fade_duration)
	_audio_tween.tween_property(_room_tone, "volume_db", _room_tone_base_db - bgm_offset, audio_fade_duration)
	_prev_mode = ConsoleMode.Mode.LEVEL_SELECT

func play_level_complete() -> void:
	_level_complete.volume_db = -80.0
	_level_complete.play()
	var t := create_tween()
	t.tween_property(_level_complete, "volume_db", _level_complete_base_db, audio_fade_duration)
	_duck_bgm(_level_complete)

func play_level_start() -> void:
	_level_start.play()
	_duck_bgm(_level_start)

func _duck_bgm(sfx: AudioStreamPlayer) -> void:
	if _duck_tween != null and _duck_tween.is_running():
		_duck_tween.kill()
	var stream_length: float = sfx.stream.get_length() if sfx.stream != null else 1.0
	_duck_tween = create_tween()
	_duck_tween.tween_property(_bgm, "volume_db", _bgm_target_db + DUCK_DB, DUCK_ATTACK)
	_duck_tween.tween_interval(maxf(0.0, stream_length - DUCK_ATTACK))
	_duck_tween.tween_property(_bgm, "volume_db", _bgm_target_db, DUCK_RELEASE)

func _mode_rank(mode: ConsoleMode.Mode) -> int:
	match mode:
		ConsoleMode.Mode.CONSOLE: return 0
		ConsoleMode.Mode.LEVEL_SELECT: return 1
	return 0
