extends Button

func _ready() -> void:
	toggle_mode = true
	button_pressed = false
	
func _on_toggled(toggled_on):
	if toggled_on:
		Playback.start()
	else:
		Playback.stop()
