class_name Sequence
extends PanelContainer

var _write_head: int = 0
var _slots: Array[Control] = []

func _ready() -> void:
	for child in $Notes.get_children():
		var slot := child as Control
		if slot == null:
			continue
		_slots.append(slot)
	Playback.stopped.connect(_on_playback_stopped)
	_reset_slots()

func register_orbit(orbit: Orbit) -> void:
	orbit.note_crossed.connect(_on_note_crossed)

func _on_note_crossed(note_id: StringName, texture: Texture2D) -> void:
	if _slots.size() == 0:
		return
	var slot: Control = _slots[_write_head]
	var empty := slot.get_node("Empty") as TextureRect
	var note := slot.get_node("Note") as TextureRect
	empty.visible = false
	note.texture = texture
	note.visible = true
	_write_head = (_write_head + 1) % _slots.size()

func _on_playback_stopped() -> void:
	_write_head = 0
	_reset_slots()

func _reset_slots() -> void:
	for slot in _slots:
		var empty := slot.get_node("Empty") as TextureRect
		var note := slot.get_node("Note") as TextureRect
		empty.visible = true
		note.visible = false
		note.texture = null
