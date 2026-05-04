class_name Note
extends Node2D

# the thing that crosses the playhead
# while playback is stopped, position is snapped to a slot. the player can move it to a new slot

signal selected(note: Note)

const LERP_SPEED: float = 4.0

@export var slot_index: int = 0
@export var note_id: StringName = &""
@export var texture: Texture2D

var slot_t: float = 0.0
var visual_t: float = 0.0
var is_selected: bool = false

var _orbit: Orbit

func initialize(orbit: Orbit) -> void:
	_orbit = orbit
	_update_slot_t()
	visual_t = slot_t

func move_to_slot(new_index: int) -> void:
	slot_index = new_index
	_update_slot_t()
	is_selected = false

func tick_visual_t(delta: float) -> void:
	var diff: float = slot_t - visual_t
	# wrap to shortest path (-0.5 to 0.5)
	if diff > 0.5:
		diff -= 1.0
	elif diff < -0.5:
		diff += 1.0
	var distance: float = abs(diff)
	if distance < 0.001:
		visual_t = slot_t
		return
	var step: float = delta * LERP_SPEED / float(_orbit.slot_count)
	visual_t = fmod(visual_t + sign(diff) * step, 1.0)
	if visual_t < 0.0:
		visual_t += 1.0

func _update_slot_t() -> void:
	slot_t = float(slot_index) / float (_orbit.slot_count)

func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			is_selected = true
			selected.emit(self)
