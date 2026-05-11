class_name Tray
extends Node2D

@export var angle_desk_deg: float = 90.0
@export var angle_sky_deg: float = 210.0
@export var desk_pos: Vector2
@export var sky_pos: Vector2
@export var arc_transition_duration: float = 0.8
@export var arc_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var arc_trans: Tween.TransitionType = Tween.TRANS_BACK

@onready var _slots_container: Node2D = $Slots
@onready var _wind_up_sfx: AudioStreamPlayer = $WindUp
@onready var _wind_down_sfx: AudioStreamPlayer = $WindDown

var _current_angle_rad: float = 0.0
var _arc_tween: Tween = null
var _was_at_desk: bool = true

## Maps Orb.OrbType → Array[Slot]. Supports multiple same-type slots per level.
var _slots_by_type: Dictionary = {}

func _ready() -> void:
	_current_angle_rad = deg_to_rad(angle_desk_deg)
	position = desk_pos

func on_mode_changed(mode: ConsoleMode.Mode) -> void:
	var is_desk := mode == ConsoleMode.Mode.DESK
	if is_desk and not _was_at_desk:
		_wind_down_sfx.play()
	elif not is_desk and _was_at_desk:
		_wind_up_sfx.play()
	_was_at_desk = is_desk
	var target_deg: float = angle_desk_deg if is_desk else angle_sky_deg
	var target_pos: Vector2 = desk_pos if is_desk else sky_pos
	_animate_to(deg_to_rad(target_deg), target_pos)

func _animate_to(target_rad: float, target_pos: Vector2) -> void:
	if _arc_tween != null and _arc_tween.is_running():
		_arc_tween.kill()
	_arc_tween = create_tween().set_parallel(true)
	_arc_tween.set_ease(arc_ease)
	_arc_tween.set_trans(arc_trans)
	_arc_tween.tween_method(_apply_angle, _current_angle_rad, target_rad, arc_transition_duration)
	_arc_tween.tween_property(self, "position", target_pos, arc_transition_duration)

func _apply_angle(angle_rad: float) -> void:
	_current_angle_rad = angle_rad
	rotation = angle_rad - deg_to_rad(angle_desk_deg)

## Clears all tray slots and repopulates from orb_types (one orb per entry, duplicates allowed).
func populate(orb_types: Array[Orb.OrbType], level_index: int = -1) -> void:
	_slots_by_type.clear()
	var slots: Array[Slot] = _get_slots()
	for slot: Slot in slots:
		if slot.is_occupied():
			slot.eject_orb().queue_free()
	for i: int in range(mini(orb_types.size(), slots.size())):
		var orb_type: Orb.OrbType = orb_types[i]
		var orb: Orb = OrbRegistry.spawn(orb_type)
		if orb == null:
			continue
		orb.source_level = level_index
		slots[i].populate_with_orb(orb)
		if not _slots_by_type.has(orb_type):
			_slots_by_type[orb_type] = []
		(_slots_by_type[orb_type] as Array).append(slots[i])

func get_unique_orbs() -> Array[Orb.OrbType]:
	var types: Array[Orb.OrbType] = []
	for key in _slots_by_type.keys():
		types.append(key as Orb.OrbType)
	types.sort_custom(func(a: Orb.OrbType, b: Orb.OrbType) -> bool: return int(a) > int(b))
	return types

func get_slot_for_type(orb_id: Orb.OrbType) -> Slot:
	if not _slots_by_type.has(orb_id):
		return null
	for slot: Slot in (_slots_by_type[orb_id] as Array):
		if not slot.is_occupied():
			return slot
	return null

func get_occupied_slot_for_type(orb_id: Orb.OrbType) -> Slot:
	if not _slots_by_type.has(orb_id):
		return null
	for slot: Slot in (_slots_by_type[orb_id] as Array):
		if slot.is_occupied():
			return slot
	return null

func get_slot_for_orb(orb: Orb) -> Slot:
	return get_slot_for_type(orb.orb_id)

func snapshot_slots() -> Array:
	var snap: Array = []
	for slot: Slot in _get_slots():
		if slot.is_occupied():
			var orb: Orb = slot.get_orb()
			snap.append({"type": int(orb.orb_id), "source": orb.source_level})
		else:
			snap.append(null)
	return snap

func restore_snapshot(snapshot: Array) -> void:
	_slots_by_type.clear()
	var slots: Array[Slot] = _get_slots()
	for slot: Slot in slots:
		if slot.is_occupied():
			slot.eject_orb().queue_free()
	for i: int in range(mini(snapshot.size(), slots.size())):
		var entry: Variant = snapshot[i]
		if entry == null:
			continue
		var orb_type: Orb.OrbType = (entry as Dictionary)["type"] as Orb.OrbType
		var orb: Orb = OrbRegistry.spawn(orb_type)
		if orb == null:
			continue
		orb.source_level = (entry as Dictionary)["source"]
		slots[i].populate_with_orb(orb)
		if not _slots_by_type.has(orb_type):
			_slots_by_type[orb_type] = []
		(_slots_by_type[orb_type] as Array).append(slots[i])

func _get_slots() -> Array[Slot]:
	var slots: Array[Slot] = []
	for child: Node in _slots_container.get_children():
		var slot := child as Slot
		if slot != null:
			slots.append(slot)
	return slots
