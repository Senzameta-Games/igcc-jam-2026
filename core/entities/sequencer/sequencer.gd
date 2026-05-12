class_name Sequencer
extends Node2D

signal note_triggered(orb_id: Orb.OrbType, texture: Texture2D, from_position: Vector2, tick: int, orb: Orb)

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

@onready var _rings_container: Node2D = $Device/Rings
@onready var _ray_caster: RayCaster = $Device/RayCaster
@onready var _device: Node2D = $Device
@onready var _ring_spin_sfx: AudioStreamPlayer = $PassiveSound/RingRotate
@onready var _playback_button_sfx: AudioStreamPlayer = $Device/StartStop/ButtonPress


var _tray: Tray = null

var _rings: Array[Ring] = []
var _resetting: bool = false
var _frame_glow_tween: Tween = null

# Tick clock driven by absolute measure time, independent of ring multipliers
var _measure_t: float = 0.0
var _current_tick: int = 0
var _last_tick_threshold: int = 0
var _tick_has_fired: bool = false

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
	_rings.sort_custom(func(a: Ring, b: Ring) -> bool:
		return a.ring_index < b.ring_index
	)
	_ray_caster.note_triggered.connect(_on_ray_caster_note_triggered)

func get_measure_duration() -> float:
	return (60.0 / bpm) * BEATS_PER_MEASURE

func get_measure_t() -> float:
	return _measure_t

func get_rings() -> Array[Ring]:
	return _rings

func eject_orbs() -> void:
	for ring: Ring in _rings:
		ring.eject_all_orbs()
	if(_tray != null):
		_tray.refill_orbs()

func snapshot_rings() -> Array:
	var snap: Array = []
	for ring: Ring in _rings:
		var ring_snap: Array = []
		for slot: Slot in ring.get_slots():
			if slot.is_occupied():
				var orb: Orb = slot.get_orb()
				ring_snap.append({"type": int(orb.orb_id), "source": orb.source_level})
			else:
				ring_snap.append(null)
		snap.append(ring_snap)
	return snap

func restore_rings(snapshot: Array) -> void:
	for i: int in range(mini(snapshot.size(), _rings.size())):
		var ring: Ring = _rings[i]
		var ring_snap: Array = snapshot[i]
		var slots: Array[Slot] = ring.get_slots()
		for j: int in range(mini(ring_snap.size(), slots.size())):
			var entry: Variant = ring_snap[j]
			if entry == null:
				continue
			var orb_type: Orb.OrbType = (entry as Dictionary)["type"] as Orb.OrbType
			var orb: Orb = OrbRegistry.spawn(orb_type)
			if orb == null:
				continue
			orb.source_level = (entry as Dictionary)["source"]
			slots[j].populate_with_orb(orb)

func _physics_process(delta: float) -> void:
	if not Playback.is_playing:
		return
	var base_rate: float = bpm / BEATS_PER_MEASURE / 60.0
	_measure_t = fmod(_measure_t + base_rate * delta, 1.0)
	var tick_threshold: int = int(_measure_t * TICKS_PER_MEASURE)
	if tick_threshold != _last_tick_threshold:
		_last_tick_threshold = tick_threshold
		_current_tick = tick_threshold
		_tick_has_fired = true
		Playback.tick_advanced.emit(_current_tick)

func _process(delta: float) -> void:
	if not _resetting:
		return
	var all_done: bool = true
	for ring: Ring in _rings:
		var current: float = ring.get_current_angle()
		var normalized: float = fmod(current, TAU)
		if normalized < 0.0:
			normalized += TAU
		var target: float = 0.0 if normalized <= PI else TAU
		var lerped: float = lerpf(normalized, target, Ring.RESET_SPEED * delta)
		ring.set_current_angle(lerped)
		if abs(lerped - target) < Ring.RESET_THRESHOLD:
			ring.set_current_angle(0.0)
		else:
			all_done = false
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

func set_frame_glow(active: bool) -> void:
	if _frame_glow_tween != null and _frame_glow_tween.is_running():
		_frame_glow_tween.kill()
	_frame_glow_tween = create_tween()
	_frame_glow_tween.set_ease(Tween.EASE_OUT)
	_frame_glow_tween.set_trans(Tween.TRANS_QUAD)
	var target: Color = Color(1.35, 1.25, 0.95, 1.0) if active else Color.WHITE
	_frame_glow_tween.tween_property(_device, "modulate", target, 0.35)

func _on_playback_started() -> void:
	_playback_button_sfx.play()
	_resetting = false
	_ring_spin_sfx.play()
	_measure_t = 0.0
	_current_tick = 0
	_last_tick_threshold = -1
	_tick_has_fired = false
	var base_rate: float = bpm / BEATS_PER_MEASURE / 60.0
	for i: int in range(_rings.size()):
		var multiplier: float = _get_multiplier(i)
		# radians per second = full revolution (TAU) × rotations per second
		_rings[i].set_rotation_speed(base_rate * multiplier * TAU)

func _on_playback_stopped() -> void:
	_playback_button_sfx.play()
	_ring_spin_sfx.stop()
	for ring: Ring in _rings:
		ring.set_rotation_speed(0.0)
	_resetting = true

func get_ring_for_orb(orb: Orb) -> Ring:
	for ring: Ring in _rings:
		for slot: Slot in ring.get_slots():
			if slot.get_orb() == orb:
				return ring
	return null

func _on_ray_caster_note_triggered(orb_id: Orb.OrbType, texture: Texture2D, from_position: Vector2, tick: int, orb: Orb) -> void:
	_pending.append({
		"orb_id": orb_id,
		"texture": texture,
		"from": from_position,
		"tick": tick,
		"orb": orb,
	})
	if not _process_queued:
		_process_queued = true
		call_deferred("_flush_pending")

func _flush_pending() -> void:
	_process_queued = false
	for entry: Dictionary in _pending:
		note_triggered.emit(
			entry.orb_id as Orb.OrbType,
			entry.texture as Texture2D,
			entry.from as Vector2,
			entry.tick as int,
			entry.orb as Orb,
		)
	_pending.clear()
	
func export() -> Dictionary:
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
		for ring_idx: int in range(ring_grids.size()):
			var ring_grid: Array = ring_grids[ring_idx]
			if ring_grid[i] != null:
				curr_pos.append([ring_idx, int((ring_grid[i] as Orb).orb_id)])
		export_arr.append(curr_pos)
	var rings_data: Array = []
	for ring: Ring in _rings:
		rings_data.append({"interval": Ring.IntervalType.keys()[ring.interval_type]})
	return {"solution": export_arr, "bpm": bpm, "rings": rings_data}
