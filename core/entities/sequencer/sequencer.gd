extends Node2D

@onready var _sequence: Sequence = $Sequence
@onready var _button: Button = $StartStop/Button
@onready var _rings: Node2D = $Rings
@onready var _tray: Tray = $Tray
@onready var _detectors: Node2D = $Detectors

func inject_hand(hand: Hand) -> void:
	var controller := _button as PlaybackButton
	if controller == null:
		return
	controller.connect_hand(hand)
	_tray.connect_hand(hand)
	for child: Node in _rings.get_children():
		var ring := child as Ring
		if ring == null:
			continue
		ring.connect_hand_to_slot(hand)
	for child: Node in _detectors.get_children():
		var detector := child as Detector
		if detector == null:
			continue
		_sequence.register_detector(detector)
		SoundPlayer.register_detector(detector)
