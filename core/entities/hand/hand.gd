class_name Hand
extends Node2D

signal picked_up(orb: Orb)
signal dropped

@export var texture_empty: Texture2D
@export var texture_holding: Texture2D
@export var texture_pointing: Texture2D

var _held_orb: Orb = null
var _pointing: bool = false
var _tray: Tray = null

@onready var _area: Area2D = $Area
@onready var _sprite: Sprite2D = $Sprite

func _ready() -> void:
	_refresh_texture()
	var mouse: Vector2 = get_global_mouse_position()
	_area.global_position = mouse
	_sprite.global_position = mouse

func _process(_delta: float) -> void:
	var mouse: Vector2 = get_global_mouse_position()
	_area.global_position = mouse
	_sprite.global_position = mouse
	if _held_orb == null:
		return
	_held_orb.global_position = mouse

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if Playback.is_playing:
		return
	# Right click
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		for area: Area2D in _area.get_overlapping_areas():
			var slot := area.get_parent() as Slot
			if slot == null or slot.in_tray or not slot.is_occupied():
				continue
			var orb: Orb = slot.eject_orb()
			if orb == null:
				continue
			if _tray != null:
				var tray_slot: Slot = _tray.get_slot_for_orb(orb)
				if tray_slot != null:
					tray_slot.receive_orb(orb)
				else:
					# No tray slot to put the orb
					slot.receive_orb(orb)
			get_viewport().set_input_as_handled()
			return
	
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if _held_orb != null:
		for area: Area2D in _area.get_overlapping_areas():
			var parent = area.get_parent()
			var slot_to_handle = null
			if(parent is Slot):
				slot_to_handle = parent as Slot
			elif(parent is Tray):
				var tray := parent as Tray
				slot_to_handle = tray.get_slot_for_orb(_held_orb)
			if slot_to_handle == null:
				continue
			var held_type: Orb.OrbType = _held_orb.orb_id
			var shift_held: bool = Input.is_key_pressed(KEY_SHIFT) and not slot_to_handle.in_tray
			try_drop(slot_to_handle)
			if shift_held and _held_orb == null and _tray != null:
				var refill_slot: Slot = _tray.get_occupied_slot_for_type(held_type)
				if refill_slot != null:
					pick_up(refill_slot.eject_orb())
			get_viewport().set_input_as_handled()
			return
	else:
		for area: Area2D in _area.get_overlapping_areas():
			var slot := area.get_parent() as Slot
			if slot == null:
				continue
			if slot.is_occupied():
				pick_up(slot.eject_orb())
				get_viewport().set_input_as_handled()
				return

func set_tray(tray: Tray) -> void:
	_tray = tray

func connect_button(button: PlaybackButton) -> void:
	picked_up.connect(button._on_picked_up)
	dropped.connect(button._on_dropped)
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)

func pick_up(orb: Orb) -> void:
	if orb == null:
		return
	_held_orb = orb
	var actual_pos: Vector2 = orb.global_position
	_held_orb.reparent(self, true)
	_held_orb.global_position = actual_pos
	_held_orb.lift()
	_refresh_texture()
	_show_all_drophints()
	picked_up.emit(_held_orb)

func try_drop(slot: Slot) -> void:
	if _held_orb == null:
		return
	var orb_to_drop: Orb = _held_orb
	_held_orb = null
	_hide_all_drophints()
	_refresh_texture()
	var ejected: Orb = slot.receive_orb(orb_to_drop)
	if ejected != null:
		pick_up(ejected)
		return
	dropped.emit()

func is_holding() -> bool:
	return _held_orb != null

func _on_button_mouse_entered() -> void:
	_pointing = true
	_refresh_texture()
 
func _on_button_mouse_exited() -> void:
	_pointing = false
	_refresh_texture()

func _refresh_texture() -> void:
	if _pointing and _held_orb == null:
		_sprite.texture = texture_pointing
		_sprite.offset = Vector2(76, 120)
	elif _held_orb != null:
		_sprite.texture = texture_holding
		_sprite.offset = Vector2(70, 80)
	else:
		_sprite.texture = texture_empty
		_sprite.offset = Vector2(70, 80)

func _show_all_drophints() -> void:
	for node: Node in get_tree().get_nodes_in_group("slots"):
		var slot := node as Slot
		if slot == null or slot.is_occupied():
			continue
		slot.show_drophint()

func _hide_all_drophints() -> void:
	for node: Node in get_tree().get_nodes_in_group("slots"):
		var slot := node as Slot
		if slot == null:
			continue
		slot.hide_drophint()
