extends Node

signal started
signal stopped

var is_playing: bool = false

func start() -> void:
	if is_playing:
		return
	is_playing = true
	started.emit()
	
func stop() -> void:
	if not is_playing:
		return
	is_playing = false
	stopped.emit()
