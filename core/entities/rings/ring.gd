class_name Ring
extends Node2D

## Rotary ring. Passive receiver of rot_t from Sequencer.
## Slots are spawned at runtime based on interval_type.
## ring_index maps this ring to its entry in Sequencer._rotations.

signal slots_rebuilt

enum IntervalType { QUARTER, EIGHTH, SIXTEENTH, TUTORIAL }

const SLOT_COUNTS: Dictionary = {
	IntervalType.QUARTER:      4,
	IntervalType.EIGHTH:       8,
	IntervalType.SIXTEENTH:    16,
	IntervalType.TUTORIAL:     2,
}

const RESET_SPEED: float = 5.0
const RESET_THRESHOLD: float = 0.001

const SLOT_SCENE: PackedScene = preload("res://core/entities/slot/slot.tscn")
@export var ring_index: int = 0
@export var radius: float = 200.0:
	set(value):
		radius = value
		_calculate_slot_positions()

@export var interval_type: IntervalType = IntervalType.QUARTER:
	set(value):
		if interval_type == value:
			return
		interval_type = value
		load_modifier = _get_load_modifier()
		_rebuild_slots()

var load_modifier = _get_load_modifier()

var _rotation_speed: float = 0.0
var _current_angle: float = 0.0

@onready var _slots_container: Node2D = $Slots

var _slots: Array[Slot] = []

func _ready() -> void:
	_rebuild_slots()

func _process(delta: float) -> void:
	if _rotation_speed == 0.0:
		return
	_current_angle += _rotation_speed * delta
	rotation = _current_angle

func eject_all_orbs() -> void:
	for slot: Slot in _slots:
		slot.disabled = false
		while slot.is_occupied():
			var removed_orb = slot.eject_orb()
			removed_orb.queue_free()

func get_current_angle() -> float:
	return _current_angle

func set_current_angle(angle: float) -> void:
	_current_angle = angle
	rotation = angle

func set_active(active: bool) -> void:
	visible = active
	for slot: Slot in _slots:
		if not slot.visible:
			continue
		var handle := slot.get_node("Handle") as Area2D
		if handle == null:
			continue
		handle.monitorable = active
		handle.monitoring = active

func get_slots() -> Array[Slot]:
	return _slots

func set_rotation_speed(radians_per_second: float) -> void:
	_rotation_speed = radians_per_second

func get_slot_count() -> int:
	return _slots.size()

func get_orbs() -> Array:
	var sorted_slots: Array[Slot] = _slots.duplicate()
	sorted_slots.sort_custom(func(a: Slot, b: Slot) -> bool:
		return a.index < b.index
	)
	var ret: Array = []
	for slot: Slot in sorted_slots:
		ret.append(slot.get_orb())
	return ret

func _rebuild_slots() -> void:
	if _slots_container == null:
		return
	eject_all_orbs()
	for slot: Slot in _slots:
		_slots_container.remove_child(slot)
		slot.queue_free()
	_slots.clear()
	var count: int = SLOT_COUNTS.get(interval_type, 4)
	for i: int in range(count):
		var slot := SLOT_SCENE.instantiate() as Slot
		_slots_container.add_child(slot)
		slot.index = i
		_slots.append(slot)
	if interval_type == IntervalType.TUTORIAL:
		_slots[0].visible = false
		var hidden_handle := _slots[0].get_node_or_null("Handle") as Area2D
		if hidden_handle != null:
			hidden_handle.monitorable = false
			hidden_handle.monitoring = false
	_calculate_slot_positions()

func _calculate_slot_positions() -> void:
	var count: int = _slots.size()
	if count == 0:
		return
	for i: int in range(count):
		_slots[i].index = i
		var angle: float = (TAU / float(count)) * float(i) * -1
		_slots[i].position = Vector2(cos(angle), sin(angle)) * radius
	if _slots_container != null:
		slots_rebuilt.emit()


func slot_at_modified_index(index: int) -> Slot:
	if (load_modifier == 1):
		return _slots[index]
	var new_index = round(index / load_modifier)
	return _slots[new_index]

func _get_load_modifier() -> int:
	match interval_type:
		IntervalType.QUARTER:
			return 4
		IntervalType.EIGHTH:
			return 2
		IntervalType.SIXTEENTH:
			return 1
		IntervalType.TUTORIAL:
			return 8
	return -1
