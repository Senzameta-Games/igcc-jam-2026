class_name Ring
extends Node2D

## Rotary ring. Passive receiver of rot_t from Sequencer.
## Interval type determines which slot group is active.
## ring_index maps this ring to its entry in Sequencer._rotations.

enum IntervalType { QUARTER, EIGHTH, SIXTEENTH }

const RESET_SPEED: float = 5.0
const RESET_THRESHOLD: float = 0.001

@export var ring_index: int = 0
@export var radius: float = 200.0:
	set(value):
		radius = value
		_calculate_slot_positions()

@export var interval_type: IntervalType = IntervalType.QUARTER:
	set(value):
		interval_type = value
		_activate_interval_group()

@onready var _slots4: Node2D = $Slots4
@onready var _slots8: Node2D = $Slots8
@onready var _slots16: Node2D = $Slots16

var _slots: Array[Slot] = []
var _hand: Hand = null

func _ready() -> void:
	_activate_interval_group()

func tick(rot_t: float) -> void:
	## Called by Sequencer each physics frame during playback.
	rotation = rot_t * TAU
	_playhead_check(rot_t)

func apply_rotation(rot_t: float) -> void:
	## Called by Sequencer each process frame during reset lerp.
	rotation = rot_t * TAU

func connect_hand_to_slot(hand: Hand) -> void:
	_hand = hand
	for slot: Slot in _slots:
		_hand.connect_slot(slot)

func eject_all_orbs() -> void:
	## Called when interval type changes. Returns orbs to tray.
	for slot: Slot in _slots:
		if slot.is_occupied() and _hand != null:
			_hand.pick_up(slot.eject_orb())

func get_slot_count() -> int:
	return _slots.size()

func _activate_interval_group() -> void:
	if _slots4 == null:
		return
	_slots4.visible = false
	_slots8.visible = false
	_slots16.visible = false
	_slots.clear()
	var active: Node2D
	match interval_type:
		IntervalType.QUARTER:
			active = _slots4
		IntervalType.EIGHTH:
			active = _slots8
		IntervalType.SIXTEENTH:
			active = _slots16
	active.visible = true
	for child: Node in active.get_children():
		var slot := child as Slot
		if slot == null:
			continue
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

func _playhead_check(rot_t: float) -> void:
	pass
	## NOTE: Crossing detection has moved to Detector (Area2D overlap).
	## This method is kept as a hook for future per-ring crossing logic.

func _crossed_playhead(prev_orb_t: float, curr_orb_t: float) -> bool:
	if curr_orb_t < prev_orb_t:
		curr_orb_t += 1.0
	var threshold: float = 0.0
	if threshold < prev_orb_t:
		threshold += 1.0
	return prev_orb_t < threshold and threshold <= curr_orb_t
