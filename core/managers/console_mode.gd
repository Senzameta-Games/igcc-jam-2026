class_name ConsoleMode
extends Node

## Owns the two-state Workstation mode: DESK (compose) and SKY (observe).
## Two drivers can change mode:
##   1. Playback state. Started → SKY, stopped → DESK (always)
##   2. Player input. Manual toggle via request_sky() / request_desk()
##      (only available when stopped; ignored during playback)
##
## Consumers connect to mode_changed and handle their own visual response.
## Nothing in this script touches positions, tweens, or visuals directly.
##
## Call initialize() from Main after all listeners are connected to broadcast
## the initial DESK state so nodes snap to their correct startup positions.

signal mode_changed(mode: Mode)

enum Mode { DESK, SKY }

var current_mode: Mode = Mode.DESK

func _ready() -> void:
	Playback.started.connect(_on_playback_started)
	Playback.stopped.connect(_on_playback_stopped)

## Broadcasts the current mode to all listeners without requiring a state change.
## Call once from Main after all mode_changed connections are established.
func initialize() -> void:
	mode_changed.emit(current_mode)

func request_sky() -> void:
	if Playback.is_playing:
		return
	_set_mode(Mode.SKY)

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
