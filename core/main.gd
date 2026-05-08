extends Node2D

@onready var _hand: Hand = $Hand
@onready var _sequencer: Sequencer = $Sequencer
@onready var _tray: Tray = $Tray
@onready var _piano_roll: PianoRoll = $SkyLayer/PianoRoll
@onready var _feedback: Node2D = $DetectionFeedback
@onready var _background: Sprite2D = $Background
@onready var _playback_button: PlaybackButton = $Sequencer/StartStop/Button

const ORB_TRAIL_SCENE: PackedScene = preload("res://core/entities/orbs/orb_trail.tscn")

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_background.position = get_viewport_rect().size / 2
	await get_tree().process_frame
	_piano_roll.setup(_tray)
	_hand.connect_button(_playback_button)
	_sequencer.note_triggered.connect(_on_note_triggered)

func _on_note_triggered(orb_id: Orb.OrbType, texture: Texture2D, from_position: Vector2, tick: int) -> void:
	var target: Vector2 = _piano_roll.get_cell_position(tick, orb_id)
	var trail := ORB_TRAIL_SCENE.instantiate() as OrbTrail
	_feedback.add_child(trail)
	trail.setup(texture, from_position, target)
	var measure_duration: float = _sequencer.get_measure_duration()
	trail.arrived.connect(func() -> void:
		_piano_roll.receive_orb(orb_id, texture, tick, measure_duration)
	)

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("dev_quit"):
		get_tree().quit()
