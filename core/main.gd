extends Node2D

@onready var _hand: Hand = $HandLayer/Hand
@onready var _desk_layer: DeskLayer = $DeskLayer
@onready var _tray: Tray = $DeskLayer/Tray
@onready var _tutorial_tray: Tray = $DeskLayer/TutorialTray
@onready var _piano_roll: PianoRoll = $SkyLayer/PianoRoll
@onready var _playback_button: PlaybackButton = $DeskLayer/Sequencer/StartStop/Button
@onready var _sky_layer: SkyLayer = $SkyLayer
@onready var _level_manager: LevelManager = $LevelManager
@onready var _level_select: LevelSelect = $SkyLayer/LevelSelect
#@onready var _pentacle: Pentacle = $DeskLayer/Pentacle
@onready var _console_mode: ConsoleMode = $ConsoleMode
@onready var _audio_manager: AudioManager = $AudioManager
#@onready var _lockbox: Lockbox = $DeskLayer/Lockbox
@onready var _hints: Control = $HintsLayer/Hints
@onready var _action_pressed_sfx: AudioStreamPlayer = $HintsLayer/ActionPressed
@onready var _hint_level_select: Control = $HintsLayer/Hints/Hints/LevelSelectHint
@onready var _hint_playback: Control = $HintsLayer/Hints/Hints/PlaybackHint
@onready var _hint_return_orbs: Control = $HintsLayer/Hints/Hints/ReturnOrbsHint
@onready var _clues: Clues = $Clues
@onready var _camera: Camera2D = $Camera2D

## World-space Y coordinate that should sit at the bottom of the viewport.
@export var console_bottom: float = 900.0

var _hints_pending: bool = false
var _post_completion: bool = false
var _pending_freeplay: bool = false
var _active_tray: Tray = null


func _ready() -> void:
	Orb.prewarm()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_hints.visible = false

	# Cover the screen immediately so initial layout settling is hidden.
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 128
	add_child(fade_layer)
	var fade_rect := ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.size = get_viewport().get_visible_rect().size
	fade_layer.add_child(fade_rect)

	await get_tree().process_frame

	_console_mode.mode_changed.connect(_on_mode_changed)
	_console_mode.mode_changed.connect(_audio_manager.on_mode_changed)
	_console_mode.mode_changed.connect(_sky_layer.on_mode_changed)
	_console_mode.mode_changed.connect(_desk_layer.on_mode_changed)
	_console_mode.mode_changed.connect(_tray.on_mode_changed)
	_console_mode.mode_changed.connect(_tutorial_tray.on_mode_changed)
	#_console_mode.mode_changed.connect(_pentacle.on_mode_changed)
	_console_mode.playback_state_changed.connect(_desk_layer.on_playback_state_changed)
	_console_mode.playback_state_changed.connect(_sky_layer.on_playback_state_changed)
	_console_mode.playback_state_changed.connect(_tray.on_playback_state_changed)
	_console_mode.playback_state_changed.connect(_tutorial_tray.on_playback_state_changed)
	_console_mode.playback_state_changed.connect(_on_playback_state_changed)
	_desk_layer.console_settled.connect(_on_console_settled)
	_level_select.level_selected.connect(_on_level_selected)
	_piano_roll.constellation_completed.connect(_on_constellation_completed)
	_piano_roll.completion_pending.connect(_on_completion_pending)

	_hint_level_select.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint_level_select.gui_input.connect(_on_level_select_hint_gui_input)
	_hint_playback.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint_playback.gui_input.connect(_on_playback_hint_gui_input)
	_hint_return_orbs.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint_return_orbs.gui_input.connect(_on_return_orbs_hint_gui_input)
	_clues.clue_active_changed.connect(_hand.set_clue_active)
	#_lockbox.unlocked.connect(_on_lockbox_opened)
	_hand.connect_button(_playback_button)
	_desk_layer.note_triggered.connect(_on_note_triggered)
	_desk_layer.slot_changed.connect(_piano_roll.on_slot_changed)
	_desk_layer.locked_orb_placed.connect(_piano_roll.on_locked_orb_placed)
	_hand.hovered_ring_slot_changed.connect(_on_hovered_ring_slot_changed)
	_sky_layer.transition_midpoint.connect(_on_sky_transition_midpoint)
	_active_tray = _tray
	_tutorial_tray.visible = false
	_level_manager.initialize(_desk_layer, _tray, _piano_roll)
	_hand.set_tray(_active_tray)
	_piano_roll.set_sequencer(_desk_layer)
	_level_manager.load_level()
	_setup_level_select()

	# Prime the solution for the default-loaded level (no ClueCard shown at level select).
	var initial_data: LevelManager.LevelData = _level_manager.get_level_data_at_index(_level_manager.current_index())
	if not initial_data.solution.is_empty():
		_piano_roll.set_solution(initial_data.solution)

	_console_mode.initialize()
	get_viewport().size_changed.connect(_update_camera)
	_update_camera()

	var fade_t := create_tween()
	fade_t.tween_interval(1.0)
	fade_t.tween_property(fade_rect, "modulate:a", 0.0, 0.7) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	fade_t.tween_callback(fade_layer.queue_free)

func _update_camera() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var cam_y: float = console_bottom - viewport_size.y * 0.5
	_camera.position = Vector2(960.0, cam_y)
	_clues.present_position = Vector2(0.0, cam_y - _clues.position.y)

func _input(event: InputEvent) -> void:
	var is_special := event.is_action_pressed("level_select") \
		or event.is_action_pressed("playback_toggle") \
		or event.is_action_pressed("return_orbs")
	if is_special and _clues.is_active():
		_clues.dismiss_active()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("level_select"):
		_toggle_level_select()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("playback_toggle"):
		_toggle_playback()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("return_orbs"):
		_return_orbs_to_tray()
		get_viewport().set_input_as_handled()

func _toggle_level_select() -> void:
	if _console_mode.current_mode == ConsoleMode.Mode.LEVEL_SELECT:
		_console_mode.request_console()
	else:
		_console_mode.request_level_select()
	_action_pressed_sfx.play()
	_flash_hint(_hint_level_select)

func _toggle_playback() -> void:
	if _playback_button.disabled:
		return
	_playback_button.button_pressed = not _playback_button.button_pressed
	_action_pressed_sfx.play()
	_flash_hint(_hint_playback)

func _return_orbs_to_tray() -> void:
	if _console_mode.current_mode != ConsoleMode.Mode.CONSOLE or Playback.is_playing:
		return
	_sweep_non_pearl_orbs_to_tray()
	_action_pressed_sfx.play()
	_flash_hint(_hint_return_orbs)

func _on_level_select_hint_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_toggle_level_select()
		_hint_level_select.accept_event()

func _on_playback_hint_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_toggle_playback()
		_hint_playback.accept_event()

func _on_return_orbs_hint_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_return_orbs_to_tray()
		_hint_return_orbs.accept_event()

func _flash_hint(hint: Control) -> void:
	if not _hints.visible:
		return
	var t := create_tween()
	t.tween_property(hint, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(hint, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _on_playback_state_changed(is_playing: bool) -> void:
	var target_alpha: float = 0.35 if is_playing else 1.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_hint_level_select, "modulate:a", target_alpha, 0.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_hint_return_orbs, "modulate:a", target_alpha, 0.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

func _on_mode_changed(mode: ConsoleMode.Mode) -> void:
	match mode:
		ConsoleMode.Mode.CONSOLE:
			_present_clue_for_current_level()
			#_lockbox.visible = true
			_post_completion = false
		ConsoleMode.Mode.LEVEL_SELECT:
			_hand.return_held_to_tray(_active_tray)
			_clues.clear()
			if not _post_completion:
				_sweep_non_pearl_orbs_to_tray()

func _sweep_non_pearl_orbs_to_tray() -> void:
	var returned: Array[Orb] = []
	for node: Node in get_tree().get_nodes_in_group("slots"):
		var slot := node as Slot
		if slot == null or slot.in_tray or not slot.is_occupied():
			continue
		var orb: Orb = slot.get_orb()
		if orb.is_pearl or orb.is_locked:
			continue
		slot.eject_orb()
		var tray_slot: Slot = null
		if is_instance_valid(orb.home_slot) and orb.home_slot.in_tray \
				and not orb.home_slot.is_occupied() and not orb.home_slot.disabled:
			tray_slot = orb.home_slot
		if tray_slot == null:
			tray_slot = _active_tray.get_slot_for_orb(orb)
		if tray_slot == null:
			tray_slot = _find_any_empty_tray_slot()
		if tray_slot != null:
			tray_slot.receive_orb(orb, true)
			returned.append(orb)
		else:
			orb.queue_free()
	if returned.is_empty():
		return
	_desk_layer.play_return_orbs_sfx()
	var t := create_tween()
	for i: int in range(returned.size()):
		if i > 0:
			t.tween_interval(0.1)
		t.tween_callback(returned[i].play_return_to_tray)

func _on_console_settled() -> void:
	_clues.on_desk_settled()
	if _pending_freeplay:
		_pending_freeplay = false
		_desk_layer.reveal_extra_trays()
	if _hints_pending:
		_hints_pending = false
		_hints.modulate.a = 0.0
		_hints.visible = true
		var t := create_tween()
		t.tween_property(_hints, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _swap_active_tray(use_tutorial: bool) -> void:
	var next: Tray = _tutorial_tray if use_tutorial else _tray
	if next == _active_tray:
		return
	_active_tray.visible = false
	_active_tray = next
	_active_tray.visible = true
	_level_manager.set_tray(_active_tray)
	_hand.set_tray(_active_tray)

func _find_any_empty_tray_slot() -> Slot:
	for node: Node in get_tree().get_nodes_in_group("slots"):
		var slot := node as Slot
		if slot != null and slot.in_tray and not slot.is_occupied() and not slot.disabled:
			return slot
	return null

func _on_hovered_ring_slot_changed(slot: Slot) -> void:
	if slot == null:
		_piano_roll.clear_ghost_marker()
		return
	var ring := slot.get_parent().get_parent() as Ring
	if ring == null:
		_piano_roll.clear_ghost_marker()
		return
	var tick: int = slot.index * ring.load_modifier
	_piano_roll.set_ghost_marker(tick, ring.ring_index)

const INCORRECT_NOTE_DB_OFFSET: float = -8.0
const POST_COMPLETION_NOTE_OFFSET_DB: float = -10.0

var _sequencer_note_offset_db: float = 0.0

func _on_note_triggered(orb_id: Orb.OrbType, texture: Texture2D, _from_position: Vector2, tick: int, orb: Orb) -> void:
	var ring: Ring = _desk_layer.get_ring_for_orb(orb)
	var ring_index: int = ring.ring_index if ring != null else 0
	var offset: float = _sequencer_note_offset_db
	if not _piano_roll.is_solution_hit(tick, ring_index, orb_id):
		offset += INCORRECT_NOTE_DB_OFFSET
	if offset != 0.0:
		orb.apply_note_volume_offset(offset)
	_piano_roll.receive_orb(orb_id, texture, tick, ring_index, _desk_layer.get_measure_duration())

func _on_sky_transition_midpoint() -> void:
	_piano_roll.clear_keys()

func _setup_level_select() -> void:
	var all_points: Array = []
	for i: int in range(_level_manager.level_count()):
		var data: LevelManager.LevelData = _level_manager.get_level_data_at_index(i)
		if not data.solution.is_empty() and i != 0:
			all_points.append(_piano_roll.get_constellation_points(data.solution))
		else:
			all_points.append([] as Array[Vector2])
	_level_select.setup(all_points)
	for i: int in range(_level_manager.level_count()):
		_level_select.set_locked(i, not _level_manager.is_unlocked(i))

func _on_level_selected(index: int) -> void:
	Playback.stop()
	_playback_button.disabled = false
	_sequencer_note_offset_db = 0.0
	_desk_layer.apply_spin_sfx_db_offset(0.0)
	_swap_active_tray(index == 0)
	_level_manager.load_level_at_index(index)
	var data: LevelManager.LevelData = _level_manager.get_level_data_at_index(index)
	if data.solution.is_empty():
		_piano_roll.set_solution([])
		_clues.clear()
		_pending_freeplay = true
	_console_mode.request_console()

func _present_clue_for_current_level() -> void:
	_clues.clear()
	var data: LevelManager.LevelData = _level_manager.get_level_data_at_index(_level_manager.current_index())
	if data.solution.is_empty():
		return
	_piano_roll.set_solution(data.solution)
	var idx: int = _level_manager.current_index()
	if idx == 0:
		return
	if not _level_manager.is_clue_shown(idx):
		_level_manager.mark_clue_shown(idx)
		_audio_manager.play_level_start()
		if idx == 1:
			_hints_pending = true
	_clues.queue_clue(data.solution, _desk_layer.get_measure_duration(), false)

func _on_completion_pending() -> void:
	_playback_button.disabled = true
	_audio_manager.play_level_complete()
	_audio_manager.fade_for_completion()
	_clues.dismiss_solved()

func _on_constellation_completed() -> void:
	var completed: int = _level_manager.current_index()
	_level_manager.mark_completed(completed)
	_level_select.set_completed(completed, true)
	var next: int = completed + 1
	if next < _level_manager.level_count():
		_level_manager.unlock_level(next)
		_level_select.set_locked(next, false)
	_sequencer_note_offset_db = POST_COMPLETION_NOTE_OFFSET_DB
	_desk_layer.apply_spin_sfx_db_offset(POST_COMPLETION_NOTE_OFFSET_DB)
	_post_completion = true
	_console_mode.force_level_select()

func _on_lockbox_opened() -> void:
	_piano_roll.set_solution([])
	_level_manager.load_level_file("res://core/levels/dev/005_freeplay.json")
