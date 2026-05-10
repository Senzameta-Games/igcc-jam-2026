class_name ExportForm
extends Node2D

## ExportForm. Dev tool popup for authoring and saving level JSON files.
## Shown when the Export button is pressed in the sequencer dev tools.
## Pre-populates BPM, ring config, and solution from current sequencer state.
## Developer fills in the level name, then saves to res://core/levels/dev/.
##
## File naming: [nnn]_[name].json where nnn is zero-padded 3-digit ID.
## New ID = highest existing ID + 1. First level = 000.
## Duplicate detection: if solution + bpm + rings match an existing file
## (ignoring ID), warn instead of saving.

const SAVE_DIR: String = "res://core/levels/dev/"

signal file_added(file_name: String)

@onready var _id_label: Label = $Panel/Form/ID
@onready var _name_field: LineEdit = $Panel/Form/Name
@onready var _bpm_field: LineEdit = $Panel/Form/BPM
@onready var _ring0_interval: OptionButton = $Panel/Form/Ring0Interval
@onready var _ring1_interval: OptionButton = $Panel/Form/Ring1Interval
@onready var _ring2_interval: OptionButton = $Panel/Form/Ring2Interval
@onready var _solution_field: TextEdit = $Panel/Form/Solution
@onready var _save_btn: Button = $Panel/Form/Save
@onready var _close_btn: Button = $Panel/Form/Close
@onready var _status_label: Label = $Panel/Form/Status

var _pending_data: Dictionary = {}

var _saved_files: Array[Dictionary] = []

func _ready() -> void:
	visible = false
	_save_btn.pressed.connect(_on_save_pressed)
	_close_btn.pressed.connect(_on_close_pressed)
	_status_label.text = ""
	_read_save_dir()

## Called by Sequencer export() with the current state.
## solution: the 16-element solution array
## bpm: current BPM
## rings: Array of Dictionaries with keys "interval" (String)
func present(solution: Array, bpm: float, rings: Array) -> void:
	_pending_data = {
		"solution": solution,
		"bpm": bpm,
		"rings": rings
	}
	var next_id: int = _next_id()
	_id_label.text = "Level ID: %03d" % next_id
	_name_field.text = ""
	_bpm_field.text = str(bpm)
	var interval_buttons: Array[OptionButton] = [_ring0_interval, _ring1_interval, _ring2_interval]
	for i: int in range(interval_buttons.size()):
		var btn := interval_buttons[i]
		if btn.item_count == 0:
			btn.add_item("QUARTER", Ring.IntervalType.QUARTER)
			btn.add_item("EIGHTH", Ring.IntervalType.EIGHTH)
			btn.add_item("SIXTEENTH", Ring.IntervalType.SIXTEENTH)
		if i < rings.size():
			# rings[i]["interval"] is a String like "QUARTER"
			var interval_str: String = rings[i]["interval"]
			var idx: int = Ring.IntervalType.keys().find(interval_str)
			btn.select(idx if idx != -1 else 0)
	_solution_field.text = JSON.stringify(solution)
	_status_label.text = ""
	visible = true
	_name_field.grab_focus()

func _on_save_pressed() -> void:
	_status_label.text = ""
	var level_name: String = _name_field.text.strip_edges()
	if level_name.is_empty():
		_status_label.text = "Level name is required."
		return

	# Re-read fields in case developer changed them
	var bpm_val: float = _bpm_field.text.to_float()
	if bpm_val <= 0.0:
		_status_label.text = "BPM must be a positive number."
		return
		
	var rings_data: Array = []
	for btn: OptionButton in [_ring0_interval, _ring1_interval, _ring2_interval]:
		rings_data.append({
			"interval": Ring.IntervalType.keys()[btn.selected]
		})
	
	var solution_parsed = JSON.parse_string(_solution_field.text)
	if solution_parsed == null or not solution_parsed is Array:
		_status_label.text = "Solution JSON is invalid."
		return

	var data: Dictionary = {
		"name": level_name,
		"bpm": bpm_val,
		"rings": rings_data,
		"solution": solution_parsed
	}

	# Check for duplicate content (ignoring ID and name)
	if _is_duplicate(data):
		_status_label.text = "Duplicate level. Change properties to save."
		return

	var new_id: int = _next_id()
	var id_str: String = "%03d" % new_id
	var safe_name: String = level_name.to_lower().replace(" ", "_")
	var filename: String = "%s_%s.json" % [id_str, safe_name]
	var full_path: String = SAVE_DIR + filename

	# Handle duplication of exact filename
	if FileAccess.file_exists(full_path):
		var suffix: int = 1
		while FileAccess.file_exists(SAVE_DIR + "%s_%s_%d.json" % [id_str, safe_name, suffix]):
			suffix += 1
		filename = "%s_%s_%d.json" % [id_str, safe_name, suffix]
		full_path = SAVE_DIR + filename

	data["id"] = new_id

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var file := FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		_status_label.text = "Failed to write file. Check save directory."
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_saved_files.append({"fileName": filename, "fileContent": data})

	_status_label.text = "Level saved to %s" % full_path
	file_added.emit(filename)

func _on_close_pressed() -> void:
	_pending_data = {}
	_status_label.text = ""
	visible = false

func _read_save_dir() -> void:
	_saved_files = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var file_details: Dictionary = { "fileName": fname, "fileContent": null }
			var path: String = SAVE_DIR + fname
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var existing = JSON.parse_string(file.get_as_text())
				file.close()
				if existing is Dictionary:
					file_details["fileContent"] = existing
					
			_saved_files.append(file_details)
		fname = dir.get_next()
	dir.list_dir_end()

## Returns the next available 3-digit ID by scanning existing files.
func _next_id() -> int:
	var highest: int = -1
	for file in _saved_files:
		var file_name = file["fileName"]
		var parts: PackedStringArray = file_name.split("_", false, 1)
		if parts.size() >= 1 and parts[0].is_valid_int():
			var id: int = parts[0].to_int()
			if id > highest:
				highest = id

	return highest + 1

## Returns true if any existing file has the same solution, bpm, and rings
## (content match ignoring id and name).
func _is_duplicate(candidate: Dictionary) -> bool:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	
	for file in _saved_files:
		var existing = file["fileContent"]
		if existing is Dictionary:
			if (
				JSON.stringify(existing.get("solution")) == JSON.stringify(candidate["solution"])
				and existing.get("bpm") == candidate["bpm"]
				and JSON.stringify(existing.get("rings")) == JSON.stringify(candidate["rings"])
			):
				return true
	return false
