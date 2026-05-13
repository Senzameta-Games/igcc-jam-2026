class_name LevelManager
extends Node

signal level_loaded
signal level_ready
signal all_levels_complete

const LEVELS_DIR: String = "res://core/levels/dev/"

var _sequencer: Sequencer = null
var _tray: Tray = null
var _piano_roll: PianoRoll = null

var _level_files: Array[String] = []
var _current_index: int = 0

## Per-level tray snapshots. Saved when navigating away; restored on return.
## Key: level index (int). Value: Array from Tray.snapshot_slots().
var _tray_states: Dictionary = {}

## Per-level sequencer ring snapshots. Saved when navigating away; restored on return.
## Key: level index (int). Value: Array from Sequencer.snapshot_rings().
var _sequencer_states: Dictionary = {}

func initialize(sequencer: Sequencer, tray: Tray, piano_roll: PianoRoll) -> void:
	_sequencer = sequencer
	_tray = tray
	_piano_roll = piano_roll
	_scan_levels()

func get_level_filename(index: int) -> String:
	if index < 0 or index >= _level_files.size():
		return ""
	var path: String = _level_files[index]
	return path.get_file().get_basename()

func get_next_index() -> int:
	var next: int = _current_index + 1
	if next >= _level_files.size():
		return 0
	return next

func is_last_level() -> bool:
	return _current_index >= _level_files.size() - 1

func load_level() -> void:
	if _level_files.is_empty():
		push_error("LevelManager: no level files found in %s" % LEVELS_DIR)
		return
	_current_index = 0
	_load_file(_level_files[_current_index])

## Emits all_levels_complete if no more levels remain.
func load_next_level() -> void:
	_current_index += 1
	if _current_index >= _level_files.size():
		all_levels_complete.emit()
		return
	_load_file(_level_files[_current_index])

func load_level_data(data: Dictionary) -> void:
	_present_level(data)

func load_level_at_index(index: int) -> void:
	if index < 0 or index >= _level_files.size():
		return
	_tray_states[_current_index] = _tray.snapshot_slots()
	_sequencer_states[_current_index] = _sequencer.snapshot_rings()
	_current_index = index
	_load_file(_level_files[_current_index])

## Returns the parsed JSON data for a level without loading it.
## Returns empty Dictionary if the index is invalid or file can't be read.
func get_level_data_at_index(index: int) -> Dictionary:
	if index < 0 or index >= _level_files.size():
		return {}
	var file := FileAccess.open(_level_files[index], FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		return data
	return {}

func current_index() -> int:
	return _current_index

func level_count() -> int:
	return _level_files.size()

func _scan_levels() -> void:
	_level_files.clear()
	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		push_error("LevelManager: could not open levels directory: %s" % LEVELS_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			_level_files.append(LEVELS_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	_level_files.sort()

func _load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LevelManager: could not open level file: %s" % path)
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		push_error("LevelManager: invalid JSON in level file: %s" % path)
		return
	_present_level(data)

func _present_level(data: Dictionary) -> void:
	_piano_roll.clear_keys()
	_load_game(data)
	_piano_roll.setup(_tray)
	level_loaded.emit()
	level_ready.emit()

func _load_game(json_data: Dictionary) -> void:
	_sequencer.eject_orbs()
	_sequencer.bpm = 40.0
	if json_data.has("rings"):
		var rings: Array[Ring] = _sequencer.get_rings()
		var ring_data: Array = json_data["rings"]
		for i: int in range(rings.size()):
			var active: bool = i < ring_data.size()
			rings[i].set_active(active)
			if active:
				var interval_str: String = ring_data[i].get("interval", "QUARTER")
				rings[i].interval_type = Ring.IntervalType.get(interval_str, Ring.IntervalType.QUARTER)
	if _sequencer_states.has(_current_index):
		_sequencer.restore_rings(_sequencer_states[_current_index])
	if _tray_states.has(_current_index):
		_tray.restore_snapshot(_tray_states[_current_index])
	elif json_data.has("tray_orbs"):
		var raw: Array = json_data["tray_orbs"]
		var types: Array[Orb.OrbType] = []
		for id: Variant in raw:
			types.append(int(id) as Orb.OrbType)
		_tray.populate(types, _current_index)
	elif json_data.has("solution"):
		_tray.populate(_extract_orb_types(json_data["solution"]), _current_index)

func _extract_orb_types(solution: Array) -> Array[Orb.OrbType]:
	var counts: Dictionary = {}
	for tick_data: Variant in solution:
		for entry: Variant in (tick_data as Array):
			var orb_int: int = int(entry) if not (entry is Array) else int((entry as Array)[1])
			counts[orb_int] = counts.get(orb_int, 0) + 1
	var unique: Array = counts.keys()
	unique.sort_custom(func(a: int, b: int) -> bool: return a > b)
	var types: Array[Orb.OrbType] = []
	for orb_int: int in unique:
		for _i: int in range(counts[orb_int]):
			types.append(orb_int as Orb.OrbType)
	return types


func add_file_name(name: String) -> void:
	_level_files.append(LEVELS_DIR + name)
	_level_files.sort()
