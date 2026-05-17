class_name Orb
extends Node2D

## State controls z-index and lerp behavior.

enum State { IN_SLOT, HELD, LERPING }

const LERP_SPEED: float = 12.0
const LERP_THRESHOLD: float = 0.5

enum OrbType { Bb3, F3, G3, A4, D4 }
@export var texture: Texture2D
@export var key_star_texture: Texture2D
@export var locked_texture: Texture2D
@export var note: AudioStream

@export var orb_id: OrbType = OrbType.F3
@export var is_pearl: bool = false

var is_locked: bool = false

static var _highlight_material: ShaderMaterial = null
static var _hover_material: ShaderMaterial = null

static func prewarm() -> void:
	if _highlight_material == null:
		_highlight_material = ShaderMaterial.new()
		_highlight_material.shader = preload("res://core/entities/orbs/orb_highlight.gdshader")
	if _hover_material == null:
		_hover_material = ShaderMaterial.new()
		_hover_material.shader = preload("res://core/entities/orbs/hover_outline.gdshader")

var _is_hovered: bool = false
var source_level: int = -1
var _state: State = State.IN_SLOT
var _pulse_tween: Tween = null
var _note_base_db: float = 0.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _note: AudioStreamPlayer = $Note
@onready var _land: AudioStreamPlayer = $Land
@onready var _lift: AudioStreamPlayer = $Lift
@onready var _pitchhint: AudioStreamPlayer = $PitchHint
@onready var _return_to_tray_sfx: AudioStreamPlayer = $ReturnToTray

func _init() -> void:
	if (key_star_texture == null):
		key_star_texture = KeyStar.KEY_STAR_TEXTURES[orb_id]

func _ready() -> void:
	_note_base_db = _note.volume_db
	_sprite.play("default")
	prewarm()
	Playback.started.connect(_on_playback_started)
	Playback.stopped.connect(_on_playback_stopped)
	_refresh_material()

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
	_note.volume_db = _note_base_db
	_note.play()

func apply_note_volume_offset(offset_db: float) -> void:
	_note.volume_db = _note_base_db + offset_db

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

func show_hover() -> void:
	_is_hovered = true
	_refresh_material()

func hide_hover() -> void:
	_is_hovered = false
	_refresh_material()

func _refresh_material() -> void:
	if is_locked or Playback.is_playing:
		_sprite.material = null
	elif _is_hovered:
		_sprite.material = _hover_material
	else:
		_sprite.material = _highlight_material

func set_locked() -> void:
	is_locked = true
	_is_hovered = false
	_sprite.play("locked")
	_refresh_material()
	Playback.started.disconnect(_on_playback_started)
	Playback.stopped.disconnect(_on_playback_stopped)

func play_return_to_tray() -> void:
	_return_to_tray_sfx.play()

func _on_playback_started() -> void:
	_refresh_material()

func _on_playback_stopped() -> void:
	_refresh_material()
