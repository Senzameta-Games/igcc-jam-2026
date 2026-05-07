class_name Sequencer
extends Node2D

## Sequencer owns BPM and all ring rotation state.
## Rings are passive. They receive rot_t each frame and apply it.
## Tray and PianoRoll live under Main.
## Detectors are owned by their respective Ring children.
## Main listens to note_triggered and owns the trail + piano roll flow.

signal note_triggered(orb_id: Orb.OrbType, texture: Texture2D, from_position: Vector2, tick: int)

enum RotationModel { QUANTIZED, CUSTOM }

const RING_COUNT: int = 3
const BEATS_PER_MEASURE: float = 4.0
const TICKS_PER_MEASURE: int = 16
const MAX_BPM: float = 90.0

@export var bpm: float = 120.0
@export var rotation_model: RotationModel = RotationModel.QUANTIZED
## Only used when rotation_model == CUSTOM.
## [1.0, 1.0, 1.0] is the same as QUANTIZED.
@export var custom_multipliers: Array[float] = [1.0, 1.0, 1.0]

@onready var _button: Button = $StartStop/Button
@onready var _rings_container: Node2D = $Rings

# Dev tools
@onready var _tools: Control = $Tools
@onready var _bpm_field: TextEdit = $Tools/BPM
@onready var _ring0_interval: OptionButton = $Tools/Ring0Interval
@onready var _ring1_interval: OptionButton = $Tools/Ring1Interval
@onready var _ring2_interval: OptionButton = $Tools/Ring2Interval
@onready var _rotation_model_select: OptionButton = $Tools/RotationModel
@onready var _custom_multipliers_field: TextEdit = $Tools/CustomMultField

var _rings: Array[Ring] = []
var _rotations: Array[float] = [0.0, 0.0, 0.0]
var _resetting: bool = false

# Tick clock — driven by absolute measure time, independent of ring multipliers
var _measure_t: float = 0.0
var _current_tick: int = 0
var _last_tick_threshold: int = 0

# Pending crossings per physics frame, sorted by ring_index before dispatch
var _pending: Array[Dictionary] = []
var _process_queued: bool = false

func _ready() -> void:
	await get_tree().process_frame
	Playback.started.connect(_on_playback_started)
	Playback.stopped.connect(_on_playback_stopped)
	for child: Node in _rings_container.get_children():
		var ring := child as Ring
		if ring == null:
			continue
		_rings.append(ring)
		ring.note_triggered.connect(_on_ring_note_triggered)
	_rings.sort_custom(func(a: Ring, b: Ring) -> bool:
		return a.ring_index < b.ring_index
	)
	_setup_dev_tools()

## Returns the current BPM measure duration in seconds. Used by Main for trail timing.
func get_measure_duration() -> float:
	return (60.0 / bpm) * BEATS_PER_MEASURE

func _physics_process(delta: float) -> void:
	if not Playback.is_playing:
		return
	var base_rate: float = bpm / BEATS_PER_MEASURE / 60.0

	# Tick clock driven by absolute measure time — independent of ring multipliers
	_measure_t = fmod(_measure_t + base_rate * delta, 1.0)
	var tick_threshold: int = int(_measure_t * TICKS_PER_MEASURE)
	if tick_threshold != _last_tick_threshold:
		_last_tick_threshold = tick_threshold
		_current_tick = tick_threshold
		Playback.tick_advanced.emit(_current_tick)

	# Rings advance at their own multiplied rates
	for i: int in range(_rings.size()):
		var multiplier: float = _get_multiplier(i)
		_rotations[i] = fmod(_rotations[i] + base_rate * multiplier * delta, 1.0)
		_rings[i].tick(_rotations[i])

func _process(delta: float) -> void:
	if not _resetting:
		return
	var all_done: bool = true
	for i: int in range(_rings.size()):
		var target: float = 0.0 if _rotations[i] <= 0.5 else 1.0
		_rotations[i] = lerpf(_rotations[i], target, Ring.RESET_SPEED * delta)
		_rings[i].apply_rotation(_rotations[i])
		var close_enough: bool = abs(_rotations[i] - target) < Ring.RESET_THRESHOLD
		var wrapped: bool = target == 1.0 and abs(_rotations[i] - 1.0) < Ring.RESET_THRESHOLD
		if not (close_enough or wrapped):
			all_done = false
		elif close_enough or wrapped:
			_rotations[i] = 0.0
			_rings[i].apply_rotation(0.0)
	if all_done:
		_resetting = false

func _get_multiplier(ring_index: int) -> float:
	match rotation_model:
		RotationModel.QUANTIZED:
			return 1.0
		RotationModel.CUSTOM:
			if ring_index < custom_multipliers.size():
				return custom_multipliers[ring_index]
			return 1.0
	return 1.0

func _on_playback_started() -> void:
	_resetting = false
	_measure_t = 0.0
	_current_tick = 0
	_last_tick_threshold = 0

func _on_playback_stopped() -> void:
	_resetting = true

func _on_ring_note_triggered(orb_id: Orb.OrbType, texture: Texture2D, from_position: Vector2, ring_index: int) -> void:
	_pending.append({
		"orb_id": orb_id,
		"texture": texture,
		"from": from_position,
		"ring_idx": ring_index,
		"tick": _current_tick
	})
	if not _process_queued:
		_process_queued = true
		call_deferred("_flush_pending")

## Sorts pending detections by ring_index and emits note_triggered for each.
## Deferred so multiple detections in one physics frame are batched.
func _flush_pending() -> void:
	_process_queued = false
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.ring_idx < b.ring_idx
	)
	for entry: Dictionary in _pending:
		note_triggered.emit(
			entry.orb_id as Orb.OrbType,
			entry.texture as Texture2D,
			entry.from as Vector2,
			entry.tick as int
		)
	_pending.clear()

func _on_reset_pressed() -> void:
	Playback.stop()
	get_tree().reload_current_scene()

func export() -> void:
	var export_arr: Array = []
	var ring_grids: Array = []
	for ring: Ring in _rings:
		var orbs: Array = ring.get_orbs()
		var ticks_per_slot: int = 16 / ring.get_slot_count()
		var grid: Array = []
		grid.resize(16)
		grid.fill(null)
		for slot_i: int in range(ring.get_slot_count()):
			if orbs[slot_i] != null:
				grid[slot_i * ticks_per_slot] = orbs[slot_i]
		ring_grids.append(grid)
	for i: int in range(16):
		var curr_pos: Array = []
		for ring_grid: Array in ring_grids:
			if ring_grid[i] != null:
				curr_pos.append((ring_grid[i] as Orb).orb_id)
		export_arr.append(curr_pos)
	print(export_arr)

func _on_export_pressed() -> void:
	export()

# --- Dev Tools ---

func _setup_dev_tools() -> void:
	_bpm_field.text = str(bpm)
	_bpm_field.focus_exited.connect(_on_bpm_committed)

	var interval_buttons: Array[OptionButton] = [
		_ring0_interval, _ring1_interval, _ring2_interval
	]
	for i: int in range(interval_buttons.size()):
		var btn := interval_buttons[i]
		btn.add_item("QUARTER", Ring.IntervalType.QUARTER)
		btn.add_item("EIGHTH", Ring.IntervalType.EIGHTH)
		btn.add_item("SIXTEENTH", Ring.IntervalType.SIXTEENTH)
		if i < _rings.size():
			btn.select(int(_rings[i].interval_type))
		var captured_i: int = i
		btn.item_selected.connect(func(idx: int) -> void:
			_on_interval_selected(captured_i, idx)
		)

	_rotation_model_select.add_item("QUANTIZED", RotationModel.QUANTIZED)
	_rotation_model_select.add_item("CUSTOM", RotationModel.CUSTOM)
	_rotation_model_select.select(int(rotation_model))
	_rotation_model_select.item_selected.connect(_on_rotation_model_selected)

	_custom_multipliers_field.text = _multipliers_to_string(custom_multipliers)
	_custom_multipliers_field.visible = rotation_model == RotationModel.CUSTOM
	_custom_multipliers_field.focus_exited.connect(_on_custom_multipliers_committed)

	var reset_btn := $Tools/Reset as Button
	var export_btn := $Tools/Export as Button
	var fill_btn := $Tools/FillSlots as Button
	reset_btn.pressed.connect(_on_reset_pressed)
	export_btn.pressed.connect(_on_export_pressed)
	fill_btn.pressed.connect(_on_fill_slots_pressed)

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("hide_tools"):
		_tools.visible = !_tools.visible

func _on_bpm_committed() -> void:
	var value: float = _bpm_field.text.to_float()
	if value <= 0.0:
		_bpm_field.text = str(bpm)
		return
	bpm = minf(value, MAX_BPM)
	_bpm_field.text = str(bpm)

func _on_interval_selected(ring_index: int, item_index: int) -> void:
	if ring_index >= _rings.size():
		return
	_rings[ring_index].interval_type = Ring.IntervalType.values()[item_index]

func _on_ring0_interval_selected(item_index: int) -> void:
	_on_interval_selected(0, item_index)

func _on_ring1_interval_selected(item_index: int) -> void:
	_on_interval_selected(1, item_index)

func _on_ring2_interval_selected(item_index: int) -> void:
	_on_interval_selected(2, item_index)

func _on_rotation_model_selected(item_index: int) -> void:
	rotation_model = RotationModel.values()[item_index]
	_custom_multipliers_field.visible = rotation_model == RotationModel.CUSTOM

func _on_fill_slots_pressed() -> void:
	for ring: Ring in _rings:
		for slot: Slot in ring.get_slots():
			if slot.is_occupied():
				continue
			var random_type: Orb.OrbType = Orb.OrbType.values()[randi() % Orb.OrbType.size()]
			var orb: Orb = OrbRegistry.spawn(random_type)
			if orb == null:
				continue
			slot.add_child(orb)
			slot.receive_orb(orb)

func _on_custom_multipliers_committed() -> void:
	var parts: Array[String] = []
	for part: String in _custom_multipliers_field.text.split(","):
		parts.append(part.strip_edges())
	if parts.size() != _rings.size():
		_custom_multipliers_field.text = _multipliers_to_string(custom_multipliers)
		return
	var parsed: Array[float] = []
	for part: String in parts:
		var val: float = part.to_float()
		if val <= 0.0:
			_custom_multipliers_field.text = _multipliers_to_string(custom_multipliers)
			return
		parsed.append(val)
	custom_multipliers = parsed
	_custom_multipliers_field.text = _multipliers_to_string(custom_multipliers)

func _multipliers_to_string(multipliers: Array[float]) -> String:
	var parts: PackedStringArray = []
	for m: float in multipliers:
		parts.append(str(m))
	return ", ".join(parts)
