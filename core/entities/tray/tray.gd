class_name Tray
extends Node2D

@onready var _slots_container: Node2D = $Slots

## Returns unique OrbTypes present in the tray, sorted highest to lowest pitch
## (descending enum value = highest note first).
func get_unique_orbs() -> Array[Orb.OrbType]:
	var seen: Dictionary = {}
	for child: Node in _slots_container.get_children():
		var slot := child as Slot
		if slot == null or not slot.is_occupied():
			continue
		seen[slot.get_orb().orb_id] = true
	var types: Array[Orb.OrbType] = []
	for key in seen.keys():
		types.append(key as Orb.OrbType)
	types.sort_custom(func(a: Orb.OrbType, b: Orb.OrbType) -> bool:
		return int(a) > int(b)
	)
	return types

func get_slot_for_orb(orb: Orb) -> Slot:
	for child: Node in _slots_container.get_children():
		var slot := child as Slot
		if slot == null or not slot.is_occupied():
			continue
		if(slot.get_orb().orb_id == orb.orb_id):
			return slot
	return null
