class_name Slot
extends Node2D

signal slot_interacted(slot: Slot)

@export var texture_empty: Texture2D
@export var texture_occupied: Texture2D
@export var texture_hover: Texture2D

var index: int

var _orb: Orb
var _hovered: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _area: Area2D = $Area

func _ready() -> void:
	# Pick up any orb authored as a child in the editor
	for child: Node in get_children():
		var orb := child as Orb
		if orb != null:
			_orb = orb
			break
	_refresh_visual()

func receive_orb(incoming: Orb) -> Orb:
	var ejected: Orb = null
	if _orb != null:
		ejected = eject_orb()
	_orb = incoming
	_orb.reparent(self, true)
	_orb.land()
	_refresh_visual()
	return ejected

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
	
func _refresh_visual() -> void:
	if _hovered and not is_occupied():
		_sprite.texture = texture_hover
	elif is_occupied():
		_sprite.texture = texture_occupied
	else:
		_sprite.texture = texture_empty

func _on_area_mouse_entered() -> void:
	_hovered = true
	_refresh_visual()
 
func _on_area_mouse_exited() -> void:
	_hovered = false
	_refresh_visual()

func _on_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			slot_interacted.emit(self)
			get_viewport().set_input_as_handled()
