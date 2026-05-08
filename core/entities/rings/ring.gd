class_name Ring
extends Node2D

## Rotary ring. Passive receiver of rot_t from Sequencer.
## Slots are spawned at runtime based on interval_type.
## ring_index maps this ring to its entry in Sequencer._rotations.

signal note_triggered(orb_id: Orb.OrbType, texture: Texture2D, from_pos: Vector2, ring_index: int)

enum IntervalType { QUARTER, EIGHTH, SIXTEENTH }

const SLOT_COUNTS: Dictionary = {
	IntervalType.QUARTER:      4,
	IntervalType.EIGHTH:       8,
	IntervalType.SIXTEENTH:    16,
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
		interval_type = value
		load_modifier = _get_load_modifier()
		_rebuild_slots()

var load_modifier = _get_load_modifier()

@onready var _slots_container: Node2D = $Slots

var _slots: Array[Slot] = []

func _ready() -> void:
	_rebuild_slots()
	_connect_detectors()

func tick(rot_t: float) -> void:
	rotation = rot_t * TAU

func apply_rotation(rot_t: float) -> void:
	rotation = rot_t * TAU

func eject_all_orbs() -> void:
	for slot: Slot in _slots:
		if slot.is_occupied():
			slot.eject_orb()

func get_slots() -> Array[Slot]:
	return _slots

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

func _connect_detectors() -> void:
	for child: Node in get_children():
		var detector := child as Detector
		if detector == null:
			continue
		if not detector.orb_passed.is_connected(_on_detector_orb_passed):
			detector.orb_passed.connect(_on_detector_orb_passed)

func _on_detector_orb_passed(orb_id: Orb.OrbType, texture: Texture2D, from_pos: Vector2) -> void:
	note_triggered.emit(orb_id, texture, from_pos, ring_index)

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
	_calculate_slot_positions()

func _calculate_slot_positions() -> void:
	var count: int = _slots.size()
	if count == 0:
		return
	for i: int in range(count):
		_slots[i].index = i
		var angle: float = (TAU / float(count)) * float(i)
		_slots[i].position = Vector2(cos(angle), sin(angle)) * radius


func slot_at_modified_index(index: int) -> Slot:
	if (load_modifier == 1):
		return _slots[index]
	var new_index = index / load_modifier
	if(new_index % 2 == 0):
		return _slots[new_index]
	return null
	
func _get_load_modifier() -> int:
	match interval_type:
		IntervalType.QUARTER:
			return 4
		IntervalType.EIGHTH:
			return 2
		IntervalType.SIXTEENTH:
			return 1
	return -1
