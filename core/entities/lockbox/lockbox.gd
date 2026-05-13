class_name Lockbox
extends Node2D

signal unlocked

var _is_unlocked: bool = false

func _ready() -> void:
	for child: Node in $Slots.get_children():
		var slot := child as Slot
		if slot != null:
			slot.orb_placed.connect(_on_slot_orb_placed)

func _on_slot_orb_placed(_orb: Orb) -> void:
	if _is_unlocked:
		return
	if _all_slots_have_pearls():
		_is_unlocked = true
		unlocked.emit()

func _all_slots_have_pearls() -> bool:
	for child: Node in $Slots.get_children():
		var slot := child as Slot
		if slot == null:
			continue
		var orb: Orb = slot.get_orb()
		if orb == null or not orb.is_pearl:
			return false
	return true
