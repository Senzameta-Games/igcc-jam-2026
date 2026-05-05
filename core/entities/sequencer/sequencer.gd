extends Node2D

@onready var _sequence: Sequence = $Sequence

func _ready() -> void:
	print("Sequence node: ", _sequence)
	for child in get_children():
		var orbit: Orbit = child as Orbit
		if orbit == null:
			continue
		_sequence.register_orbit(orbit)
