class_name AudioManager
extends Node

@export var audio_offset_db: float = 4.0
@export var audio_fade_duration: float = 1.0

@onready var _bgm: AudioStreamPlayer = $BGM
@onready var _room_tone: AudioStreamPlayer = $RoomTone
@onready var _screen_up_sfx: AudioStreamPlayer = $ScreenUp
@onready var _screen_down_sfx: AudioStreamPlayer = $ScreenDown

var _audio_tween: Tween = null
var _prev_mode: ConsoleMode.Mode = ConsoleMode.Mode.DESK
var _mode_ready: bool = false
var _bgm_base_db: float = 0.0
var _room_tone_base_db: float = 0.0

func _ready() -> void:
	_bgm_base_db = _bgm.volume_db
	_room_tone_base_db = _room_tone.volume_db

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
	if _audio_tween != null and _audio_tween.is_running():
		_audio_tween.kill()
	_audio_tween = create_tween().set_parallel(true)
	_audio_tween.tween_property(_bgm, "volume_db", _bgm_base_db + bgm_offset, audio_fade_duration)
	_audio_tween.tween_property(_room_tone, "volume_db", _room_tone_base_db - bgm_offset, audio_fade_duration)

func _mode_rank(mode: ConsoleMode.Mode) -> int:
	match mode:
		ConsoleMode.Mode.DESK: return 0
		ConsoleMode.Mode.SKY: return 1
		ConsoleMode.Mode.LEVEL_SELECT: return 2
	return 0
