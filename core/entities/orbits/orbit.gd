class_name Orbit
extends Node2D

signal note_crossed(note_id: StringName, texture: Texture2D)

const PLAYHEAD_T: float = 0.0

@export var radius: float = 400.0:
	set(value):
		radius = value
		_rebuild_curve()

@export_group("Orbit Visual")
@export var line_color: Color:
	set(value):
		line_color = value
		queue_redraw()
		
@export var line_width: float = 8.0:
	set(value):
		line_width = value
		queue_redraw()
		
@export var playhead_color: Color:
	set(value):
		playhead_color = value
		queue_redraw()
		
@export var playhead_width: float = 8.0:
	set(value):
		playhead_width = value
		queue_redraw()
		
@export_group("Sequencing")
@export var rpm: float = 32.0
@export var slot_count: int = 8

@onready var _path: Path2D = $Path
@onready var _notes: Node2D = $Notes

var _rot_t: float = 0.0
var _selected_note: Note = null

func _ready() -> void:
	_rebuild_curve()
	queue_redraw()
	Playback.started.connect(_on_playback_started)
	Playback.stopped.connect(_on_playback_stopped)
	for child in _notes.get_children():
		var note = child as Note
		if note == null:
			continue
		note.initialize(self)
		note.selected.connect(_on_note_selected)
	_move_notes() # this gets all the notes in their initial spots on load

func _physics_process(delta: float) -> void:
	if not Playback.is_playing:
		return
	var prev_t = _rot_t
	_rot_t = fmod(_rot_t + (rpm / 60.0) * delta, 1.0)
	_playhead_check(prev_t, _rot_t)

func _process(delta: float) -> void:
	if not Playback.is_playing:
		return
	_move_notes()

func _input(event: InputEvent) -> void:
	if Playback.is_playing or _selected_note == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var slot: int = _get_slot_at(get_local_mouse_position())
			if slot >= 0:
				_selected_note.move_to_slot(slot)
				_selected_note = null
				_move_notes()
				queue_redraw()
				get_viewport().set_input_as_handled()

func _draw() -> void:
	if _path.curve == null:
		return
	var points: PackedVector2Array = _path.curve.tessellate(10, 1.0)
	draw_polyline(points, line_color, line_width, true)
	var playhead_pos := _path.curve.sample_baked(0.0)
	draw_arc(playhead_pos, 24.0, 0.0, TAU, 32, playhead_color, playhead_width, true)
	if _selected_note != null:
		_draw_slot_hints()

func _draw_slot_hints() -> void:
	var baked_length: float = _path.curve.get_baked_length()
	var occupied_slots: Array[int] = []
	for child in _notes.get_children():
		var note: Note = child as Note
		if note == null or note == _selected_note:
			continue
		occupied_slots.append(note.slot_index)
	for i in range(slot_count):
		if occupied_slots.has(i):
			continue
		var slot_t: float = float(i) / float(slot_count)
		var pos: Vector2 = _path.curve.sample_baked(slot_t * baked_length)
		draw_arc(pos, 16.0, 0.0, TAU, 32, Color.GRAY, 4.0, true)

func _get_slot_at(local_pos: Vector2) -> int:
	var baked_length: float = _path.curve.get_baked_length()
	for i in range(slot_count):
		var slot_t: float = float(i) / float(slot_count)
		var pos: Vector2 = _path.curve.sample_baked(slot_t * baked_length)
		if local_pos.distance_to(pos) <= 32.0:
			return i
	return -1

func _on_note_selected(note: Note) -> void:
	_selected_note = note
	queue_redraw()

func _rebuild_curve() -> void:
	if _path == null:
		return
	var h: float = radius * 0.5522867
	var curve: Curve2D = Curve2D.new()
	curve.add_point(Vector2(radius, 0.0),  Vector2(0.0, -h), Vector2(0.0, h))
	curve.add_point(Vector2(0.0, radius),  Vector2(h, 0.0),  Vector2(-h, 0.0))
	curve.add_point(Vector2(-radius, 0.0), Vector2(0.0, h),  Vector2(0.0, -h))
	curve.add_point(Vector2(0.0, -radius), Vector2(-h, 0.0), Vector2(h, 0.0))
	curve.add_point(Vector2(radius, 0.0),  Vector2(0.0, -h),  Vector2(0.0, h))
	_path.curve = curve
	queue_redraw()

func _playhead_check(prev_t: float, curr_t: float) -> void:
	for child in _notes.get_children():
		var note = child as Note
		if note == null:
			continue
		var prev_note_t = fmod(prev_t + note.slot_t, 1.0)
		var curr_note_t = fmod(curr_t + note.slot_t, 1.0)
		if _note_crossed(prev_note_t, curr_note_t):
			note_crossed.emit(note.note_id, note.texture)
			print(str(note.note_id) + " crossed playhead.")

func _note_crossed(prev_note_t: float, curr_note_t: float) -> bool:
	if curr_note_t < prev_note_t:
		curr_note_t += 1.0
	var threshold = PLAYHEAD_T
	if threshold < prev_note_t:
		threshold += 1.0
	return prev_note_t < threshold and threshold <= curr_note_t

func _on_playback_stopped() -> void:
	_rot_t = 0.0
	line_color = Color("#777777")
	_move_notes()

func _on_playback_started() -> void:
	line_color = Color.WHITE

func _move_notes() -> void:
	if _path.curve == null:
		return
	var baked_length = _path.curve.get_baked_length()
	for note in _notes.get_children():
		var n = note as Note
		if n == null:
			continue
		var note_t = fmod(_rot_t + n.slot_t, 1.0)
		n.position = _path.curve.sample_baked(note_t * baked_length)
