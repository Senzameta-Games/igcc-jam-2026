class_name SkyLayer
extends Node2D

signal transition_finished
signal transition_midpoint
signal desk_area_hovered(active: bool)  # SKY hover near bottom → sequencer frame glow

@export var transition_duration: float = 2.0
@export var transition_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition_trans: Tween.TransitionType = Tween.TRANS_SINE

## Position when Sky is the active mode (fully visible).
@export var position_active: Vector2 = Vector2(960, 900)
## Position when Sky is minimized (Desk is active, peek at top).
@export var position_minimized: Vector2 = Vector2(960, 200)
## Duration for the active/minimized position+scale tween.
@export var mode_transition_duration: float = 0.5
@export var mode_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var mode_trans: Tween.TransitionType = Tween.TRANS_CUBIC

## PianoRoll scale when Sky is the active mode.
@export var piano_roll_scale_sky: Vector2 = Vector2(1.0, 1.0)
## PianoRoll scale when Desk is active (piano roll peeks above sequencer).
@export var piano_roll_scale_desk: Vector2 = Vector2(0.7, 0.7)

## SkyLayer world position for LEVEL_SELECT.
@export var position_level_select: Vector2 = Vector2(960, 1900)

## SKY hover affordance: viewport y above which hovering near the bottom emits desk_area_hovered.
@export var desk_hover_y_threshold: float = 850.0

var _tween: Tween = null
var _mode_tween: Tween = null
var _is_minimized: bool = false
var _desk_glow_active: bool = false
var _current_mode: ConsoleMode.Mode = ConsoleMode.Mode.DESK

@onready var _piano_roll: PianoRoll = $PianoRoll
@onready var _level_select: LevelSelect = $LevelSelect

func on_mode_changed(mode: ConsoleMode.Mode) -> void:
	_current_mode = mode
	# Clear desk glow when leaving SKY.
	if mode != ConsoleMode.Mode.SKY and _desk_glow_active:
		_desk_glow_active = false
		desk_area_hovered.emit(false)
	match mode:
		ConsoleMode.Mode.SKY:
			_is_minimized = false
			_tween_to(position_active, piano_roll_scale_sky)
		ConsoleMode.Mode.DESK:
			_is_minimized = true
			_tween_to(position_minimized, piano_roll_scale_desk)
		ConsoleMode.Mode.LEVEL_SELECT:
			_is_minimized = false
			_tween_to(position_level_select, piano_roll_scale_sky)
	_level_select.on_mode_changed(mode)

func _process(_delta: float) -> void:
	if _mode_tween != null and _mode_tween.is_running():
		return
	if _current_mode == ConsoleMode.Mode.SKY:
		_update_desk_glow(get_viewport().get_mouse_position().y)

func _update_desk_glow(mouse_y: float) -> void:
	var should_glow: bool = mouse_y > desk_hover_y_threshold
	if should_glow == _desk_glow_active:
		return
	_desk_glow_active = should_glow
	desk_area_hovered.emit(should_glow)

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
