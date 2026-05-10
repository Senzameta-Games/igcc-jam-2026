class_name SkyLayer
extends Node2D

signal transition_finished
signal transition_midpoint

@export var transition_duration: float = 2.0
@export var transition_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition_trans: Tween.TransitionType = Tween.TRANS_SINE

var _tween: Tween = null

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

func _on_transition_midpoint() -> void:
	transition_midpoint.emit()

func _on_transition_finished() -> void:
	rotation = fmod(rotation, TAU)
	transition_finished.emit()
