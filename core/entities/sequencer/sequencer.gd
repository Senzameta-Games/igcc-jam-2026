extends Node2D

## Sequencer owns BPM and all ring rotation state.
## Rings are passive. They receive rot_t each frame and apply it.

enum RotationModel { QUANTIZED, CUSTOM }

const RING_COUNT: int = 3
const BEATS_PER_MEASURE: float = 4.0
const MAX_BPM: float = 90.0

@export var bpm: float = 120.0
@export var rotation_model: RotationModel = RotationModel.QUANTIZED
## Only used when rotation_model == CUSTOM.
## [1.0, 1.0, 1.0] is the same as QUANTIZED.
@export var custom_multipliers: Array[float] = [1.0, 1.0, 1.0]

@onready var _sequence: Sequence = $Sequence
@onready var _button: Button = $StartStop/Button
@onready var _rings_container: Node2D = $Rings
@onready var _tray: Tray = $Tray
@onready var _detectors: Node2D = $Detectors
@onready var _feedback: Node2D = $DetectionFeedback
@onready var _tools: Control = $Tools
@onready var _bpm_field: TextEdit = $Tools/BPM
@onready var _ring0_interval: OptionButton = $Tools/Ring0Interval
@onready var _ring1_interval: OptionButton = $Tools/Ring1Interval
@onready var _ring2_interval: OptionButton = $Tools/Ring2Interval
@onready var _rotation_model_select: OptionButton = $Tools/RotationModel
@onready var _custom_multipliers_field: TextEdit = $Tools/CustomMultField

const ORB_TRAIL_SCENE: PackedScene = preload("res://core/entities/orbs/orb_trail.tscn")

var _rings: Array[Ring] = []
var _rotations: Array[float] = [0.0, 0.0, 0.0]
var _resetting: bool = false

# Pending crossings per physics frame, sorted by ring_index before dispatch
var _pending: Array[Dictionary] = []
var _process_queued: bool = false

func _ready() -> void:
	Playback.started.connect(_on_playback_started)
	Playback.stopped.connect(_on_playback_stopped)
	for child: Node in _rings_container.get_children():
		var ring := child as Ring
		if ring == null:
			continue
		_rings.append(ring)
	# Sort by ring_index so _rings[i] matches _rotations[i]
	_rings.sort_custom(func(a: Ring, b: Ring) -> bool:
		return a.ring_index < b.ring_index
	)
	_setup_dev_tools()

func inject_hand(hand: Hand) -> void:
	var controller := _button as PlaybackButton
	if controller == null:
		return
	controller.connect_hand(hand)
	_tray.connect_hand(hand)
	for ring: Ring in _rings:
		ring.connect_hand_to_slot(hand)
	for child: Node in _detectors.get_children():
		var detector := child as Detector
		if detector == null:
			continue
		detector.orb_passed.connect(_on_orb_passed)

func _physics_process(delta: float) -> void:
	if not Playback.is_playing:
		return
	var base_rate: float = bpm / BEATS_PER_MEASURE / 60.0
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

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("hide_tools"):
		_tools.visible = !_tools.visible

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

func _on_playback_stopped() -> void:
	_resetting = true

func _on_orb_passed(orb_id: Orb.OrbType, texture: Texture2D, from_position: Vector2, ring_idx: int) -> void:
	_pending.append({
		"orb_id": orb_id,
		"texture": texture,
		"from": from_position,
		"ring_idx": ring_idx
	})
	if not _process_queued:
		_process_queued = true
		call_deferred("_process_pending")

func _process_pending() -> void:
	_process_queued = false
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.ring_idx < b.ring_idx
	)
	for entry: Dictionary in _pending:
		var target: Vector2 = _sequence.get_next_slot_position()
		var trail := ORB_TRAIL_SCENE.instantiate() as OrbTrail
		_feedback.add_child(trail)
		trail.setup(entry.texture, entry.from, target)
		var captured_id: Orb.OrbType = entry.orb_id
		var captured_texture: Texture2D = entry.texture
		trail.arrived.connect(func() -> void:
			_sequence.receive_orb(captured_id, captured_texture)
		)
	_pending.clear()

func _on_reset_pressed() -> void:
	Playback.stop()
	get_tree().reload_current_scene()




# --- Dev Tools ---
 
func _setup_dev_tools() -> void:
	# BPM field. Give current value, commit on focus_exited
	_bpm_field.text = str(bpm)
 
	# Interval type dropdowns — one per ring
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
 
	# Rotation model dropdown
	_rotation_model_select.add_item("QUANTIZED", RotationModel.QUANTIZED)
	_rotation_model_select.add_item("CUSTOM", RotationModel.CUSTOM)
	_rotation_model_select.select(int(rotation_model))
 
	# Custom multipliers field — hidden unless CUSTOM is active
	_custom_multipliers_field.text = _multipliers_to_string(custom_multipliers)
	_custom_multipliers_field.visible = rotation_model == RotationModel.CUSTOM
 
func export() -> void:
	var export_arr = []
	var ring_orbs = []
	for ring in _rings:
		var orbs = ring.get_orbs()
		var ticks_per_slot = 16 / ring.get_slot_count()
		var grid = []
		grid.resize(16)
		grid.fill(null)
		for slot_i in range(ring.get_slot_count()):
			if orbs[slot_i] != null:
				grid[slot_i * ticks_per_slot] = orbs[slot_i]
		ring_orbs.append(grid)
	for i in 16:
		var curr_pos = []
		for ring_grid in ring_orbs:
			if ring_grid[i] != null:
				curr_pos.append(ring_grid[i].orb_id)
		export_arr.append(curr_pos)
	print(export_arr)

func _on_export_pressed():
	export()
	
func _on_bpm_committed() -> void:
	var value: float = _bpm_field.text.to_float()
	if value <= 0.0:
		# Reject — restore current value
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
 
func _on_custom_mult_committed() -> void:
	# Expects comma-separated floats matching ring count, e.g. "1.0, 2.0, 0.5"
	var parts: Array[String] = []
	for part: String in _custom_multipliers_field.text.split(","):
		parts.append(part.strip_edges())
	if parts.size() != _rings.size():
		# Reject — restore
		_custom_multipliers_field.text = _multipliers_to_string(custom_multipliers)
		return
	var parsed: Array[float] = []
	for part: String in parts:
		var val: float = part.to_float()
		if val <= 0.0:
			# Reject — restore
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
