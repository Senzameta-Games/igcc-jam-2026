extends Node2D

@onready var _hand: Hand = $Hand
@onready var _sequencer: Sequencer = $Sequencer
@onready var _tray: Tray = $Sequencer/Tray
@onready var _piano_roll: PianoRoll = $SkyLayer/PianoRoll
@onready var _playback_button: PlaybackButton = $Sequencer/Device/StartStop/Button
@onready var _sky_layer: SkyLayer = $SkyLayer
@onready var _level_manager: LevelManager = $LevelManager
@onready var _level_select: LevelSelect = $SkyLayer/LevelSelect
@onready var _stash: Stash = $Sequencer/Stash
@onready var _console_mode: ConsoleMode = $ConsoleMode
@onready var _tools: Tools = $Tools
@onready var _audio_manager: AudioManager = $AudioManager
@onready var _lockbox: Lockbox = $Sequencer/Lockbox

@export var sequencer_position_desk: Vector2 = Vector2(0, -100)
@export var sequencer_position_sky: Vector2 = Vector2(0, 341)
@export var sequencer_position_level_select: Vector2 = Vector2(0, 1500)
@export var sequencer_transition_duration: float = 0.5
@export var sequencer_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var sequencer_trans: Tween.TransitionType = Tween.TRANS_CUBIC
@export var sequencer_z_index_desk: int = 0
@export var sequencer_z_index_sky: int = -1

var _sequencer_tween: Tween = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	await get_tree().process_frame

	_console_mode.mode_changed.connect(_on_mode_changed)
	_console_mode.mode_changed.connect(_audio_manager.on_mode_changed)
	_console_mode.mode_changed.connect(_sky_layer.on_mode_changed)
	_console_mode.mode_changed.connect(_tray.on_mode_changed)
	_console_mode.mode_changed.connect(_stash.on_mode_changed)
	_sky_layer.focus_requested.connect(_console_mode.request_sky)
	_sky_layer.desk_requested.connect(_console_mode.request_desk)
	_sky_layer.level_select_requested.connect(_console_mode.request_level_select)
	_sky_layer.desk_area_hovered.connect(_sequencer.set_frame_glow)
	_level_select.level_selected.connect(_on_level_selected)
	_piano_roll.constellation_completed.connect(_on_constellation_completed)

	_lockbox.unlocked.connect(_on_lockbox_opened)
	_hand.connect_button(_playback_button)
	_sequencer.note_triggered.connect(_on_note_triggered)
	_tools.dev_load_requested.connect(_on_dev_load_requested)
	_tools.setup(_sequencer)
	_sky_layer.transition_midpoint.connect(_on_sky_transition_midpoint)
	_level_manager.initialize(_sequencer, _tray, _piano_roll)
	_hand.set_tray(_tray)
	_piano_roll.set_sequencer(_sequencer)
	_level_manager.load_level()
	_setup_level_select()

	# Prime the solution for the default-loaded level (no ClueCard shown at level select).
	var initial_data: Dictionary = _level_manager.get_level_data_at_index(_level_manager.current_index())
	if initial_data.has("solution"):
		_piano_roll.set_solution(initial_data["solution"])

	_sequencer.position = sequencer_position_level_select
	_sequencer.z_index = sequencer_z_index_sky
	_console_mode.initialize()

func _on_mode_changed(mode: ConsoleMode.Mode) -> void:
	match mode:
		ConsoleMode.Mode.SKY:
			_move_sequencer(sequencer_position_sky)
			_sequencer.z_index = sequencer_z_index_sky
			_lockbox.visible = false
		ConsoleMode.Mode.DESK:
			_move_sequencer(sequencer_position_desk)
			_sequencer.z_index = sequencer_z_index_desk
			_lockbox.visible = true
		ConsoleMode.Mode.LEVEL_SELECT:
			_move_sequencer(sequencer_position_level_select)
			_sequencer.z_index = sequencer_z_index_sky
			_lockbox.visible = false

func _move_sequencer(target: Vector2) -> void:
	if _sequencer_tween != null and _sequencer_tween.is_running():
		_sequencer_tween.kill()
	_sequencer_tween = create_tween()
	_sequencer_tween.set_ease(sequencer_ease)
	_sequencer_tween.set_trans(sequencer_trans)
	_sequencer_tween.tween_property(_sequencer, "position", target, sequencer_transition_duration)
	if target == sequencer_position_desk:
		_sequencer_tween.tween_callback(_sequencer.on_desk_settled)

func _on_note_triggered(orb_id: Orb.OrbType, texture: Texture2D, _from_position: Vector2, tick: int, orb: Orb) -> void:
	var ring: Ring = _sequencer.get_ring_for_orb(orb)
	var ring_index: int = ring.ring_index if ring != null else 0
	_piano_roll.receive_orb(orb_id, texture, tick, ring_index, _sequencer.get_measure_duration())

func _on_dev_load_requested(data: Dictionary) -> void:
	_level_manager.load_level_data(data)

func _on_sky_transition_midpoint() -> void:
	_piano_roll.clear_keys()

func _on_export_form_file_added(file_name: String) -> void:
	_level_manager.add_file_name(file_name)
	_setup_level_select()

func _setup_level_select() -> void:
	var all_points: Array = []
	for i: int in range(_level_manager.level_count()):
		var data: Dictionary = _level_manager.get_level_data_at_index(i)
		if data.has("solution"):
			all_points.append(_piano_roll.get_constellation_points(data["solution"]))
		else:
			all_points.append([])
	_level_select.setup(all_points)
	for i: int in range(_level_manager.level_count()):
		_level_select.set_locked(i, not _level_manager.is_unlocked(i))

func _on_level_selected(index: int) -> void:
	Playback.stop()
	_level_manager.load_level_at_index(index)
	_present_clue_for_current_level()
	_console_mode.request_desk()

func _present_clue_for_current_level() -> void:
	var data: Dictionary = _level_manager.get_level_data_at_index(_level_manager.current_index())
	if not data.has("solution"):
		return
	_piano_roll.set_solution(data["solution"])
	if not _level_manager.is_completed(_level_manager.current_index()):
		_sequencer.queue_clue(data["solution"])

func _on_constellation_completed() -> void:
	var completed: int = _level_manager.current_index()
	_level_manager.mark_completed(completed)
	_level_select.set_completed(completed, true)
	var next: int = completed + 1
	if next < _level_manager.level_count():
		_level_manager.unlock_level(next)
		_level_select.set_locked(next, false)
	_console_mode.force_level_select()

func _on_lockbox_opened() -> void:
	_piano_roll.set_solution([])
	_level_manager.load_level_data({
		"rings": [
			{"interval": "SIXTEENTH"},
			{"interval": "SIXTEENTH"},
			{"interval": "SIXTEENTH"}
		],
		"tray_orbs": [0, 1, 2, 3, 4]
	})
