class_name Hand
extends Node2D

signal picked_up(note: Note)
signal dropped

var _held_note: Note = null

func _process(delta: float) -> void:
	if not _held_note: return
	_held_note.global_position = get_global_mouse_position()

func pick_up(note: Note) -> void:
	if not note: return
	_held_note = note
	_held_note.reparent(self, true)
	_held_note.lift()
	picked_up.emit(_held_note)
	
func try_drop(slot: Slot) -> void:
	if _held_note == null:
		return
	var note_to_drop: Note = _held_note
	_held_note = null
	var ejected: Note = slot.receive_note(note_to_drop)
	if ejected != null:
		pick_up(ejected)
		return
	dropped.emit()
		
func is_holding() -> bool:
	return _held_note != null

func connect_slot(slot: Slot) -> void:
	slot.slot_interacted.connect(_on_slot_interacted)
 
func _on_slot_interacted(slot: Slot) -> void:
	if Playback.is_playing:
		return
	if _held_note != null:
		try_drop(slot)
	elif slot.is_occupied():
		pick_up(slot.eject_note())
