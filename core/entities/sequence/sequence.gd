class_name Sequence
extends PanelContainer

@export_group("Panel Dip")
@export var dip_distance: float = 8.0
@export var dip_duration: float = 0.25

@onready var _orbs_container: HBoxContainer = $Orbs

var _write_head: int = 0
var _prev_write_head: int = -1
var _slots: Array[SequenceSlot] = []
var _dip_tween: Tween = null
var _rest_position: Vector2

func _ready() -> void:
	for child: Node in _orbs_container.get_children():
		var slot := child as SequenceSlot
		if slot == null:
			continue
		_slots.append(slot)
	Playback.stopped.connect(_on_playback_stopped)
	_rest_position = position
	_reset_slots()
	await get_tree().process_frame
	_update_indicator()

func get_next_slot_position() -> Vector2:
	if _slots.size() == 0:
		return Vector2.ZERO
	if _write_head >= _slots.size():
		_eject_all()
		_write_head = 0
		_prev_write_head = -1
		_update_indicator()
	return _slots[_write_head].global_position + _slots[_write_head].size * 0.5

func receive_orb(orb_id: Orb.OrbType, texture: Texture2D) -> void:
	if _slots.size() == 0:
		return
	var idx: int = _write_head % _slots.size()
	_slots[idx].receive(texture)
	_dip_panel()
	_write_head += 1
	_update_indicator()

func _on_playback_stopped() -> void:
	_write_head = 0
	_eject_all()
	_update_indicator()

func _eject_all() -> void:
	for slot: SequenceSlot in _slots:
		slot.eject()

func _reset_slots() -> void:
	_prev_write_head = -1
	for i: int in range(_slots.size()):
		_slots[i].clear()
		_slots[i].set_indicator(i == 0)

func _update_indicator() -> void:
	if _slots.size() == 0:
		return
	var current_idx: int = _write_head % _slots.size()
	if _prev_write_head >= 0 and _prev_write_head < _slots.size():
		_slots[_prev_write_head].play_indicator_exit()
	_slots[current_idx].play_indicator_enter()
	_prev_write_head = current_idx

func _dip_panel() -> void:
	if _dip_tween:
		_dip_tween.kill()
	_dip_tween = create_tween()
	_dip_tween.tween_property(self, "position:y", _rest_position.y + dip_distance, dip_duration * 0.5)\
		.set_ease(Tween.EASE_OUT)
	_dip_tween.tween_property(self, "position:y", _rest_position.y, dip_duration * 0.5)\
		.set_ease(Tween.EASE_IN)
