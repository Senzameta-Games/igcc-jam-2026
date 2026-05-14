class_name ConsoleMode
extends Node

signal mode_changed(mode: Mode)
signal playback_state_changed(is_playing: bool)

enum Mode { CONSOLE, LEVEL_SELECT }

var current_mode: Mode = Mode.LEVEL_SELECT

func _ready() -> void:
	Playback.started.connect(_on_playback_started)
	Playback.stopped.connect(_on_playback_stopped)

func initialize() -> void:
	mode_changed.emit(current_mode)

func request_console() -> void:
	if Playback.is_playing:
		return
	_set_mode(Mode.CONSOLE)

func request_level_select() -> void:
	if Playback.is_playing:
		return
	_set_mode(Mode.LEVEL_SELECT)

func force_level_select() -> void:
	_set_mode(Mode.LEVEL_SELECT)

func _on_playback_started() -> void:
	playback_state_changed.emit(true)

func _on_playback_stopped() -> void:
	playback_state_changed.emit(false)

func _set_mode(new_mode: Mode) -> void:
	if current_mode == new_mode:
		return
	current_mode = new_mode
	mode_changed.emit(current_mode)
