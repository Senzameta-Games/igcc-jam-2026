class_name Ring
extends Node2D

const RESET_SPEED: float = 5.0
const RESET_THRESHOLD: float = 0.001

@export var radius: float = 200.0:
	set(value):
		radius = value
		_calculate_slot_positions()

@export_group("Sequencing")
@export var rpm: float = 12.0

@onready var _slots_container: Node2D = $Slots

var _slots: Array[Slot] = []
var _hand: Hand = null
var _rot_t: float = 0.0
var _resetting: bool = false

func _ready() -> void:
	Playback.stopped.connect(_on_playback_stopped)
	Playback.started.connect(_on_playback_started)
	for child: Node in _slots_container.get_children():
		var slot := child as Slot
		if slot == null:
			continue
		_slots.append(slot)
	_calculate_slot_positions()

func _physics_process(delta: float) -> void:
	if not Playback.is_playing:
		return
	_rot_t = fmod(_rot_t + (rpm / 60.0) * delta, 1.0)
	rotation = _rot_t * TAU

func _process(delta: float) -> void:
	if not _resetting:
		return
	# Lerp using shortest arc. if past halfway, approach 0 from above (negative target)
	var target: float = 0.0 if _rot_t <= 0.5 else 1.0
	_rot_t = lerpf(_rot_t, target, RESET_SPEED * delta)
	rotation = _rot_t * TAU
	if abs(_rot_t - target) < RESET_THRESHOLD or (target == 1.0 and abs(_rot_t - 1.0) < RESET_THRESHOLD):
		_rot_t = 0.0
		rotation = 0.0
		_resetting = false

func connect_hand_to_slot(hand: Hand) -> void:
	_hand = hand
	for slot: Slot in _slots:
		_hand.connect_slot(slot)

func add_slot() -> Slot:
	var slot_scene: PackedScene = preload("res://core/entities/slot/slot.tscn")
	var slot := slot_scene.instantiate() as Slot
	slot.index = _slots.size()
	_slots_container.add_child(slot)
	_slots.append(slot)
	_calculate_slot_positions()
	if _hand != null:
		_hand.connect_slot(slot)
	return slot

func remove_slot(slot: Slot) -> void:
	if not _slots.has(slot):
		return
	if slot.is_occupied() and _hand != null:
		_hand.pick_up(slot.eject_orb())
	_slots.erase(slot)
	slot.queue_free()
	_calculate_slot_positions()
	# Re-index remaining slots
	for i: int in range(_slots.size()):
		_slots[i].index = i

func _calculate_slot_positions() -> void:
	var count: int = _slots.size()
	if count == 0:
		return
	for i: int in range(count):
		var angle: float = (TAU / float(count)) * float(i)
		_slots[i].position = Vector2(cos(angle), sin(angle)) * radius

func _on_playback_stopped() -> void:
	_resetting = true

func _on_playback_started() -> void:
	_resetting = false
