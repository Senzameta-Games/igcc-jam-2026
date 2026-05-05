class_name Orbit
extends Node2D

signal note_crossed(note_id: StringName, texture: Texture2D)

@export var radius: float = 200.0:
	set(value):
		radius = value
		_recompute_slot_positions()

@export_group("Sequencing")
@export var rpm: float = 12.0

@onready var _slots_container: Node2D = $Slots

var _slots: Array[Slot] = []
var _hand: Hand = null
var _rot_t: float = 0.0

func _ready() -> void:
	# Collect any slots authored directly in the scene
	for child: Node in _slots_container.get_children():
		var slot := child as Slot
		if slot == null:
			continue
		_slots.append(slot)
	_recompute_slot_positions()

func _physics_process(delta: float) -> void:
	if not Playback.is_playing:
		return
	var prev_t: float = _rot_t
	_rot_t = fmod(_rot_t + (rpm / 60.0) * delta, 1.0)
	rotation = _rot_t * TAU
	_playhead_check(prev_t, _rot_t)

func inject_hand(hand: Hand) -> void:
	_hand = hand
	for slot: Slot in _slots:
		_hand.connect_slot(slot)

func add_slot() -> Slot:
	var slot_scene: PackedScene = preload("res://core/entities/slot/slot.tscn")
	var slot := slot_scene.instantiate() as Slot
	slot.index = _slots.size()
	_slots_container.add_child(slot)
	_slots.append(slot)
	_recompute_slot_positions()
	if _hand != null:
		_hand.connect_slot(slot)
	return slot

func remove_slot(slot: Slot) -> void:
	if not _slots.has(slot):
		return
	if slot.is_occupied() and _hand != null:
		_hand.pick_up(slot.eject_note())
	_slots.erase(slot)
	slot.queue_free()
	_recompute_slot_positions()
	# Re-index remaining slots
	for i: int in range(_slots.size()):
		_slots[i].index = i

func _recompute_slot_positions() -> void:
	var count: int = _slots.size()
	if count == 0:
		return
	for i: int in range(count):
		var angle: float = (TAU / float(count)) * float(i)
		_slots[i].position = Vector2(cos(angle), sin(angle)) * radius

func _playhead_check(prev_t: float, curr_t: float) -> void:
	for slot: Slot in _slots:
		if not slot.is_occupied():
			continue
		var note: Note = slot.get_note()
		var slot_t: float = float(slot.index) / float(_slots.size())
		var prev_note_t: float = fmod(prev_t + slot_t, 1.0)
		var curr_note_t: float = fmod(curr_t + slot_t, 1.0)
		if _crossed_playhead(prev_note_t, curr_note_t):
			note_crossed.emit(note.note_id, note.texture)

func _crossed_playhead(prev_note_t: float, curr_note_t: float) -> bool:
	if curr_note_t < prev_note_t:
		curr_note_t += 1.0
	var threshold: float = 0.0
	if threshold < prev_note_t:
		threshold += 1.0
	return prev_note_t < threshold and threshold <= curr_note_t
