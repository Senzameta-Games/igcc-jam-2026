class_name SkyLayer
extends Node2D

signal transition_finished
signal transition_midpoint

@export var transition_duration: float = 2.0
@export var transition_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition_trans: Tween.TransitionType = Tween.TRANS_SINE

## SkyLayer world position in CONSOLE mode (piano roll peeking above sequencer).
@export var position_console: Vector2 = Vector2(960, 200)
## SkyLayer world position during playback (shifted down, more piano roll visible).
@export var position_playback: Vector2 = Vector2(960, 900)
## SkyLayer world position in LEVEL_SELECT.
@export var position_level_select: Vector2 = Vector2(960, 1900)

## Duration for mode and playback position+scale tweens.
@export var mode_transition_duration: float = 0.5
@export var mode_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var mode_trans: Tween.TransitionType = Tween.TRANS_CUBIC

## PianoRoll scale in CONSOLE mode (not playing).
@export var piano_roll_scale_console: Vector2 = Vector2(0.7, 0.7)
## PianoRoll scale during playback.
@export var piano_roll_scale_playback: Vector2 = Vector2(1.0, 1.0)
## PianoRoll scale in LEVEL_SELECT.
@export var piano_roll_scale_level_select: Vector2 = Vector2(1.0, 1.0)


@export var cloud_layer: Sprite2D
@export var cloud_speed: float = 20.0
@export var cloud_wrap_right_x: float = 1920.0
@export var cloud_wrap_left_x: float = -1920.0

var _tween: Tween = null
var _mode_tween: Tween = null
var _mode_ready: bool = false
var _current_mode: ConsoleMode.Mode = ConsoleMode.Mode.LEVEL_SELECT

@onready var _piano_roll: PianoRoll = $PianoRoll
@onready var _level_select: LevelSelect = $LevelSelect

func _process(delta: float) -> void:
	move_clouds(delta)

func move_clouds(delta: float) -> void:
	if cloud_layer == null:
		return
	cloud_layer.position.x += cloud_speed * delta
	if cloud_layer.position.x > cloud_wrap_right_x:
		cloud_layer.position.x = cloud_wrap_left_x

func on_mode_changed(mode: ConsoleMode.Mode) -> void:
	_current_mode = mode
	if not _mode_ready:
		_mode_ready = true
		_snap_to_mode(mode)
	else:
		match mode:
			ConsoleMode.Mode.CONSOLE:
				_tween_to(position_console, piano_roll_scale_console)
			ConsoleMode.Mode.LEVEL_SELECT:
				_tween_to(position_level_select, piano_roll_scale_level_select)
	_level_select.on_mode_changed(mode)

func on_playback_state_changed(is_playing: bool) -> void:
	if _current_mode != ConsoleMode.Mode.CONSOLE:
		return
	if is_playing:
		_tween_to(position_playback, piano_roll_scale_playback)
	else:
		_tween_to(position_console, piano_roll_scale_console)

func _snap_to_mode(mode: ConsoleMode.Mode) -> void:
	var target_pos: Vector2
	var target_scale: Vector2
	match mode:
		ConsoleMode.Mode.CONSOLE:
			target_pos = position_console
			target_scale = piano_roll_scale_console
		_:
			target_pos = position_level_select
			target_scale = piano_roll_scale_level_select
	position = target_pos
	var pivot_local: Vector2 = _piano_roll.fan_origin
	var pivot_in_sky: Vector2 = _piano_roll.position + pivot_local * _piano_roll.scale
	_piano_roll.scale = target_scale
	_piano_roll.position = pivot_in_sky - pivot_local * target_scale

func rotate_to_next() -> void:
	if _tween != null and _tween.is_running():
		return
	var half: float = rotation + PI
	var end: float = rotation + TAU
	_tween = create_tween()
	_tween.set_ease(transition_ease)
	_tween.set_trans(transition_trans)
	_tween.tween_property(self, "rotation", half, transition_duration * 0.5)
	_tween.tween_callback(_on_transition_midpoint)
	_tween.tween_property(self, "rotation", end, transition_duration * 0.5)
	_tween.tween_callback(_on_transition_finished)

func _tween_to(target_position: Vector2, target_scale: Vector2) -> void:
	if _mode_tween != null and _mode_tween.is_running():
		_mode_tween.kill()

	var pivot_local: Vector2 = _piano_roll.fan_origin
	var pivot_in_sky: Vector2 = _piano_roll.position + pivot_local * _piano_roll.scale
	var target_piano_position: Vector2 = pivot_in_sky - pivot_local * target_scale

	_mode_tween = create_tween()
	_mode_tween.set_parallel(true)
	_mode_tween.set_ease(mode_ease)
	_mode_tween.set_trans(mode_trans)
	_mode_tween.tween_property(self, "position", target_position, mode_transition_duration)
	_mode_tween.tween_property(_piano_roll, "scale", target_scale, mode_transition_duration)
	_mode_tween.tween_property(_piano_roll, "position", target_piano_position, mode_transition_duration)

func _on_transition_midpoint() -> void:
	transition_midpoint.emit()

func _on_transition_finished() -> void:
	rotation = fmod(rotation, TAU)
	transition_finished.emit()
