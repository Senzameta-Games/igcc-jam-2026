class_name Ring
extends Node2D

## Rotary ring. Passive receiver of rot_t from Sequencer.
## Slots are spawned at runtime based on interval_type.
## ring_index maps this ring to its entry in Sequencer._rotations.

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
		_rebuild_slots()

@onready var _slots_container: Node2D = $Slots

var _slots: Array[Slot] = []
var _hand: Hand = null

func _ready() -> void:
	_rebuild_slots()

func tick(rot_t: float) -> void:
	rotation = rot_t * TAU

func apply_rotation(rot_t: float) -> void:
	rotation = rot_t * TAU

func connect_hand_to_slot(hand: Hand) -> void:
	_hand = hand
	for slot: Slot in _slots:
		_hand.connect_slot(slot)

func eject_all_orbs() -> void:
	for slot: Slot in _slots:
		if slot.is_occupied() and _hand != null:
			_hand.pick_up(slot.eject_orb())

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

func _rebuild_slots() -> void:
	if _slots_container == null:
		return
	if _hand != null:
		for slot: Slot in _slots:
			_hand.disconnect_slot(slot)
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
	if _hand != null:
		for slot: Slot in _slots:
			_hand.connect_slot(slot)

func _calculate_slot_positions() -> void:
	var count: int = _slots.size()
	if count == 0:
		return
	for i: int in range(count):
		_slots[i].index = i
		var angle: float = (TAU / float(count)) * float(i)
		_slots[i].position = Vector2(cos(angle), sin(angle)) * radius

func _crossed_playhead(prev_orb_t: float, curr_orb_t: float) -> bool:
	if curr_orb_t < prev_orb_t:
		curr_orb_t += 1.0
	var threshold: float = 0.0
	if threshold < prev_orb_t:
		threshold += 1.0
	return prev_orb_t < threshold and threshold <= curr_orb_t
