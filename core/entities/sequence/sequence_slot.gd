class_name SequenceSlot
extends Control

## A slot in the Sequence panel.
## Owns its own enter and eject animations.
## Eject is local, called one at a time

@export_group("Enter Animation")
@export var bob_distance: float = 6.0
@export var bob_duration: float = 0.2

@export_group("Eject Animation")
@export var eject_up_distance: float = 20.0
@export var eject_fall_distance: float = 200.0
@export var eject_up_duration: float = 0.06
@export var eject_fall_duration: float = 0.2

@export_group("Indicator Animation")
@export var indicator_dip_distance: float = 32.0
@export var indicator_dip_duration: float = 0.1
@export var indicator_rise_duration: float = 0.1

var _orb_texture: Texture2D = null
var _indicator_tween: Tween = null
var _slot_center: Vector2
var _indicator_rest_y: float

@onready var _empty: Sprite2D = $Empty
@onready var _orb: Sprite2D = $Orb
@onready var _indicator: Sprite2D = $Indicator

func _ready() -> void:
	await get_tree().process_frame
	_slot_center = size * 0.5
	_orb.position = _slot_center
	_empty.position = _slot_center
	# place indicator below center — adjust the offset to taste
	_indicator_rest_y = _slot_center.y + 40.0
	_indicator.position = Vector2(_slot_center.x, _indicator_rest_y)

func is_filled() -> bool:
	return _orb_texture != null

func set_indicator(visible_state: bool) -> void:
	if _indicator_tween:
		_indicator_tween.kill()
	_indicator.visible = visible_state
	_indicator.position = Vector2(_slot_center.x, _indicator_rest_y)
	_indicator.modulate.a = 1.0

func play_indicator_enter() -> void:
	if _indicator_tween:
		_indicator_tween.kill()
	_indicator.position = Vector2(_slot_center.x, _indicator_rest_y + indicator_dip_distance)
	_indicator.modulate.a = 0.0
	_indicator.visible = true
	_indicator_tween = create_tween()
	_indicator_tween.set_parallel(true)
	_indicator_tween.tween_property(_indicator, "position:y", _indicator_rest_y, indicator_rise_duration)\
		.set_ease(Tween.EASE_OUT)
	_indicator_tween.tween_property(_indicator, "modulate:a", 1.0, indicator_rise_duration)

func play_indicator_exit() -> void:
	if _indicator_tween:
		_indicator_tween.kill()
	_indicator_tween = create_tween()
	_indicator_tween.set_parallel(true)
	_indicator_tween.tween_property(_indicator, "position:y", _indicator_rest_y + indicator_dip_distance, indicator_dip_duration)\
		.set_ease(Tween.EASE_IN)
	_indicator_tween.tween_property(_indicator, "modulate:a", 0.0, indicator_dip_duration)
	_indicator_tween.tween_callback(func() -> void:
		_indicator.visible = false
		_indicator.position.y = _indicator_rest_y
		_indicator.modulate.a = 1.0
	).set_delay(indicator_dip_duration)

func receive(texture: Texture2D) -> void:
	_orb_texture = texture
	_orb.texture = texture
	_empty.visible = false
	_orb.visible = true
	_orb.position = Vector2.ZERO
	_animate_enter()

func eject() -> void:
	if _orb_texture == null:
		return
	_orb_texture = null
	_animate_eject()

func clear() -> void:
	_orb_texture = null
	_orb.texture = null
	_orb.visible = false
	_orb.position = _slot_center
	_empty.visible = true

func _animate_enter() -> void:
	_orb.position = _slot_center
	var tween := create_tween()
	tween.tween_property(_orb, "position:y", _slot_center.y + bob_distance, bob_duration * 0.5)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_orb, "position:y", _slot_center.y, bob_duration * 0.5)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_BACK)

func _animate_eject() -> void:
	var tween := create_tween()
	tween.tween_property(_orb, "position:y", -eject_up_distance, eject_up_duration)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_orb, "position:y", eject_fall_distance, eject_fall_duration)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(clear)
