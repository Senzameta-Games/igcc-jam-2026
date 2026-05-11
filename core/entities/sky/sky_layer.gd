class_name SkyLayer
extends Node2D

signal transition_finished
signal transition_midpoint
signal focus_requested

@export var transition_duration: float = 2.0
@export var transition_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition_trans: Tween.TransitionType = Tween.TRANS_SINE

## Position when Sky is the active mode (fully visible).
@export var position_active: Vector2 = Vector2(960, 900)
## Position when Sky is minimized (Desk is active — peek at top).
@export var position_minimized: Vector2 = Vector2(960, 200)
## Duration for the active/minimized position+scale tween.
@export var mode_transition_duration: float = 0.5
@export var mode_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var mode_trans: Tween.TransitionType = Tween.TRANS_CUBIC

## PianoRoll scale when Sky is the active mode.
@export var piano_roll_scale_sky: Vector2 = Vector2(1.0, 1.0)
## PianoRoll scale when Desk is active (piano roll peeks above sequencer).
@export var piano_roll_scale_desk: Vector2 = Vector2(0.7, 0.7)

var _tween: Tween = null
var _mode_tween: Tween = null
var _is_minimized: bool = false

@onready var _hit_area: Area2D = $HitArea
@onready var _piano_roll: PianoRoll = $PianoRoll

func _ready() -> void:
	_hit_area.input_event.connect(_on_hit_area_input)
	_refresh_hit_area()

## Called by ConsoleMode via mode_changed signal.
func on_mode_changed(mode: ConsoleMode.Mode) -> void:
	match mode:
		ConsoleMode.Mode.SKY:
			_is_minimized = false
			_tween_to(position_active, piano_roll_scale_sky)
		ConsoleMode.Mode.DESK:
			_is_minimized = true
			_tween_to(position_minimized, piano_roll_scale_desk)
	_refresh_hit_area()

## Level transition rotation — unchanged from original.
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

	# Pivot compensation: keep fan_origin stationary in SkyLayer space as scale changes.
	# fan_origin is in PianoRoll local space. We want the point it occupies in
	# SkyLayer space to not move when scale changes.
	#
	# current pivot in SkyLayer space:
	#   pivot_sky = piano_roll.position + fan_origin * piano_roll.scale
	# after scale change we need:
	#   new_piano_position = pivot_sky - fan_origin * target_scale
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

## HitArea is only active when minimized so clicks pass through
## to the sequencer when Sky is the active layer.
func _refresh_hit_area() -> void:
	_hit_area.monitoring = _is_minimized
	_hit_area.monitorable = _is_minimized

func _on_hit_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _is_minimized:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		focus_requested.emit()

func _on_transition_midpoint() -> void:
	transition_midpoint.emit()

func _on_transition_finished() -> void:
	rotation = fmod(rotation, TAU)
	transition_finished.emit()
