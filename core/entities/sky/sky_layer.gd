class_name SkyLayer
extends Node2D
 
## Emitted when the full rotation transition completes.
signal transition_finished
 
## Duration of one full 360° rotation in seconds.
@export var transition_duration: float = 2.0
## Easing applied to the rotation tween.
@export var transition_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition_trans: Tween.TransitionType = Tween.TRANS_SINE
 
var _tween: Tween = null
 
func rotate_to_next() -> void:
	if _tween != null and _tween.is_running():
		return
	var end: float = rotation + TAU
	_tween = create_tween()
	_tween.set_ease(transition_ease)
	_tween.set_trans(transition_trans)
	_tween.tween_property(self, "rotation", end, transition_duration)
	_tween.tween_callback(_on_transition_finished)
 
func _on_transition_finished() -> void:
	# Normalize rotation to avoid float drift over many transitions
	rotation = fmod(rotation, TAU)
	transition_finished.emit()
 
