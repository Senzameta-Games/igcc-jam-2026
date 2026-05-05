class_name Tray
extends Node2D

@onready var _slots_container: Node2D = $Slots

func connect_hand(hand: Hand) -> void:
	for child: Node in _slots_container.get_children():
		var slot := child as Slot
		if slot == null:
			continue
		hand.connect_slot(slot)
