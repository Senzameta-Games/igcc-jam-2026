extends Node

signal started
signal stopped
signal tick_advanced(tick_index: int)

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

func advance_tick(tick: int) -> void:
	tick_advanced.emit(tick)
