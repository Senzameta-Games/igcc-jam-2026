class_name Orb
extends Node2D

## State controls z-index and lerp behavior.

enum State { IN_SLOT, HELD, LERPING }

const LERP_SPEED: float = 12.0
const LERP_THRESHOLD: float = 0.5

enum OrbType { Bb3, F3, G3, A4, D4 }
@export var texture: Texture2D
@export var key_star_texture: Texture2D
@export var note: AudioStream

@export var orb_id: OrbType = OrbType.F3
@export var is_pearl: bool = false

var source_level: int = -1
var _state: State = State.IN_SLOT

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _note: AudioStreamPlayer = $Note
@onready var _land: AudioStreamPlayer = $Land
@onready var _lift: AudioStreamPlayer = $Lift
@onready var _pitchhint: AudioStreamPlayer = $PitchHint

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
	_pitchhint.play()

func land() -> void:
	# position is now in Slot local space. Lerp to center.
	_state = State.LERPING
	_land.play()
	_pitchhint.play()
