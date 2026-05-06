class_name Slot
extends Node2D

signal slot_interacted(slot: Slot)

@export var texture_empty: Texture2D
@export var texture_occupied: Texture2D
@export var texture_hover: Texture2D

## How many orbs are in this slot at start. Requires one orb child added in the editor.
@export var stack_count: int = 1

## Badge textures indexed by count (index 0 unused, 1–8 map to pip counts)
@export var badge_textures: Array[Texture2D] = []

var index: int
var _orb: Orb = null
var _count: int = 0
var _hovered: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _area: Area2D = $Handle
@onready var _drophint: Sprite2D = $DropHint
@onready var _badge: Sprite2D = $Badge

func _ready() -> void:
	_drophint.visible = false
	_drophint.scale = Vector2.ZERO
	_badge.visible = false
	# Pick up any orb authored as a child in the editor
	for child: Node in get_children():
		var orb := child as Orb
		if orb != null:
			_orb = orb
			_count = clampi(stack_count, 1, 8)
			break
	_refresh_visual()

func receive_orb(incoming: Orb) -> Orb:
	# Empty slot path. Accept then type it
	if _orb == null:
		_orb = incoming
		_count = 1
		_orb.reparent(self, true)
		_orb.land()
		_refresh_visual()
		return null
	# Matching type path. stack it if under a max (currently 8)
	if incoming.orb_id == _orb.orb_id:
		if _count < 8:
			_count += 1
			incoming.queue_free()
			
			_refresh_visual()
			return null
		else:
			# Capped stack path. Reject it
			return incoming
	# Mismatched type. Reject it
	return incoming

func eject_orb() -> Orb:
	if _orb == null:
		return null
	if _count > 1:
		var spawned: Orb = OrbRegistry.spawn(_orb.orb_id)
		if spawned == null:
			return null
		# Must be in the tree before reparent can work
		add_child(spawned)
		_count -= 1
		_refresh_visual()
		return spawned
	else:
		var orb: Orb = _orb
		_orb = null
		_count = 0
		_refresh_visual()
		return orb

func is_occupied() -> bool:
	return _orb != null

func get_orb() -> Orb:
	return _orb

func get_count() -> int:
	return _count

func show_drophint() -> void:
	_drophint.scale = Vector2.ZERO
	_drophint.visible = true
	var tween := create_tween()
	tween.tween_property(_drophint, "scale", Vector2(0.5, 0.5), 0.15)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)

func hide_drophint() -> void:
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
	_refresh_badge()

func _refresh_badge() -> void:
	if _count <= 0 or badge_textures.size() < _count:
		_badge.visible = false
		return
	_badge.texture = badge_textures[_count - 1]
	_badge.visible = true

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
