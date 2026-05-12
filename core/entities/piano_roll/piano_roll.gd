class_name PianoRoll
extends Node2D

## Piano roll display. 16 columns (ticks) x 3 rows (rings, inner to outer).
## Rows are concentric arcs, columns are radial lines.
## Row 0 = innermost ring, row 2 = outermost ring.
## Three child layers (bottom to top): Stars, Keys, Dots.
## Stars: faint randomized star field at every grid vertex, re-rolled per level.
## Keys: hint stars at solution positions, shaped and colored by OrbType.
## Dots: player input orbs from sequencer playback.

## Radius of the innermost arc (ring 0).
@export var fan_radius_inner: float = 300.0
## Radius of the outermost arc (ring 2).
@export var fan_radius_outer: float = 600.0
## Total degrees the 16 ticks span across the fan.
@export var fan_angle_span: float = 120.0
## Vanishing point of the fan in local space. Move down to push the arc higher.
@export var fan_origin: Vector2 = Vector2(512.0, 800.0)
@export var playhead_lerp_speed: float = 18.0

## Star field configuration.
## Pool of star textures to randomly sample from. Assign in inspector.
@export var star_textures: Array[Texture2D] = []
## Scale range for random star sizing (min, max). Stars are 2x res, scale down here.
@export var star_scale_min: float = 0.15
@export var star_scale_max: float = 0.35
## Max positional jitter offset from exact grid vertex in pixels.
@export var star_jitter: float = 8.0
## Base modulate for faint stars. Alpha drives overall brightness.
@export var star_color: Color = Color(1.0, 1.0, 1.0, 0.18)

## Key (hint) star scale range. Color/texture come from KeyStar per OrbType.
@export var key_star_scale_min: float = 0.25
@export var key_star_scale_max: float = 0.45
@export var key_star_shader: Shader = null

@onready var _stars_container: Node2D = $Stars
@onready var _keys_container: Node2D = $Keys
@onready var _dots_container: Node2D = $Dots
@onready var _playhead: Node2D = $Playhead
@export var playhead_fade_speed: float = 8.0

const TICKS: int = 16
const RING_COUNT: int = 3
const ARRIVAL_SCALE: float = 0.18

const KEY_STAR_SCENE: PackedScene = preload("res://core/entities/key_star/key_star.tscn")

const _DEBUG_ARC_COLOR: Color = Color(1.0, 0.0, 1.0, 0.4)
const _DEBUG_RADIAL_COLOR: Color = Color(1.0, 1.0, 1.0, 0.15)
const _DEBUG_ORIGIN_COLOR: Color = Color(1.0, 1.0, 0.0, 0.6)
const _DEBUG_ARC_SEGMENTS: int = 48

## Sparse map of placed dots: key = tick * 100 + ring_index, value = Sprite2D node.
var _dots: Dictionary = {}

var _sequencer: Sequencer = null
var _playing: bool = false

func _ready() -> void:
	Playback.stopped.connect(_on_playback_stopped)
	Playback.started.connect(_on_playback_started)

func setup(tray: Tray) -> void:
	_rebuild_stars()
	queue_redraw()

func _process(delta: float) -> void:
	if _playhead == null or _sequencer == null:
		return

	var t: float = _sequencer.get_measure_t() if _playing else 0.0

	# Fade out from 0.9→1.0, snap, fade in from 0.0→0.1
	if t >= 0.9:
		var fade_t: float = (t - 0.9) / 0.1
		_playhead.modulate.a = lerpf(1.0, 0.0, fade_t)
	elif t <= 0.1:
		var fade_t: float = t / 0.1
		_playhead.modulate.a = lerpf(0.0, 1.0, fade_t)
	else:
		_playhead.modulate.a = 1.0

	_update_playhead(t * float(TICKS))

func set_sequencer(sequencer: Sequencer) -> void:
	_sequencer = sequencer

func get_cell_position(tick: int, ring_index: int) -> Vector2:
	return to_global(_cell_pos(tick, ring_index))

func clear_keys() -> void:
	for child: Node in _keys_container.get_children():
		child.queue_free()

func show_keys(solution: Array) -> void:
	clear_keys()
	for tick: int in range(solution.size()):
		for entry: Variant in (solution[tick] as Array):
			var ring_idx: int = 0 if not (entry is Array) else int((entry as Array)[0])
			var orb_type := (int(entry) if not (entry is Array) else int((entry as Array)[1])) as Orb.OrbType
			var ks := KEY_STAR_SCENE.instantiate() as KeyStar
			var scale_val: float = randf_range(key_star_scale_min, key_star_scale_max)
			ks.scale = Vector2(scale_val, scale_val)
			ks.rotation = randf_range(0.0, TAU)
			ks.position = _cell_pos(tick, ring_idx)
			_keys_container.add_child(ks)
			ks.setup(orb_type, key_star_shader)

func receive_orb(orb_id: Orb.OrbType, texture: Texture2D, tick: int, ring_index: int, measure_duration: float) -> void:
	var key: int = _cell_key(tick, ring_index)
	if _dots.has(key):
		(_dots[key] as Node).queue_free()
	var dot := Sprite2D.new()
	dot.texture = texture
	dot.scale = Vector2.ZERO
	dot.position = _cell_pos(tick, ring_index)
	_dots_container.add_child(dot)
	_dots[key] = dot
	var tween := dot.create_tween()
	tween.tween_property(dot, "scale", Vector2(ARRIVAL_SCALE, ARRIVAL_SCALE), 0.1) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	tween.tween_property(dot, "scale", Vector2.ZERO, measure_duration) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void:
		if _dots.get(key) == dot:
			_dots.erase(key)
		dot.queue_free()
	)

func _on_playback_started() -> void:
	_playing = true
	_clear_dots()

func _on_playback_stopped() -> void:
	_clear_dots()
	_playing = false
	_playhead.modulate.a = 1.0
	_update_playhead(0.0)

func _clear_dots() -> void:
	for dot in _dots.values():
		(dot as Node).queue_free()
	_dots.clear()

func _rebuild_stars() -> void:
	for child: Node in _stars_container.get_children():
		child.queue_free()
	if star_textures.is_empty():
		return
	for tick: int in range(TICKS):
		for ring: int in range(RING_COUNT):
			var base_pos: Vector2 = _cell_pos(tick, ring)
			var jitter: Vector2 = Vector2(
				randf_range(-star_jitter, star_jitter),
				randf_range(-star_jitter, star_jitter)
			)
			var star := Sprite2D.new()
			star.texture = star_textures[randi() % star_textures.size()]
			var scale_val: float = randf_range(star_scale_min, star_scale_max)
			star.scale = Vector2(scale_val, scale_val)
			star.rotation = randf_range(0.0, TAU)
			star.position = base_pos + jitter
			star.modulate = star_color
			_stars_container.add_child(star)

func _update_playhead(tick: float) -> void:
	if _playhead == null:
		return
	var angle_rad: float = _tick_angle_rad(tick)
	var mid_radius: float = (fan_radius_inner + fan_radius_outer) * 0.5
	_playhead.position = fan_origin + Vector2(cos(angle_rad), sin(angle_rad)) * mid_radius
	_playhead.rotation = angle_rad + PI * 0.5

func _cell_pos(tick: int, ring_index: int) -> Vector2:
	var angle_rad: float = _tick_angle_rad(float(tick))
	var radius: float = _note_radius(ring_index)
	return fan_origin + Vector2(cos(angle_rad), sin(angle_rad)) * radius

func _tick_angle_rad(tick: float) -> float:
	var t: float = tick / float(TICKS - 1)
	var angle_deg: float = -fan_angle_span * 0.5 + t * fan_angle_span
	return deg_to_rad(angle_deg - 90.0)

func _note_radius(ring_index: int) -> float:
	var t: float = float(ring_index) / float(RING_COUNT - 1)
	return lerpf(fan_radius_inner, fan_radius_outer, t)

func _cell_key(tick: int, ring_index: int) -> int:
	return tick * 100 + ring_index

## Returns solution positions as normalized Vector2 values in [-1, 1] space.
func get_constellation_points(solution: Array) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for tick: int in range(solution.size()):
		for entry: Variant in (solution[tick] as Array):
			var ring_idx: int = 0 if not (entry is Array) else int((entry as Array)[0])
			var angle_rad: float = _tick_angle_rad(float(tick))
			var radius: float = _note_radius(ring_idx)
			positions.append(fan_origin + Vector2(cos(angle_rad), sin(angle_rad)) * radius)

	if positions.is_empty():
		return positions

	var centroid := Vector2.ZERO
	for p: Vector2 in positions:
		centroid += p
	centroid /= float(positions.size())

	var max_dist: float = 0.001
	for p: Vector2 in positions:
		max_dist = maxf(max_dist, (p - centroid).length())

	var result: Array[Vector2] = []
	for p: Vector2 in positions:
		result.append((p - centroid) / max_dist)
	return result

# --- Debug draw ---

#func _draw() -> void:
	## Concentric arcs. One per ring.
	#for ring: int in range(RING_COUNT):
		#_draw_arc_segment(_note_radius(ring), _DEBUG_ARC_COLOR)
#
	## Radial lines. One per tick
	#for tick: int in range(TICKS):
		#var angle_rad: float = _tick_angle_rad(float(tick))
		#var dir: Vector2 = Vector2(cos(angle_rad), sin(angle_rad))
		#var from: Vector2 = fan_origin + dir * fan_radius_inner
		#var to: Vector2 = fan_origin + dir * fan_radius_outer
		#draw_line(from, to, _DEBUG_RADIAL_COLOR, 1.0)
#
	## Fan origin marker
	#draw_circle(fan_origin, 6.0, _DEBUG_ORIGIN_COLOR)
#
#func _draw_arc_segment(radius: float, color: Color) -> void:
	#var points: PackedVector2Array = []
	#for i: int in range(_DEBUG_ARC_SEGMENTS + 1):
		#var t: float = float(i) / float(_DEBUG_ARC_SEGMENTS)
		#var angle_deg: float = -fan_angle_span * 0.5 + t * fan_angle_span
		#var angle_rad: float = deg_to_rad(angle_deg - 90.0)
		#points.append(fan_origin + Vector2(cos(angle_rad), sin(angle_rad)) * radius)
	#for i: int in range(points.size() - 1):
		#draw_line(points[i], points[i + 1], color, 1.5)
