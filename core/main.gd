extends Node2D

## Main scene coordinator.
## Wires node references together at startup and delegates level
## lifecycle to LevelManager. Owns the orb trail spawning flow
## since it bridges Sequencer (source) and PianoRoll (destination).

@onready var _hand: Hand = $Hand
@onready var _sequencer: Sequencer = $Sequencer
@onready var _tray: Tray = $Tray
@onready var _piano_roll: PianoRoll = $SkyLayer/PianoRoll
@onready var _feedback: Node2D = $DetectionFeedback
@onready var _background: Sprite2D = $Background
@onready var _playback_button: PlaybackButton = $Sequencer/StartStop/Button
@onready var _sky_layer: SkyLayer = $SkyLayer
@onready var _clue_card: ClueCard = $ClueCard
@onready var _level_manager: LevelManager = $LevelManager
@onready var _next_level_btn: Button = $NextLevel

const ORB_TRAIL_SCENE: PackedScene = preload("res://core/entities/orbs/orb_trail.tscn")

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_background.position = get_viewport_rect().size / 2
	await get_tree().process_frame
	_hand.connect_button(_playback_button)
	_sequencer.note_triggered.connect(_on_note_triggered)
	_sequencer.dev_load_requested.connect(_on_dev_load_requested)
	_next_level_btn.pressed.connect(_on_next_level_pressed)
	_sky_layer.transition_midpoint.connect(_on_sky_transition_midpoint)
	_sky_layer.transition_finished.connect(_on_sky_transition_finished)
	_level_manager.initialize(_sequencer, _tray, _piano_roll, _clue_card)
	_piano_roll.set_sequencer(_sequencer)
	_level_manager.load_level()
	_update_next_button()

func _on_note_triggered(orb_id: Orb.OrbType, texture: Texture2D, from_position: Vector2, tick: int) -> void:
	var target: Vector2 = _piano_roll.get_cell_position(tick, orb_id)
	var trail := ORB_TRAIL_SCENE.instantiate() as OrbTrail
	_feedback.add_child(trail)
	trail.setup(texture, from_position, target)
	var measure_duration: float = _sequencer.get_measure_duration()
	trail.arrived.connect(func() -> void:
		_piano_roll.receive_orb(orb_id, texture, tick, measure_duration)
	)

func _on_dev_load_requested(data: Dictionary) -> void:
	_level_manager.load_level_data(data)

func _on_next_level_pressed() -> void:
	_next_level_btn.disabled = true
	
	_sky_layer.rotate_to_next()
	
func _on_sky_transition_midpoint() -> void:
	_piano_roll.clear_keys()
	if _level_manager.is_last_level():
		_level_manager.load_level()
	else:
		_level_manager.load_next_level()
	_update_next_button()

func _on_sky_transition_finished() -> void:
	_next_level_btn.disabled = false

func _update_next_button() -> void:
	var next_index: int = _level_manager.get_next_index()
	var next_filename: String = _level_manager.get_level_filename(next_index)
	if _level_manager.is_last_level():
		_next_level_btn.text = "Return to Level 000 (%s)" % next_filename
	else:
		_next_level_btn.text = "Next Level (%s)" % next_filename

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("dev_quit"):
		get_tree().quit()
