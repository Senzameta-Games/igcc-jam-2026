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
@export var fan_radius_inner: float = 300.0:
	set(value):
		fan_radius_inner = value
		_on_fan_geometry_changed()
## Radius of the outermost arc (ring 2).
@export var fan_radius_outer: float = 600.0:
	set(value):
		fan_radius_outer = value
		_on_fan_geometry_changed()
## Total degrees the 16 ticks span across the fan.
@export var fan_angle_span: float = 120.0:
	set(value):
		fan_angle_span = value
		_on_fan_geometry_changed()
## Vanishing point of the fan in local space. Move down to push the arc higher.
@export var fan_origin: Vector2 = Vector2(512.0, 800.0):
	set(value):
		fan_origin = value
		_on_fan_geometry_changed()
@export var playhead_lerp_speed: float = 18.0

## Star field configuration.
## Pool of star textures to randomly sample from. Assign in inspector.
@export var star_textures: Array[Texture2D] = []
@export var slot_texture: Texture2D
@export var slot_marker_scale: float = 0.3
@export var slot_marker_enter_duration: float = 0.15
@export var slot_marker_enter_trans: Tween.TransitionType = Tween.TRANS_BACK
@export var ghost_marker_opacity: float = 0.5
@export var ghost_marker_scale_min: float = 0.22
@export var ghost_marker_scale_max: float = 0.28
@export var ghost_marker_pulse_duration: float = 0.4
@export var line_star_spacing: float = 18.0
@export var line_star_scale_min: float = 0.06
@export var line_star_scale_max: float = 0.12
@export var line_star_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var line_position_jitter: float = 8.0
@export var line_spacing_jitter: float = 0.35
@export var line_enter_duration: float = 0.12
@export var line_enter_step_delay: float = 0.015
## Points farther than this (in fan local pixels) are treated as separate constellations.
## 0 = no limit.
@export var max_constellation_distance: float = 200.0
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
@onready var _lines_container: Node2D = $Lines
@onready var _slot_markers_container: Node2D = $Slots
@onready var _keys_container: Node2D = $Keys
@onready var _dots_container: Node2D = $Dots
@onready var _playhead: Node2D = $Playhead
@export var playhead_fade_speed: float = 8.0

const TICKS: int = 16
const RING_COUNT: int = 3
const KEY_STAR_ARRIVAL_SCALE: float = 0.5
const CORRECT_ARRIVAL_SCALE: float = 0.7
const KEY_STAR_MIN_SCALE: float = 0.35

const KEY_STAR_SCENE: PackedScene = preload("res://core/entities/key_star/key_star.tscn")

const _DEBUG_ARC_COLOR: Color = Color(1.0, 0.0, 1.0, 0.4)
const _DEBUG_RADIAL_COLOR: Color = Color(1.0, 1.0, 1.0, 0.15)
const _DEBUG_ORIGIN_COLOR: Color = Color(1.0, 1.0, 0.0, 0.6)
const _DEBUG_ARC_SEGMENTS: int = 48

signal constellation_completed
signal completion_pending

## Persistent key stars placed on first detection. key = tick * 100 + ring_index.
var _dots: Dictionary = {}
var _dot_tweens: Dictionary = {}
var _slot_markers: Dictionary = {}
## Each constellation: {keys: Array[int], positions: Array[Vector2], segments: Array[Array]}
## segments[i] is the Array[Sprite2D] connecting positions[i] to positions[i+1].
var _constellations: Array[Dictionary] = []

var _ghost_marker: Sprite2D = null
var _ghost_tween: Tween = null
var _ghost_key: int = -1

var _sequencer: DeskLayer = null
var _playing: bool = false

var _solution: Array[LevelManager.SolutionData] = []
var _hit_positions: Dictionary = {}
var _solution_position_count: int = 0
var _pending_completion: bool = false
var _completion_signaled: bool = false
var _key_star_material: ShaderMaterial = null

class _LoadSlotMarker:
	var tick: int = -1
	var ring_index: int = -1
	var is_occupied: bool = false

var _load_slot_markers: Array[_LoadSlotMarker] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_stars()
		queue_redraw()
		return
	Playback.stopped.connect(_on_playback_stopped)
	Playback.started.connect(_on_playback_started)
	Playback.tick_advanced.connect(_on_tick_advanced)

func setup(tray: Tray) -> void:
	_clear_slot_markers()
	_rebuild_stars()
	queue_redraw()
	
	for mark in _load_slot_markers:
		on_slot_changed(mark.tick, mark.ring_index, mark.is_occupied, false)

	_load_slot_markers = []

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

func set_sequencer(sequencer: DeskLayer) -> void:
	_sequencer = sequencer

func get_cell_position(tick: int, ring_index: int) -> Vector2:
	return to_global(_cell_pos(tick, ring_index))

func clear_keys() -> void:
	for child: Node in _keys_container.get_children():
		child.queue_free()

func on_slot_changed(tick: int, ring_index: int, is_occupied: bool, from_load: bool) -> void:
	if (from_load):
		var marker = _LoadSlotMarker.new()
		marker.tick = tick
		marker.ring_index = ring_index
		marker.is_occupied = is_occupied
		_load_slot_markers.append(marker)
		return
	var key: int = _cell_key(tick, ring_index)
	if is_occupied:
		if _slot_markers.has(key) or slot_texture == null:
			return
		var pos: Vector2 = _cell_pos(tick, ring_index)
		var marker := Sprite2D.new()
		marker.texture = slot_texture
		marker.scale = Vector2.ZERO
		marker.position = pos
		_slot_markers_container.add_child(marker)
		_slot_markers[key] = marker
		var t := marker.create_tween()
		t.tween_property(marker, "scale", Vector2(slot_marker_scale, slot_marker_scale), slot_marker_enter_duration) \
			.set_ease(Tween.EASE_OUT).set_trans(slot_marker_enter_trans)
		_add_chain_point(key, pos)
	else:
		if _slot_markers.has(key):
			var marker := _slot_markers[key] as Sprite2D
			_slot_markers.erase(key)
			_remove_chain_point(key)
			var t := marker.create_tween()
			t.tween_property(marker, "scale", Vector2.ZERO, slot_marker_enter_duration) \
				.set_ease(Tween.EASE_IN).set_trans(slot_marker_enter_trans)
			t.tween_callback(marker.queue_free)

func _add_chain_point(key: int, pos: Vector2) -> void:
	# Find nearest endpoint across all constellations.
	var best_ci: int = -1
	var best_end: int = -1  # 0 = first, 1 = last
	var best_dist: float = INF
	for ci: int in range(_constellations.size()):
		var positions: Array = (_constellations[ci] as Dictionary)["positions"] as Array
		if positions.is_empty():
			continue
		var d_last: float = pos.distance_to(positions[-1] as Vector2)
		if d_last < best_dist:
			best_dist = d_last
			best_ci = ci
			best_end = 1
		if positions.size() > 1:
			var d_first: float = pos.distance_to(positions[0] as Vector2)
			if d_first < best_dist:
				best_dist = d_first
				best_ci = ci
				best_end = 0

	if best_ci == -1 or (max_constellation_distance > 0.0 and best_dist > max_constellation_distance):
		_constellations.append({"keys": [key], "positions": [pos], "segments": []})
		return

	var c: Dictionary = _constellations[best_ci]
	var keys: Array = c["keys"] as Array
	var positions: Array = c["positions"] as Array
	var segments: Array = c["segments"] as Array

	if best_end == 1:
		var dots: Array = _build_segment_dots(positions[-1] as Vector2, pos)
		positions.append(pos)
		keys.append(key)
		segments.append(dots)
		_animate_segment_in(dots)
	else:
		var dots: Array = _build_segment_dots(pos, positions[0] as Vector2)
		positions.insert(0, pos)
		keys.insert(0, key)
		segments.insert(0, dots)
		_animate_segment_in(dots)

func _remove_chain_point(key: int) -> void:
	for ci: int in range(_constellations.size()):
		var c: Dictionary = _constellations[ci]
		var keys: Array = c["keys"] as Array
		var idx: int = keys.find(key)
		if idx == -1:
			continue
		var positions: Array = c["positions"] as Array
		var segments: Array = c["segments"] as Array

		if positions.size() == 1:
			_constellations.remove_at(ci)
			return

		if idx == 0:
			_animate_segment_out(segments[0] as Array)
			segments.remove_at(0)
			keys.remove_at(0)
			positions.remove_at(0)
		elif idx == positions.size() - 1:
			_animate_segment_out(segments[-1] as Array)
			segments.remove_at(segments.size() - 1)
			keys.remove_at(keys.size() - 1)
			positions.remove_at(positions.size() - 1)
		else:
			_animate_segment_out(segments[idx - 1] as Array)
			_animate_segment_out(segments[idx] as Array)
			segments.remove_at(idx)
			segments.remove_at(idx - 1)
			keys.remove_at(idx)
			positions.remove_at(idx)
			var new_dots: Array = _build_segment_dots(positions[idx - 1] as Vector2, positions[idx] as Vector2)
			segments.insert(idx - 1, new_dots)
			_animate_segment_in(new_dots)

		if (c["positions"] as Array).is_empty():
			_constellations.remove_at(ci)
		return

func _build_segment_dots(a: Vector2, b: Vector2) -> Array:
	var dots: Array = []
	if star_textures.is_empty():
		return dots
	var seg_len: float = a.distance_to(b)
	if seg_len < 0.001 or (max_constellation_distance > 0.0 and seg_len > max_constellation_distance):
		return dots
	var dir: Vector2 = (b - a) / seg_len
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var walked: float = 0.0
	while true:
		walked += line_star_spacing * randf_range(1.0 - line_spacing_jitter, 1.0 + line_spacing_jitter)
		if walked >= seg_len:
			break
		var dot := Sprite2D.new()
		dot.texture = star_textures[randi() % star_textures.size()]
		var target_scale: float = randf_range(line_star_scale_min, line_star_scale_max)
		dot.scale = Vector2.ZERO
		dot.rotation = randf_range(0.0, TAU)
		dot.position = a + dir * walked + perp * randf_range(-line_position_jitter, line_position_jitter)
		dot.modulate = line_star_color
		dot.set_meta("target_scale", target_scale)
		_lines_container.add_child(dot)
		dots.append(dot)
	return dots

func _animate_segment_in(dots: Array) -> void:
	for i: int in range(dots.size()):
		var dot := dots[i] as Node2D
		var target: float = dot.get_meta("target_scale")
		var tween := dot.create_tween()
		tween.tween_interval(i * line_enter_step_delay)
		tween.tween_property(dot, "scale", Vector2(target, target), line_enter_duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _animate_segment_out(dots: Array) -> void:
	var n: int = dots.size()
	for i: int in range(n):
		var dot := dots[n - 1 - i] as Node2D
		var tween := dot.create_tween()
		tween.tween_interval(i * line_enter_step_delay)
		tween.tween_property(dot, "scale", Vector2.ZERO, line_enter_duration * 0.6) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(dot.queue_free)

func set_ghost_marker(tick: int, ring_index: int) -> void:
	var key: int = _cell_key(tick, ring_index)
	if _ghost_key == key:
		return
	_erase_ghost_marker()
	_ghost_key = key
	if slot_texture == null:
		return
	_ghost_marker = Sprite2D.new()
	_ghost_marker.texture = slot_texture
	_ghost_marker.scale = Vector2(ghost_marker_scale_min, ghost_marker_scale_min)
	_ghost_marker.position = _cell_pos(tick, ring_index)
	_ghost_marker.modulate.a = ghost_marker_opacity
	_slot_markers_container.add_child(_ghost_marker)
	_ghost_tween = _ghost_marker.create_tween().set_loops()
	_ghost_tween.tween_property(_ghost_marker, "scale",
		Vector2(ghost_marker_scale_max, ghost_marker_scale_max), ghost_marker_pulse_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_ghost_tween.tween_property(_ghost_marker, "scale",
		Vector2(ghost_marker_scale_min, ghost_marker_scale_min), ghost_marker_pulse_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func clear_ghost_marker() -> void:
	_ghost_key = -1
	_erase_ghost_marker()

func _erase_ghost_marker() -> void:
	if _ghost_tween != null and _ghost_tween.is_running():
		_ghost_tween.kill()
		_ghost_tween = null
	if _ghost_marker != null:
		var dying := _ghost_marker
		_ghost_marker = null
		var t := dying.create_tween()
		t.tween_property(dying, "scale", Vector2.ZERO, slot_marker_enter_duration) \
			.set_ease(Tween.EASE_IN).set_trans(slot_marker_enter_trans)
		t.tween_callback(dying.queue_free)

func _clear_slot_markers() -> void:
	for marker in _slot_markers.values():
		(marker as Node).queue_free()
	_slot_markers.clear()
	_clear_chain()

func _clear_chain() -> void:
	if _lines_container != null:
		for c: Dictionary in _constellations:
			for seg: Variant in (c["segments"] as Array):
				_animate_segment_out(seg as Array)
	_constellations.clear()

func _get_key_star_material() -> ShaderMaterial:
	if key_star_shader == null:
		return null
	if _key_star_material == null:
		_key_star_material = ShaderMaterial.new()
		_key_star_material.shader = key_star_shader
	return _key_star_material

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
			ks.setup(orb_type, _get_key_star_material())

## Stores the current level solution for playback validation. Does not display any hints.
func set_solution(solution: Array[LevelManager.SolutionData]) -> void:
	_solution = solution
	_hit_positions.clear()
	_completion_signaled = false
	var unique_keys: Dictionary = {}
	for tick: int in range(solution.size()):
		for entry: LevelManager.SlotData in solution[tick].rings:
			unique_keys[_cell_key(tick, entry.ring)] = true
	_solution_position_count = unique_keys.size()

func receive_orb(orb_id: Orb.OrbType, texture: Texture2D, tick: int, ring_index: int, measure_duration: float) -> void:
	var key: int = _cell_key(tick, ring_index)
	var correct: bool = _is_solution_hit(tick, ring_index, orb_id)
	var arrival: float = CORRECT_ARRIVAL_SCALE if correct else KEY_STAR_ARRIVAL_SCALE

	if _dots.has(key):
		# Already placed — jump back to arrival scale and restart decay.
		var dot := _dots[key] as Sprite2D
		dot.scale = Vector2(arrival, arrival)
		if _dot_tweens.has(key):
			(_dot_tweens[key] as Tween).kill()
		_dot_tweens[key] = _start_key_star_decay(dot, measure_duration)
	else:
		# First detection — create the persistent key star.
		var dot := Sprite2D.new()
		if correct:
			dot.texture = texture
			dot.material = _get_key_star_material()
		else:
			if not star_textures.is_empty():
				dot.texture = star_textures[randi() % star_textures.size()]
		dot.rotation = randf_range(0.0, TAU)
		dot.scale = Vector2(arrival, arrival)
		dot.position = _cell_pos(tick, ring_index)
		_dots_container.add_child(dot)
		_dots[key] = dot
		_dot_tweens[key] = _start_key_star_decay(dot, measure_duration)

	if correct and not _hit_positions.has(key):
		_hit_positions[key] = true
		if _hit_positions.size() >= _solution_position_count and _solution_position_count > 0:
			_pending_completion = true
			if not _completion_signaled:
				_completion_signaled = true
				completion_pending.emit()

func _start_key_star_decay(dot: Sprite2D, duration: float) -> Tween:
	var tween := dot.create_tween()
	tween.tween_property(dot, "scale", Vector2(KEY_STAR_MIN_SCALE, KEY_STAR_MIN_SCALE), duration) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	return tween

func _on_tick_advanced(tick: int) -> void:
	if tick == 0:
		if _pending_completion:
			_pending_completion = false
			constellation_completed.emit()
		_hit_positions.clear()

func _on_playback_started() -> void:
	_playing = true

func _on_playback_stopped() -> void:
	_pending_completion = false
	_completion_signaled = false
	_clear_dots()
	_playing = false
	_playhead.modulate.a = 1.0
	_update_playhead(0.0)

func _clear_dots() -> void:
	for dot in _dots.values():
		(dot as Node).queue_free()
	_dots.clear()
	_dot_tweens.clear()

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

func _is_solution_hit(tick: int, ring_index: int, orb_id: Orb.OrbType) -> bool:
	if tick >= _solution.size():
		return false
	for entry: LevelManager.SlotData in (_solution[tick].rings as Array):
		if entry.ring == ring_index and entry.orb_type == orb_id:
			return true
	return false

## Returns solution positions as normalized Vector2 values in [-1, 1] space.
func get_constellation_points(solution: Array[LevelManager.SolutionData]) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for tick: int in range(solution.size()):
		for entry: LevelManager.SlotData in solution[tick].rings:
			var angle_rad: float = _tick_angle_rad(float(tick))
			var radius: float = _note_radius(entry.ring)
			positions.append(Vector2(cos(angle_rad), sin(angle_rad)) * radius)

	if positions.is_empty():
		return positions

	var centroid := Vector2.ZERO
	for p: Vector2 in positions:
		centroid += p
	centroid /= float(positions.size())

	var max_dist: float = 0.001
	for p: Vector2 in positions:
		max_dist = maxf(max_dist, (p - centroid).length())

	# Scale by geometric mean of the solution's own extent and the full-grid extent.
	# This keeps tight constellations bunched while large ones still fill the display.
	var norm_scale: float = sqrt(max_dist * _grid_reference_scale())

	var result: Array[Vector2] = []
	for p: Vector2 in positions:
		result.append((p - centroid) / norm_scale)
	return result

func _on_fan_geometry_changed() -> void:
	if not is_node_ready():
		return
	_rebuild_stars()
	for key: int in _slot_markers:
		(_slot_markers[key] as Sprite2D).position = _cell_pos(key / 100, key % 100)
	queue_redraw()

func _grid_reference_scale() -> float:
	var grid_centroid := Vector2.ZERO
	for tick: int in range(TICKS):
		for ring: int in range(RING_COUNT):
			var angle_rad: float = _tick_angle_rad(float(tick))
			var radius: float = _note_radius(ring)
			grid_centroid += Vector2(cos(angle_rad), sin(angle_rad)) * radius
	grid_centroid /= float(TICKS * RING_COUNT)
	var ref: float = 0.001
	for tick: int in range(TICKS):
		for ring: int in range(RING_COUNT):
			var angle_rad: float = _tick_angle_rad(float(tick))
			var radius: float = _note_radius(ring)
			ref = maxf(ref, (Vector2(cos(angle_rad), sin(angle_rad)) * radius - grid_centroid).length())
	return ref
