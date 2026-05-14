class_name RayCaster
extends Node2D

signal note_triggered(orb_id: Orb.OrbType, texture: Texture2D, from_position: Vector2, tick: int, orb: Orb)

## Ray cast origin. Sits at [radius] + buffer away from the center along the X axis.
@export var ray_origin: Vector2 = Vector2(400.0, 0.0)
## World-space target of the ray, the sequencer center.
@export var ray_target: Vector2 = Vector2.ZERO
## Maximum number of hits to collect per sweep.
@export var max_hits: int = 3

@onready var _line: Line2D = $Ray

var _active: bool = false
var _sweep_pending: bool = false
var _pending_tick: int = 0

func _ready() -> void:
	Playback.started.connect(_on_playback_started)
	Playback.stopped.connect(_on_playback_stopped)
	Playback.tick_advanced.connect(_on_tick_advanced)
	_update_visual()

func _process(_delta: float) -> void:
	if not _sweep_pending:
		return
	_sweep_pending = false
	_sweep(_pending_tick)

## Called by Sequencer or externally to set world-space ray endpoints.
## Ray should point from outside the outermost ring toward the sequencer center.
func configure(origin: Vector2, target: Vector2) -> void:
	ray_origin = origin
	ray_target = target
	_update_visual()

func _on_playback_started() -> void:
	_active = true

func _on_playback_stopped() -> void:
	_active = false

func _on_tick_advanced(tick: int) -> void:
	if not _active:
		return
	_pending_tick = tick
	_sweep_pending = true

func _sweep(tick: int) -> void:
	var space := get_world_2d().direct_space_state
	var exclude: Array[RID] = []
	for _i in range(max_hits):
		var params := PhysicsRayQueryParameters2D.create(
			to_global(ray_origin), to_global(ray_target)
		)
		params.collision_mask = 2
		params.collide_with_areas = true
		params.collide_with_bodies = false
		params.exclude = exclude
		var result: Dictionary = space.intersect_ray(params)
		if result.is_empty():
			break
		var area := result["collider"] as Area2D
		if area == null:
			break
		var orb := area.get_parent() as Orb
		if orb != null:
			orb.play_note()
			note_triggered.emit(orb.orb_id, orb.key_star_texture, result["position"], tick, orb)
		exclude.append(result["rid"])

func _update_visual() -> void:
	if _line == null:
		return
	_line.clear_points()
	_line.add_point(ray_origin)
	_line.add_point(ray_target)
