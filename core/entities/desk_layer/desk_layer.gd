class_name DeskLayer
extends Node2D

signal note_triggered(orb_id: Orb.OrbType, texture: Texture2D, from_position: Vector2, tick: int, orb: Orb)
signal console_settled
signal slot_changed(tick: int, ring_index: int, is_occupied: bool, from_load: bool)

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

@export var extra_tray_hidden_pos: Vector2 = Vector2(293, 707)
@export var extra_tray2_hidden_pos: Vector2 = Vector2(1641, 707)
@export var extra_tray_revealed_pos: Vector2 = Vector2(274, 588)
@export var extra_tray2_revealed_pos: Vector2 = Vector2(1663, 588)
@export var tray_reveal_duration: float = 0.6

@export var position_console: Vector2 = Vector2(0, -100)
@export var position_level_select: Vector2 = Vector2(0, 1500)
@export var position_playback: Vector2 = Vector2(0, 100)
@export var position_transition_duration: float = 0.5
@export var position_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var position_trans: Tween.TransitionType = Tween.TRANS_CUBIC
@export var z_index_console: int = 0
@export var z_index_level_select: int = 1

@onready var _rings_container: Node2D = $Sequencer/Rings
@onready var _ray_caster: RayCaster = $Sequencer/RayCaster
@onready var _sequencer: Node2D = $Sequencer
@onready var _ring_spin_sfx: AudioStreamPlayer = $PassiveSound/RingRotate
@onready var _return_all_orbs_sfx: AudioStreamPlayer = $PassiveSound/ReturnAllOrbs
@onready var _playback_button_sfx: AudioStreamPlayer = $Sequencer/StartStop/ButtonPress
#@onready var _lockbox: Lockbox = $Lockbox
@onready var _extra_tray: Node2D = $ExtraTray
@onready var _extra_tray2: Node2D = $ExtraTray2

var _rings: Array[Ring] = []
var _resetting: bool = false
var _position_tween: Tween = null
var _position_ready: bool = false
var _current_mode: ConsoleMode.Mode = ConsoleMode.Mode.LEVEL_SELECT

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
	#_lockbox.unlocked.connect(_on_lockbox_unlocked)
	_extra_tray.position = extra_tray_hidden_pos
	_extra_tray2.position = extra_tray2_hidden_pos
	_set_extra_trays_disabled(true)
	for ring: Ring in _rings:
		ring.slots_rebuilt.connect(_bind_ring_slots.bind(ring))
	_bind_all_ring_slots()


func _on_lockbox_unlocked() -> void:
	reveal_extra_trays()

func play_return_orbs_sfx() -> void:
	_return_all_orbs_sfx.play()

func reveal_extra_trays() -> void:
	_set_extra_trays_disabled(false)
	var t1 := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t1.tween_property(_extra_tray, "position", extra_tray_revealed_pos, tray_reveal_duration)
	var t2 := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t2.tween_property(_extra_tray2, "position", extra_tray2_revealed_pos, tray_reveal_duration)

func get_measure_duration() -> float:
	return (60.0 / bpm) * BEATS_PER_MEASURE

func get_measure_t() -> float:
	return _measure_t

func get_rings() -> Array[Ring]:
	return _rings

func eject_orbs() -> void:
	for ring: Ring in _rings:
		ring.eject_all_orbs()

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

func on_mode_changed(mode: ConsoleMode.Mode) -> void:
	_current_mode = mode
	if not _position_ready:
		_position_ready = true
		_snap_to_mode(mode)
		return
	match mode:
		ConsoleMode.Mode.CONSOLE:
			z_index = z_index_console
			_move_to(position_console, true)
		ConsoleMode.Mode.LEVEL_SELECT:
			z_index = z_index_level_select
			_move_to(position_level_select)

func on_playback_state_changed(is_playing: bool) -> void:
	if _current_mode != ConsoleMode.Mode.CONSOLE:
		return
	if is_playing:
		_move_to(position_playback)
	else:
		_move_to(position_console, true)

func _snap_to_mode(mode: ConsoleMode.Mode) -> void:
	match mode:
		ConsoleMode.Mode.CONSOLE:
			z_index = z_index_console
			position = position_console
		ConsoleMode.Mode.LEVEL_SELECT:
			z_index = z_index_level_select
			position = position_level_select

func _move_to(target: Vector2, emit_settled: bool = false) -> void:
	if _position_tween != null and _position_tween.is_running():
		_position_tween.kill()
	_position_tween = create_tween()
	_position_tween.set_ease(position_ease)
	_position_tween.set_trans(position_trans)
	_position_tween.tween_property(self, "position", target, position_transition_duration)
	if emit_settled:
		_position_tween.tween_callback(func() -> void: console_settled.emit())

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

func _bind_all_ring_slots() -> void:
	for ring: Ring in _rings:
		_bind_ring_slots(ring)

func _bind_ring_slots(ring: Ring) -> void:
	for slot: Slot in ring.get_slots():
		slot.orb_placed.connect(_on_ring_orb_placed.bind(slot, ring))
		slot.orb_ejected.connect(_on_ring_orb_ejected.bind(slot, ring))

func _on_ring_orb_placed(_orb: Orb, slot: Slot, ring: Ring) -> void:
	var tick: int = slot.index * (16 / ring.get_slot_count())
	slot_changed.emit(tick, ring.ring_index, true, false)

func _on_ring_orb_ejected(slot: Slot, ring: Ring) -> void:
	var tick: int = slot.index * (16 / ring.get_slot_count())
	slot_changed.emit(tick, ring.ring_index, false, false)

func _set_extra_trays_disabled(value: bool) -> void:
	for tray: Node2D in [_extra_tray, _extra_tray2]:
		var slots_node: Node = tray.get_node_or_null("Slots")
		if slots_node == null:
			continue
		for child: Node in slots_node.get_children():
			var slot := child as Slot
			if slot != null:
				slot.disabled = value

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

func load_locked_orbs(data: Array[LevelManager.SolutionData]) -> void:
	for tick_i in range(data.size()):
		for slot_data: LevelManager.SlotData in data[tick_i].rings:
			if(slot_data.locked):
				var adjusted_index = tick_i / (16 / _rings[slot_data.ring].get_slot_count())
				var slot_for_orb = _rings[slot_data.ring].get_slots()[adjusted_index]
				slot_for_orb.populate_with_orb(OrbRegistry.spawn(slot_data.orb_type))
				slot_for_orb.disabled = true
				slot_changed.emit(tick_i, slot_data.ring, true, true)
				pass
