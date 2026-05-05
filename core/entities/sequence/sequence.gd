class_name Sequence
extends PanelContainer

@onready var _orbs_container: HBoxContainer = $Orbs

var _write_head: int = 0
var _slots: Array[Control] = []

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
	if _write_head >= _slots.size():
		_write_head = 0
		_reset_slots()
	var slot: Control = _slots[_write_head]
	var empty := slot.get_node("Empty") as TextureRect
	var orb := slot.get_node("Orb") as TextureRect
	empty.visible = false
	orb.texture = texture
	orb.visible = true
	_write_head += 1
	_update_indicator()

func _on_playback_stopped() -> void:
	_write_head = 0
	_reset_slots()
	_update_indicator()

func _update_indicator() -> void:
	for i: int in range(_slots.size()):
		var indicator := _slots[i].get_node("Indicator") as TextureRect
		indicator.visible = i == _write_head % _slots.size()

func _reset_slots() -> void:
	for slot: Control in _slots:
		var empty := slot.get_node("Empty") as TextureRect
		var orb := slot.get_node("Orb") as TextureRect
		empty.visible = true
		orb.visible = false
		orb.texture = null
