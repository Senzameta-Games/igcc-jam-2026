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
var _pulse_tween: Tween = null

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _note: AudioStreamPlayer = $Note
@onready var _land: AudioStreamPlayer = $Land
@onready var _lift: AudioStreamPlayer = $Lift
@onready var _pitchhint: AudioStreamPlayer = $PitchHint

func _init() -> void:
	if (key_star_texture == null):
		key_star_texture = KeyStar.KEY_STAR_TEXTURES[orb_id]

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

func pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.05) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	_pulse_tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 3.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

func lift() -> void:
	_state = State.HELD
	_lift.play()
	_pitchhint.play()

func land(silent: bool = false) -> void:
	# position is now in Slot local space. Lerp to center.
	_state = State.LERPING
	if not silent:
		_land.play()
		_pitchhint.play()
