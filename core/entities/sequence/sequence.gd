class_name Sequence
extends PanelContainer

@onready var _orbs_container: HBoxContainer = $Orbs

var _write_head: int = 0
var _slots: Array[Control] = []
var _clearing: bool = false
var _pending_orbs: Array[Dictionary] = []
var _wipe_tween: Tween = null

func _ready() -> void:
	for child: Node in _orbs_container.get_children():
		var slot := child as Control
		if slot == null:
			continue
		_slots.append(slot)
	Playback.stopped.connect(_on_playback_stopped)
	_reset_slots()
	_update_indicator()

func register_detector(detector: Detector) -> void:
	detector.orb_passed.connect(_on_orb_passed)

func _on_orb_passed(orb_id: StringName, texture: Texture2D) -> void:
	if _slots.size() == 0:
		return
	if _clearing:
		_pending_orbs.append({"orb_id": orb_id, "texture": texture})
		return
	if _write_head >= _slots.size():
		_start_wipe(orb_id, texture)
		return
	_fill_slot(orb_id, texture)

func _fill_slot(orb_id: StringName, texture: Texture2D) -> void:
	var slot: Control = _slots[_write_head]
	var empty := slot.get_node("Empty") as TextureRect
	var orb := slot.get_node("Orb") as TextureRect
	empty.visible = false
	orb.texture = texture
	orb.visible = true
	_write_head += 1
	_update_indicator()

func _start_wipe(first_orb_id: StringName, first_texture: Texture2D) -> void:
	_clearing = true
	_pending_orbs.clear()
	_pending_orbs.append({"orb_id": first_orb_id, "texture": first_texture})
	_update_indicator()

	_wipe_tween = create_tween()
	for i: int in range(_slots.size()):
		_wipe_tween.tween_interval(0.04)
		_wipe_tween.tween_callback(_clear_slot.bind(i))
	_wipe_tween.tween_callback(_finish_wipe)

func _clear_slot(index: int) -> void:
	var slot: Control = _slots[index]
	var empty := slot.get_node("Empty") as TextureRect
	var orb := slot.get_node("Orb") as TextureRect
	empty.visible = true
	orb.visible = false
	orb.texture = null

func _finish_wipe() -> void:
	_wipe_tween = null
	_clearing = false
	_write_head = 0
	var buffered := _pending_orbs.duplicate()
	_pending_orbs.clear()
	for entry: Dictionary in buffered:
		_on_orb_passed(entry["orb_id"], entry["texture"])

func _on_playback_stopped() -> void:
	if _wipe_tween != null:
		_wipe_tween.kill()
		_wipe_tween = null
	_clearing = false
	_pending_orbs.clear()
	_write_head = 0
	_reset_slots()
	_update_indicator()

func _update_indicator() -> void:
	for i: int in range(_slots.size()):
		var indicator := _slots[i].get_node("Indicator") as TextureRect
		indicator.visible = not _clearing and i == _write_head % _slots.size()

func _reset_slots() -> void:
	for slot: Control in _slots:
		var empty := slot.get_node("Empty") as TextureRect
		var orb := slot.get_node("Orb") as TextureRect
		empty.visible = true
		orb.visible = false
		orb.texture = null
