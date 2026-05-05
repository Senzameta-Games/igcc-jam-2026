class_name PlaybackController
extends Button

func _ready() -> void:
	toggle_mode = true
	button_pressed = false

func connect_hand(hand: Hand) -> void:
	hand.note_picked_up.connect(_on_note_picked_up)
	hand.note_dropped.connect(_on_note_dropped)

func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Playback.start()
	else:
		Playback.stop()

func _on_note_picked_up(_note: Note) -> void:
	disabled = true
	button_pressed = false

func _on_note_dropped() -> void:
	disabled = false
