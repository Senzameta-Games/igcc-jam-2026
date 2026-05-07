class_name PianoRoll
extends Control

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

@onready var _dots_container: Control = $Dots
@onready var _playhead: Control = $Playhead

const TICKS: int = 16
const ARRIVAL_SCALE: float = 0.5

var notes: Array[Orb.OrbType] = []

var _dots: Dictionary = {}

var _playhead_target_tick: float = 0.0
var _playhead_current_tick: float = 0.0

func _ready() -> void:
	Playback.tick_advanced.connect(_on_tick_advanced)
	Playback.stopped.connect(_on_playback_stopped)

func setup(tray: Tray) -> void:
	notes = tray.get_unique_orbs()
	_playhead_current_tick = 0.0
	_playhead_target_tick = 0.0
	_update_playhead(_playhead_current_tick)

func _process(delta: float) -> void:
	if _playhead == null:
		return
	_playhead_current_tick = lerpf(_playhead_current_tick, _playhead_target_tick, playhead_lerp_speed * delta)
	_update_playhead(_playhead_current_tick)

func get_cell_position(tick: int, orb_id: Orb.OrbType) -> Vector2:
	var note_row: int = notes.find(orb_id)
	if note_row == -1:
		return global_position
	return global_position + _cell_pos(tick, note_row)

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

func _update_playhead(tick: float) -> void:
	if _playhead == null:
		return
	# Place playhead at the midpoint radius along the radial line for this tick
	var angle_rad: float = _tick_angle_rad(tick)
	var mid_radius: float = (fan_radius_inner + fan_radius_outer) * 0.5
	_playhead.position = fan_origin + Vector2(cos(angle_rad), sin(angle_rad)) * mid_radius

func _cell_pos(tick: int, note_row: int) -> Vector2:
	var angle_rad: float = _tick_angle_rad(float(tick))
	var radius: float = _note_radius(note_row)
	return fan_origin + Vector2(cos(angle_rad), sin(angle_rad)) * radius

func _tick_angle_rad(tick: float) -> float:
	var t: float = tick / float(TICKS - 1)  # 0.0 to 1.0
	var angle_deg: float = -fan_angle_span * 0.5 + t * fan_angle_span
	return deg_to_rad(angle_deg - 90.0)  # offset so 0deg points up

func _note_radius(note_row: int) -> float:
	var t: float = float(note_row) / float(max(notes.size() - 1, 1))
	return lerpf(fan_radius_outer, fan_radius_inner, t)

func _cell_key(tick: int, note_row: int) -> int:
	return tick * 100 + note_row
