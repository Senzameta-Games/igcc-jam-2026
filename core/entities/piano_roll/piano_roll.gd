class_name PianoRoll
extends Node2D

## Piano roll display. 16 columns (ticks) x N rows (unique notes, high to low).
## Laid out as a radial fan — rows are concentric arcs, columns are radial lines.
## Replaces Sequence. Receives orbs from Sequencer via receive_orb().
## Playhead driven by Playback.tick_advanced.

## Radius of the innermost arc (lowest note row).
@export var fan_radius_inner: float = 300.0
## Radius of the outermost arc (highest note row).
@export var fan_radius_outer: float = 600.0
## Total degrees the 16 ticks span across the fan.
@export var fan_angle_span: float = 120.0
## Vanishing point of the fan in local space. Move down to push the arc higher.
@export var fan_origin: Vector2 = Vector2(512.0, 800.0)
@export var playhead_lerp_speed: float = 18.0

## Number of rows to preview in editor (since notes are populated at runtime).
@export var debug_row_count: int = 4

@onready var _dots_container: Node2D = $Dots
@onready var _playhead: Node2D = $Playhead

const TICKS: int = 16
const ARRIVAL_SCALE: float = 0.5

const _DEBUG_ARC_COLOR: Color = Color(1.0, 1.0, 1.0, 0.1)
const _DEBUG_RADIAL_COLOR: Color = Color(1.0, 1.0, 1.0, 0.1)
const _DEBUG_ORIGIN_COLOR: Color = Color(1.0, 1.0, 0.0, 0.1)
const _DEBUG_ARC_SEGMENTS: int = 48

## Ordered high to low — index 0 is highest pitch, index N-1 is lowest.
var notes: Array[Orb.OrbType] = []

## Sparse map of placed dots: key = tick * 100 + note_row, value = Sprite2D node.
var _dots: Dictionary = {}

var _playhead_target_tick: float = 0.0
var _playhead_current_tick: float = 0.0

func _ready() -> void:
	Playback.tick_advanced.connect(_on_tick_advanced)
	Playback.stopped.connect(_on_playback_stopped)

## Called by Sequencer after tray is available. Must be called before first use.
func setup(tray: Tray) -> void:
	notes = tray.get_unique_orbs()
	_playhead_current_tick = 0.0
	_playhead_target_tick = 0.0
	_update_playhead(_playhead_current_tick)
	queue_redraw()

func _process(delta: float) -> void:
	if _playhead == null:
		return
	_playhead_current_tick = lerpf(_playhead_current_tick, _playhead_target_tick, playhead_lerp_speed * delta)
	_update_playhead(_playhead_current_tick)

## Returns the global position of the center of the cell at (tick, orb_id).
func get_cell_position(tick: int, orb_id: Orb.OrbType) -> Vector2:
	var note_row: int = notes.find(orb_id)
	if note_row == -1:
		return global_position
	return to_global(_cell_pos(tick, note_row))

## Places a dot at (tick, orb_id). Called when an orb trail arrives.
func receive_orb(orb_id: Orb.OrbType, texture: Texture2D, tick: int, measure_duration: float) -> void:
	var note_row: int = notes.find(orb_id)
	if note_row == -1:
		return
	var key: int = _cell_key(tick, note_row)
	if _dots.has(key):
		(_dots[key] as Node).queue_free()
	var dot := Sprite2D.new()
	dot.texture = texture
	dot.scale = Vector2(ARRIVAL_SCALE, ARRIVAL_SCALE)
	dot.position = _cell_pos(tick, note_row)
	_dots_container.add_child(dot)
	_dots[key] = dot
	var tween := dot.create_tween()
	tween.tween_property(dot, "scale", Vector2.ZERO, measure_duration) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void:
		if _dots.get(key) == dot:
			_dots.erase(key)
		dot.queue_free()
	)

func _on_tick_advanced(tick_index: int) -> void:
	_playhead_target_tick = float(tick_index)

func _on_playback_stopped() -> void:
	_clear_dots()
	_playhead_current_tick = 0.0
	_playhead_target_tick = 0.0
	_update_playhead(0.0)

func _clear_dots() -> void:
	for dot in _dots.values():
		(dot as Node).queue_free()
	_dots.clear()

## Moves the playhead to the radial line at a continuous tick position.
func _update_playhead(tick: float) -> void:
	if _playhead == null:
		return
	var angle_rad: float = _tick_angle_rad(tick)
	var mid_radius: float = (fan_radius_inner + fan_radius_outer) * 0.5
	_playhead.position = fan_origin + Vector2(cos(angle_rad), sin(angle_rad)) * mid_radius
	_playhead.rotation = angle_rad + PI * 0.5

## Returns local position for a cell in fan/polar space.
func _cell_pos(tick: int, note_row: int) -> Vector2:
	var angle_rad: float = _tick_angle_rad(float(tick))
	var radius: float = _note_radius(note_row)
	return fan_origin + Vector2(cos(angle_rad), sin(angle_rad)) * radius

## Converts a tick index (continuous) to a radial angle in radians.
## Tick 0 = left edge, tick 15 = right edge. Arc points upward.
func _tick_angle_rad(tick: float) -> float:
	var t: float = tick / float(TICKS - 1)
	var angle_deg: float = -fan_angle_span * 0.5 + t * fan_angle_span
	return deg_to_rad(angle_deg - 90.0)

## Returns the radius for a given note row.
## Row 0 (highest pitch) = outermost. Row N-1 (lowest pitch) = innermost.
func _note_radius(note_row: int) -> float:
	var t: float = float(note_row) / float(max(notes.size() - 1, 1))
	return lerpf(fan_radius_outer, fan_radius_inner, t)

func _cell_key(tick: int, note_row: int) -> int:
	return tick * 100 + note_row

# --- Debug draw ---

func _draw() -> void:
	var row_count: int = notes.size() if notes.size() > 0 else debug_row_count

	# Concentric arcs — one per note row
	for row: int in range(row_count):
		var radius: float = lerpf(fan_radius_outer, fan_radius_inner,
			float(row) / float(max(row_count - 1, 1)))
		_draw_arc_segment(radius, _DEBUG_ARC_COLOR)

	# Radial lines — one per tick
	for tick: int in range(TICKS):
		var angle_rad: float = _tick_angle_rad(float(tick))
		var dir: Vector2 = Vector2(cos(angle_rad), sin(angle_rad))
		var from: Vector2 = fan_origin + dir * fan_radius_inner
		var to: Vector2 = fan_origin + dir * fan_radius_outer
		draw_line(from, to, _DEBUG_RADIAL_COLOR, 1.0)

	# Fan origin marker
	draw_circle(fan_origin, 6.0, _DEBUG_ORIGIN_COLOR)

func _draw_arc_segment(radius: float, color: Color) -> void:
	var points: PackedVector2Array = []
	for i: int in range(_DEBUG_ARC_SEGMENTS + 1):
		var t: float = float(i) / float(_DEBUG_ARC_SEGMENTS)
		var angle_deg: float = -fan_angle_span * 0.5 + t * fan_angle_span
		var angle_rad: float = deg_to_rad(angle_deg - 90.0)
		points.append(fan_origin + Vector2(cos(angle_rad), sin(angle_rad)) * radius)
	for i: int in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, 1.5)
