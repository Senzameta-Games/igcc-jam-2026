extends Node2D

const ORB_TRAIL_SCENE: PackedScene = preload("res://core/entities/orbs/orb_trail.tscn")

# Pending detections collected per physics frame in ring priority order
var _pending: Array[Dictionary] = []
var _process_queued: bool = false

@onready var _sequence: Sequence = $Sequence
@onready var _button: Button = $StartStop/Button
@onready var _rings: Node2D = $Rings
@onready var _tray: Tray = $Tray
@onready var _detectors: Node2D = $Detectors
@onready var _feedback: Node2D = $DetectionFeedback

func inject_hand(hand: Hand) -> void:
	var controller := _button as PlaybackButton
	if controller == null:
		push_warning("Sequencer: PlaybackController not found on StartStop/Button")
		return
	controller.connect_hand(hand)
	_tray.connect_hand(hand)
	for child: Node in _rings.get_children():
		var ring := child as Ring
		if ring == null:
			continue
		ring.connect_hand_to_slot(hand)
	for child: Node in _detectors.get_children():
		var detector := child as Detector
		if detector == null:
			continue
		detector.orb_passed.connect(_on_orb_passed)

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


func _on_reset_pressed():
	Playback.stop()
	get_tree().reload_current_scene()
