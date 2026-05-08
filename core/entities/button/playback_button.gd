class_name PlaybackButton
extends Button

func _ready() -> void:
	toggle_mode = true
	button_pressed = false

func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Playback.start()
	else:
		Playback.stop()

func _on_picked_up(_orb: Orb) -> void:
	disabled = true
	button_pressed = false

func _on_dropped() -> void:
	disabled = false
