class_name PlaybackButton
extends Button

func _ready() -> void:
	toggle_mode = true
	button_pressed = false

func connect_hand(hand: Hand) -> void:
	hand.picked_up.connect(_on_picked_up)
	hand.dropped.connect(_on_dropped)

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
