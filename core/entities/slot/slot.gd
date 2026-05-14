class_name Slot
extends Node2D

signal orb_placed(orb: Orb)

@export var texture_empty: Texture2D
@export var texture_occupied: Texture2D
@export var texture_hover: Texture2D

@export var in_tray: bool = false
@export var disabled: bool = false

var index: int
var _orb: Orb = null
var _hovered: bool = false
var _hinting: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _area: Area2D = $Handle
@onready var _drophint: Sprite2D = $DropHint

var _initial_orb_type: Orb.OrbType = -1

func _ready() -> void:
	add_to_group("slots")
	_drophint.visible = false
	_drophint.scale = Vector2.ZERO
	for child: Node in get_children():
		var orb := child as Orb
		if orb != null:
			_orb = orb
			break
	_refresh_visual()

## Silent placement used during level load. No land sound or lerp animation.
func populate_with_orb(orb: Orb) -> void:
	if _orb != null:
		_orb.queue_free()
		_orb = null
	add_child(orb)
	_orb = orb
	_refresh_visual()

## Accepts an orb into this slot. Returns the orb if rejected (slot occupied).
func receive_orb(incoming: Orb) -> Orb:
	if _orb == null:
		_orb = incoming
		_orb.reparent(self, true)
		_orb.land()
		_refresh_visual()
		orb_placed.emit(_orb)
		return null
	return incoming

func eject_orb() -> Orb:
	if _orb == null:
		return null
	var orb: Orb = _orb
	_orb = null
	_refresh_visual()
	return orb

func is_occupied() -> bool:
	return _orb != null

func get_orb() -> Orb:
	return _orb

func is_hinting() -> bool:
	return _hinting

func show_drophint() -> void:
	_hinting = true
	_drophint.scale = Vector2.ZERO
	_drophint.visible = true
	var tween := create_tween()
	tween.tween_property(_drophint, "scale", Vector2(0.5, 0.5), 0.15)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)

func hide_drophint() -> void:
	_hinting = false
	var tween := create_tween()
	tween.tween_property(_drophint, "scale", Vector2.ZERO, 0.1)\
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _drophint.visible = false)

func _refresh_visual() -> void:
	if _hovered and not is_occupied():
		_sprite.texture = texture_hover
	elif is_occupied():
		_sprite.texture = texture_occupied
	else:
		_sprite.texture = texture_empty

func _on_area_mouse_entered() -> void:
	if disabled:
		return
	_hovered = true
	_refresh_visual()

func _on_area_mouse_exited() -> void:
	if disabled:
		return
	_hovered = false
	_refresh_visual()
