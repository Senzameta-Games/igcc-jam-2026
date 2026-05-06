class_name Orb
extends Node2D

## A orb. Owned by a Slot when placed and by Hand when held.
## State controls z-index and lerp behavior.

enum State { IN_SLOT, HELD, LERPING }

const LERP_SPEED: float = 12.0
const LERP_THRESHOLD: float = 0.5

@export var orb_id: StringName = &""
@export var texture: Texture2D
@export var note: AudioStream

var _state: State = State.IN_SLOT

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _note: AudioStreamPlayer = $Note
@onready var _land: AudioStreamPlayer = $Land
@onready var _lift: AudioStreamPlayer = $Lift

func _ready() -> void:
	_sprite.play("default")

func _process(delta: float) -> void:
	if _state != State.LERPING:
		return
	var target: Vector2 = Vector2.ZERO
	var dist: float = position.distance_to(target)
	if dist < LERP_THRESHOLD:
		position = target
		_state = State.IN_SLOT
		return
	position = position.lerp(target, LERP_SPEED * delta)

func play_note() -> void:
	if note == null:
		return
	_note.stream = note
	_note.play()

func lift() -> void:
	_state = State.HELD
	_lift.play()
	z_index = 10

func land() -> void:
	# Called by Slot.receive_orb after reparenting.
	# position is now in Slot local space. Lerp to center.
	_state = State.LERPING
	_land.play()
	z_index = 5
