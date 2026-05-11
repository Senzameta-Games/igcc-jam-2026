class_name Tray
extends Node2D

## Arc animation on mode change.
## The tray orbits around a pivot point (the sequencer center).
## Two angles define the resting (DESK) and hidden (SKY) positions.
## Orbit radius is computed at ready from the tray's initial position.
@export var tray_pivot: Vector2 = Vector2(960, 593)
@export var angle_desk_deg: float = 90.0
@export var angle_sky_deg: float = 210.0
@export var arc_transition_duration: float = 0.5
@export var arc_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var arc_trans: Tween.TransitionType = Tween.TRANS_CUBIC

@onready var _slots_container: Node2D = $Slots

var _orbit_radius: float = 0.0
var _current_angle_rad: float = 0.0
var _arc_tween: Tween = null

func _ready() -> void:
	_orbit_radius = global_position.distance_to(tray_pivot)
	_current_angle_rad = deg_to_rad(angle_desk_deg)

func on_mode_changed(mode: ConsoleMode.Mode) -> void:
	var target_deg: float = angle_sky_deg if mode == ConsoleMode.Mode.SKY else angle_desk_deg
	_animate_to(deg_to_rad(target_deg))

func _animate_to(target_rad: float) -> void:
	if _arc_tween != null and _arc_tween.is_running():
		_arc_tween.kill()
	_arc_tween = create_tween()
	_arc_tween.set_ease(arc_ease)
	_arc_tween.set_trans(arc_trans)
	_arc_tween.tween_method(_apply_angle, _current_angle_rad, target_rad, arc_transition_duration)

func _apply_angle(angle_rad: float) -> void:
	_current_angle_rad = angle_rad
	var dir := Vector2(cos(angle_rad), sin(angle_rad))
	global_position = tray_pivot + dir * _orbit_radius
	rotation = angle_rad - deg_to_rad(angle_desk_deg)

## Returns unique OrbTypes present in the tray, sorted highest to lowest pitch
## (descending enum value = highest note first).
func get_unique_orbs() -> Array[Orb.OrbType]:
	var seen: Dictionary = {}
	for child: Node in _slots_container.get_children():
		var slot := child as Slot
		if slot == null or not slot.is_occupied():
			continue
		seen[slot.get_orb().orb_id] = true
	var types: Array[Orb.OrbType] = []
	for key in seen.keys():
		types.append(key as Orb.OrbType)
	types.sort_custom(func(a: Orb.OrbType, b: Orb.OrbType) -> bool:
		return int(a) > int(b)
	)
	return types

func get_slot_for_orb(orb: Orb) -> Slot:
	return get_slot_for_type(orb.orb_id)

func get_slot_for_type(orb_id: Orb.OrbType) -> Slot:
	for child: Node in _slots_container.get_children():
		var slot: Slot = child
		if slot == null or not slot.is_occupied():
			continue
		if slot.get_orb().orb_id == orb_id:
			return slot
	return null
