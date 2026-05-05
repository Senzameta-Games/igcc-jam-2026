class_name Hand
extends Node2D

signal picked_up(orb: Orb)
signal dropped

var _held_orb: Orb = null

func _process(delta: float) -> void:
	if not _held_orb: return
	_held_orb.global_position = get_global_mouse_position()

func pick_up(orb: Orb) -> void:
	if not orb: return
	_held_orb = orb
	_held_orb.reparent(self, true)
	_held_orb.lift()
	picked_up.emit(_held_orb)
	
func try_drop(slot: Slot) -> void:
	if _held_orb == null:
		return
	var orb_to_drop: Orb = _held_orb
	_held_orb = null
	var ejected: Orb = slot.receive_orb(orb_to_drop)
	if ejected != null:
		pick_up(ejected)
		return
	dropped.emit()
		
func is_holding() -> bool:
	return _held_orb != null

func connect_slot(slot: Slot) -> void:
	slot.slot_interacted.connect(_on_slot_interacted)
 
func _on_slot_interacted(slot: Slot) -> void:
	if Playback.is_playing:
		return
	if _held_orb != null:
		try_drop(slot)
	elif slot.is_occupied():
		pick_up(slot.eject_orb())
