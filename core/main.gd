extends Node2D

@onready var _hand: Hand = $Hand
@onready var _sequencer: Sequencer = $Sequencer
@onready var _tray: Tray = $Tray
@onready var _piano_roll: PianoRoll = $SkyLayer/PianoRoll
@onready var _feedback: Node2D = $DetectionFeedback
@onready var _background: Sprite2D = $Background
@onready var _playback_button: PlaybackButton = $Sequencer/StartStop/Button
@onready var _sky_layer: SkyLayer = $SkyLayer
@onready var _clue_card: ClueCard = $ClueCard
@onready var _test_rotate_btn: Button = $TestRotate

const ORB_TRAIL_SCENE: PackedScene = preload("res://core/entities/orbs/orb_trail.tscn")

# Uses the tools panel solution data as a hardcoded placeholder
var json_data: Dictionary = {"solution": [[], [], [1,2], [], [1,2,3], [], [], [2], [1,2,3], [], [], [], [0,3,2], [1], [2], [3]]}

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_background.position = get_viewport_rect().size / 2
	await get_tree().process_frame
	_piano_roll.setup(_tray)
	_hand.connect_button(_playback_button)
	_sequencer.note_triggered.connect(_on_note_triggered)
	_test_rotate_btn.pressed.connect(_on_test_rotate_pressed)
	_load_level(json_data)

func _load_level(json_data: Dictionary) -> void:
	var key_targets: Array[Vector2] = _build_key_targets(json_data["solution"])
	var piano_roll_keys: Node2D = _piano_roll.get_node("Keys") as Node2D
	_clue_card.setup(key_targets, piano_roll_keys)
	_clue_card.present()

func _build_key_targets(solution: Array) -> Array[Vector2]:
	var targets: Array[Vector2] = []
	var unique_orbs: Array[Orb.OrbType] = _tray.get_unique_orbs()
	var key_count: int = _clue_card.get_key_count()
	
	# The solution array is indexed by slot position (tick 0 = slot 0 = leftmost
	# in the data). However, the sequencer rotates clockwise toward the detector,
	# so slot 0 is the LAST slot to reach the detector each measure. This means
	# solution tick 0 maps to the rightmost column on the piano roll (last detected),
	# and solution tick 15 maps to the leftmost column (first detected).
	#
	# To get the correct piano roll column for a given solution tick, we mirror:
	# piano_roll_tick = last_tick - solution_tick
	#
	# We iterate in reverse (last solution tick first) so that key stars represent
	# the final notes of the sequence (the last slots before slot 0) which are
	# the first notes the player will hear on playback. My brain is broken.
	
	for tick: int in range(solution.size() - 1, -1, -1):
		if targets.size() >= key_count:
			break
		var orb_arr: Array = solution[tick]
		for orb_type_int: int in orb_arr:
			if targets.size() >= key_count:
				break
			var orb_id := orb_type_int as Orb.OrbType
			var note_row: int = unique_orbs.find(orb_id)
			if note_row == -1:
				continue
			targets.append(_piano_roll.get_cell_position(solution.size() - 1 - tick, orb_id))
	return targets

func _on_note_triggered(orb_id: Orb.OrbType, texture: Texture2D, from_position: Vector2, tick: int) -> void:
	var target: Vector2 = _piano_roll.get_cell_position(tick, orb_id)
	var trail := ORB_TRAIL_SCENE.instantiate() as OrbTrail
	_feedback.add_child(trail)
	trail.setup(texture, from_position, target)
	var measure_duration: float = _sequencer.get_measure_duration()
	trail.arrived.connect(func() -> void:
		_piano_roll.receive_orb(orb_id, texture, tick, measure_duration)
	)

func _on_test_rotate_pressed() -> void:
	_sky_layer.rotate_to_next()

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("dev_quit"):
		get_tree().quit()
