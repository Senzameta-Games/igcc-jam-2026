extends Node2D

@onready var _hand: Hand = $Hand
@onready var _sequencer: Node2D = $Sequencer
@onready var _background: Sprite2D = $Background
@onready var _tray: Tray = $Tray

func _ready() -> void:
	_background.position = get_viewport_rect().size / 2
	await get_tree().process_frame
	_sequencer.setup(_tray)
	_sequencer.inject_hand(_hand)
	_tray.connect_hand(_hand)

func _input(InputEvent) -> void:
	if Input.is_action_just_pressed("dev_quit"):
		get_tree().quit()
