extends Node2D

@onready var _sequence: Sequence = $Sequence
@onready var _controller: Button = $StartStop/Button

func inject_hand(hand: Hand) -> void:
	var controller := _controller as PlaybackController
	if controller == null:
		return
	controller.connect_hand(hand)
	for child: Node in get_children():
		var orbit := child as Orbit
		if orbit == null:
			continue
		orbit.inject_hand(hand)
		_sequence.register_orbit(orbit)
