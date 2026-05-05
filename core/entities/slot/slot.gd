class_name Slot
extends Node2D

signal slot_interacted(slot: Slot)

@export var texture_empty: Texture2D
@export var texture_occupied: Texture2D
@export var texture_hover: Texture2D

var index: int

var _note: Note
var _hovered: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _area: Area2D = $Area

func _ready() -> void:
	_refresh_visual()

func receive_note(incoming: Note) -> Note:
	var ejected: Note = null
	if _note != null:
		ejected = eject_note()
	_note = incoming
	_note.reparent(self, true)
	_note.land()
	_refresh_visual()
	return ejected

func eject_note() -> Note:
	if _note == null:
		return null
	var note: Note = _note
	_note = null
	_refresh_visual()
	return note

func is_occupied() -> bool:
	return _note != null

func get_note() -> Note:
	return _note
	
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
