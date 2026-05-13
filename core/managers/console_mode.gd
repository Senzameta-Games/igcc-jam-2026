class_name ConsoleMode
extends Node

signal mode_changed(mode: Mode)

enum Mode { DESK, SKY, LEVEL_SELECT }

var current_mode: Mode = Mode.LEVEL_SELECT

func _ready() -> void:
	Playback.started.connect(_on_playback_started)
	Playback.stopped.connect(_on_playback_stopped)

func initialize() -> void:
	mode_changed.emit(current_mode)

func request_sky() -> void:
	if Playback.is_playing:
		return
	_set_mode(Mode.SKY)

func request_level_select() -> void:
	if Playback.is_playing:
		return
	_set_mode(Mode.LEVEL_SELECT)

func force_level_select() -> void:
	_set_mode(Mode.LEVEL_SELECT)

func request_desk() -> void:
	if Playback.is_playing:
		return
	_set_mode(Mode.DESK)

func _on_playback_started() -> void:
	_set_mode(Mode.SKY)

func _on_playback_stopped() -> void:
	_set_mode(Mode.DESK)

func _set_mode(new_mode: Mode) -> void:
	if current_mode == new_mode:
		return
	current_mode = new_mode
	mode_changed.emit(current_mode)
