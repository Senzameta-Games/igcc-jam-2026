class_name ConstellationHintDisplay
extends Node2D

## Renders a cropped, arc-shaped piano-roll grid hint from a raw solution array.
## Uses the same fan geometry as PianoRoll (angle × radius), scaled down.
## The cropped cells are auto-centered at the node's origin.

@export var star_textures: Array[Texture2D] = []

## Arc geometry — mirrors PianoRoll fan parameters at a smaller scale.
@export var fan_radius_inner: float = 80.0
@export var fan_radius_outer: float = 140.0
@export var fan_angle_span: float = 120.0

## Non-constellation grid stars.
@export var grid_star_scale: float = 0.3
@export var grid_star_color: Color = Color(0.0, 0.0, 0.0, 0.5)

## Constellation position stars.
@export var constellation_star_scale_min: float = 0.5
@export var constellation_star_scale_max: float = 0.7
@export var constellation_star_color: Color = Color(0.0, 0.0, 0.0, 1.0)

## Extra blank cells shown beyond the constellation bounding box for context.
@export var tick_padding: int = 2
@export var ring_padding: int = 1

## Flash animation when a tick fires during clue playback.
@export var flash_scale_multiplier: float = 1.5
@export var flash_in_duration: float = 0.08
@export var flash_out_duration: float = 0.15

const _TOTAL_TICKS: int = 16
const _TOTAL_RINGS: int = 3
const _MAX_TICK: int = 15
const _MAX_RING: int = 2

var _tick_stars: Dictionary = {}

func setup(solution: Array) -> void:
	clear()
	if star_textures.is_empty() or solution.is_empty():
		return

	var min_tick: int = _MAX_TICK
	var max_tick: int = 0
	var min_ring: int = _MAX_RING
	var max_ring: int = 0
	var constellation_keys: Dictionary = {}
	var found: bool = false

	for tick: int in range(solution.size()):
		for entry: Variant in (solution[tick] as Array):
			var ring: int = 0
			var orb_id: Orb.OrbType = Orb.OrbType.F3
			if(entry is Array):
				var entry_size = entry.size()
				if(entry_size > 0):
					ring = entry[0]
				if(entry_size > 1):
					orb_id = entry[1]
			min_tick = mini(min_tick, tick)
			max_tick = maxi(max_tick, tick)
			min_ring = mini(min_ring, ring)
			max_ring = maxi(max_ring, ring)
			constellation_keys[tick * 100 + ring] = {
				entryExists = true,
				orb_id = orb_id
			}
			found = true

	if not found:
		return

	min_tick = maxi(0, min_tick - tick_padding)
	max_tick = mini(_MAX_TICK, max_tick + tick_padding)
	min_ring = maxi(0, min_ring - ring_padding)
	max_ring = mini(_MAX_RING, max_ring + ring_padding)

	var cell_positions: Dictionary = {}
	var bbox_min := Vector2(INF, INF)
	var bbox_max := Vector2(-INF, -INF)

	for tick: int in range(min_tick, max_tick + 1):
		for ring: int in range(min_ring, max_ring + 1):
			var pos: Vector2 = _cell_pos(tick, ring, min_tick, max_tick, min_ring, max_ring)
			cell_positions[tick * 100 + ring] = pos
			bbox_min = bbox_min.min(pos)
			bbox_max = bbox_max.max(pos)

	var center_offset: Vector2 = -(bbox_min + bbox_max) * 0.5

	for tick: int in range(min_tick, max_tick + 1):
		for ring: int in range(min_ring, max_ring + 1):
			var key: int = tick * 100 + ring
			var pos: Vector2 = (cell_positions[key] as Vector2) + center_offset
			var is_constellation: bool = constellation_keys.has(key)
			var star := Sprite2D.new()
			star.texture = star_textures[randi() % star_textures.size()]
			star.rotation = randf_range(0.0, TAU)
			star.position = pos
			if is_constellation:
				var scale_val: float = randf_range(constellation_star_scale_min, constellation_star_scale_max)
				star.scale = Vector2(scale_val, scale_val)
				star.modulate = constellation_star_color
				star.set_meta("base_scale", star.scale)
				star.texture = KeyStar.KEY_STAR_TEXTURES[constellation_keys[key].orb_id]
				if not _tick_stars.has(tick):
					_tick_stars[tick] = []
				(_tick_stars[tick] as Array).append(star)
			else:
				star.scale = Vector2(grid_star_scale, grid_star_scale)
				star.modulate = grid_star_color
			add_child(star)

func flash_at_tick(tick: int) -> void:
	if not _tick_stars.has(tick):
		return
	for star: Sprite2D in (_tick_stars[tick] as Array):
		var base: Vector2 = star.get_meta("base_scale") as Vector2
		var t := create_tween()
		t.tween_property(star, "scale", base * flash_scale_multiplier, flash_in_duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(star, "scale", base, flash_out_duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

func clear() -> void:
	for child: Node in get_children():
		child.queue_free()
	_tick_stars.clear()

func _cell_pos(tick: int, ring: int, min_tick: int, max_tick: int, min_ring: int, max_ring: int) -> Vector2:
	var t_tick: float = float(tick - min_tick) / float(maxi(1, max_tick - min_tick))
	var angle_deg: float = -fan_angle_span * 0.5 + t_tick * fan_angle_span
	var angle_rad: float = deg_to_rad(angle_deg - 90.0)
	var t_ring: float = float(ring - min_ring) / float(maxi(1, max_ring - min_ring))
	var radius: float = lerpf(fan_radius_inner, fan_radius_outer, t_ring)
	return Vector2(cos(angle_rad), sin(angle_rad)) * radius
