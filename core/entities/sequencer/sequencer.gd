extends Node2D

## Sequencer owns BPM and all ring rotation state.
## Rings are passive. They receive rot_t each frame and apply it.

enum RotationModel { QUANTIZED, CUSTOM }

const RING_COUNT: int = 3
const BEATS_PER_MEASURE: float = 4.0

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

func _on_orb_passed(orb_id: StringName, texture: Texture2D, from_position: Vector2, ring_idx: int) -> void:
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
		var captured_id: StringName = entry.orb_id
		var captured_texture: Texture2D = entry.texture
		trail.arrived.connect(func() -> void:
			_sequence.receive_orb(captured_id, captured_texture)
		)
	_pending.clear()

func _on_reset_pressed() -> void:
	Playback.stop()
	get_tree().reload_current_scene()
