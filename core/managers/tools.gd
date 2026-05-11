class_name Tools
extends Node

## Toggle visibility with the hide_tools input action (backtick).

signal dev_load_requested(data: Dictionary)

var _sequencer: Sequencer = null

@onready var _panel: Control = $Tools/Layout/Form
@onready var _bpm_field: TextEdit = $Tools/Layout/Form/Timing/BPM/BPM
@onready var _ring0_interval: OptionButton = $Tools/Layout/Form/Timing/Intervals/Interval1/Option
@onready var _ring1_interval: OptionButton = $Tools/Layout/Form/Timing/Intervals/Interval2/Option
@onready var _ring2_interval: OptionButton = $Tools/Layout/Form/Timing/Intervals/Interval3/Option
@onready var _rotation_model_select: OptionButton = $Tools/Layout/Form/Timing/Rotation/Option
@onready var _custom_multipliers_field: TextEdit = $Tools/Layout/Form/Timing/Rotation/Field
@onready var _load_text: TextEdit = $Tools/Layout/Form/LevelData/Load/LoadText
@onready var _export_form: ExportForm = $ExportForm

func setup(sequencer: Sequencer) -> void:
	_sequencer = sequencer
	_setup_dev_tools()

func _setup_dev_tools() -> void:
	_panel.visible = false
	_bpm_field.text = str(_sequencer.bpm)
	_bpm_field.focus_exited.connect(_on_bpm_committed)

	var interval_buttons: Array[OptionButton] = [
		_ring0_interval, _ring1_interval, _ring2_interval
	]
	var rings: Array[Ring] = _sequencer.get_rings()
	for i: int in range(interval_buttons.size()):
		var btn := interval_buttons[i]
		btn.add_item("QUARTER", Ring.IntervalType.QUARTER)
		btn.add_item("EIGHTH", Ring.IntervalType.EIGHTH)
		btn.add_item("SIXTEENTH", Ring.IntervalType.SIXTEENTH)
		if i < rings.size():
			btn.select(int(rings[i].interval_type))
		var captured_i: int = i
		btn.item_selected.connect(func(idx: int) -> void:
			_on_interval_selected(captured_i, idx)
		)

	_rotation_model_select.add_item("QUANTIZED", Sequencer.RotationModel.QUANTIZED)
	_rotation_model_select.add_item("CUSTOM", Sequencer.RotationModel.CUSTOM)
	_rotation_model_select.select(int(_sequencer.rotation_model))
	_rotation_model_select.item_selected.connect(_on_rotation_model_selected)

	_custom_multipliers_field.text = _multipliers_to_string(_sequencer.custom_multipliers)
	_custom_multipliers_field.visible = _sequencer.rotation_model == Sequencer.RotationModel.CUSTOM
	_custom_multipliers_field.focus_exited.connect(_on_custom_multipliers_committed)

	var reset_btn := $Tools/Layout/Form/MiscUtils/Reset as Button
	var export_btn := $Tools/Layout/Form/LevelData/Export as Button
	var fill_btn := $Tools/Layout/Form/MiscUtils/FillSlots as Button
	var load_btn := $Tools/Layout/Form/LevelData/Load/Load as Button
	reset_btn.pressed.connect(_on_reset_pressed)
	export_btn.pressed.connect(_on_export_pressed)
	fill_btn.pressed.connect(_on_fill_slots_pressed)
	load_btn.pressed.connect(_on_load_slots_pressed)

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("hide_tools"):
		_panel.visible = !_panel.visible

func _on_bpm_committed() -> void:
	var value: float = _bpm_field.text.to_float()
	if value <= 0.0:
		_bpm_field.text = str(_sequencer.bpm)
		return
	_sequencer.bpm = minf(value, Sequencer.MAX_BPM)
	_bpm_field.text = str(_sequencer.bpm)

func _on_interval_selected(ring_index: int, item_index: int) -> void:
	var rings: Array[Ring] = _sequencer.get_rings()
	if ring_index >= rings.size():
		return
	rings[ring_index].interval_type = Ring.IntervalType.values()[item_index]

func _on_rotation_model_selected(item_index: int) -> void:
	_sequencer.rotation_model = Sequencer.RotationModel.values()[item_index]
	_custom_multipliers_field.visible = _sequencer.rotation_model == Sequencer.RotationModel.CUSTOM

func _on_fill_slots_pressed() -> void:
	for ring: Ring in _sequencer.get_rings():
		ring.eject_all_orbs()
		for slot: Slot in ring.get_slots():
			if slot.is_occupied():
				continue
			_add_orb_to_slot(slot)

func _on_custom_multipliers_committed() -> void:
	var parts: Array[String] = []
	for part: String in _custom_multipliers_field.text.split(","):
		parts.append(part.strip_edges())
	if parts.size() != _sequencer.get_rings().size():
		_custom_multipliers_field.text = _multipliers_to_string(_sequencer.custom_multipliers)
		return
	var parsed: Array[float] = []
	for part: String in parts:
		var val: float = part.to_float()
		if val <= 0.0:
			_custom_multipliers_field.text = _multipliers_to_string(_sequencer.custom_multipliers)
			return
		parsed.append(val)
	_sequencer.custom_multipliers = parsed
	_custom_multipliers_field.text = _multipliers_to_string(_sequencer.custom_multipliers)

func _on_load_slots_pressed() -> void:
	var load_obj = JSON.parse_string(_load_text.text)
	if load_obj == null:
		return
	dev_load_requested.emit(load_obj)

func _on_reset_pressed() -> void:
	Playback.stop()
	get_tree().reload_current_scene()

func _on_export_pressed() -> void:
	var data: Dictionary = _sequencer.export()
	_load_text.text = JSON.stringify({"solution": data["solution"]})
	_export_form.present(data["solution"], data["bpm"], data["rings"])

func _multipliers_to_string(multipliers: Array[float]) -> String:
	var parts: PackedStringArray = []
	for m: float in multipliers:
		parts.append(str(m))
	return ", ".join(parts)

func _add_orb_to_slot(slot: Slot, orb_type_index: int = -1) -> void:
	var orb: Orb = _generate_orb(orb_type_index)
	if orb == null or slot == null:
		return
	slot.add_child(orb)
	slot.receive_orb(orb)

func _generate_orb(orb_type_index: int = -1) -> Orb:
	if orb_type_index == -1:
		orb_type_index = randi() % Orb.OrbType.size()
	var orb_type: Orb.OrbType = Orb.OrbType.values()[orb_type_index]
	return OrbRegistry.spawn(orb_type)
