extends Node2D

@onready var _hand: Hand = $Interface/Hand
@onready var _sequencer: Node2D = $Sequencer

func _ready() -> void:
	_sequencer.inject_hand(_hand)
