class_name Hand
extends Node2D

signal picked_up(orb: Orb)
signal dropped

var _held_orb: Orb = null
var _slots: Array[Slot] = []

@onready var _area: Area2D = $Area

func _process(_delta: float) -> void:
	if _held_orb == null:
		return
	var mouse: Vector2 = get_global_mouse_position()
	_held_orb.global_position = mouse
	_area.global_position = mouse

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _held_orb == null:
		return
	if Playback.is_playing:
		return
	for area: Area2D in _area.get_overlapping_areas():
		var slot := area.get_parent() as Slot
		if slot == null:
			continue
		try_drop(slot)
		get_viewport().set_input_as_handled()
		return

func pick_up(orb: Orb) -> void:
	if orb == null:
		return
	_held_orb = orb
	_held_orb.reparent(self, true)
	_held_orb.lift()
	_show_all_drophint()
	picked_up.emit(_held_orb)

func try_drop(slot: Slot) -> void:
	if _held_orb == null:
		return
	var orb_to_drop: Orb = _held_orb
	_held_orb = null
	_hide_all_drophint()
	var ejected: Orb = slot.receive_orb(orb_to_drop)
	if ejected != null:
		pick_up(ejected)
		return
	dropped.emit()

func is_holding() -> bool:
	return _held_orb != null

func _show_all_drophint() -> void:
	for slot: Slot in _slots:
		if not slot.is_occupied():
			slot.show_drophint()

func _hide_all_drophint() -> void:
	for slot: Slot in _slots:
		slot.hide_drophint()

func connect_slot(slot: Slot) -> void:
	if not slot.slot_interacted.is_connected(_on_slot_interacted):
		slot.slot_interacted.connect(_on_slot_interacted)

func disconnect_slot(slot: Slot) -> void:
	if slot.slot_interacted.is_connected(_on_slot_interacted):
		slot.slot_interacted.disconnect(_on_slot_interacted)

func _on_slot_interacted(slot: Slot) -> void:
	if Playback.is_playing:
		return
	if _held_orb != null:
		return
	if slot.is_occupied():
		pick_up(slot.eject_orb())
