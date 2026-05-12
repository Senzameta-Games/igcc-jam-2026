class_name PlaybackButton
extends Button

const LOCK_DURATION: float = 0.85

var _locked: bool = false

func _ready() -> void:
	toggle_mode = true
	button_pressed = false

func _on_toggled(toggled_on: bool) -> void:
	if _locked:
		set_pressed_no_signal(not toggled_on)
		return
	_locked = true
	if toggled_on:
		Playback.start()
	else:
		Playback.stop()
	get_tree().create_timer(LOCK_DURATION).timeout.connect(func() -> void:
		_locked = false
	)

func _on_picked_up(_orb: Orb) -> void:
	disabled = true
	set_pressed_no_signal(false)

func _on_dropped() -> void:
	disabled = false
