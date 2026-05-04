class_name Note
extends Node2D

signal selected(note: Note)

@export var slot_index: int = 0
@export var note_id: StringName = &""
@export var texture: Texture2D

var slot_t: float = 0.0
var is_selected: bool = false

var _orbit: Orbit

func initialize(orbit: Orbit) -> void:
	_orbit = orbit
	_update_slot_t()

func move_to_slot(new_index: int) -> void:
	slot_index = new_index
	_update_slot_t()
	is_selected = false

func _update_slot_t() -> void:
	slot_t = float(slot_index) / float (_orbit.slot_count)

func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			is_selected = true
			selected.emit(self)
