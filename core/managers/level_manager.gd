class_name LevelManager
extends Node

signal level_loaded
signal level_ready
signal all_levels_complete

const LEVELS_DIR: String = "res://core/levels/dev/"

var _sequencer: DeskLayer = null
var _tray: Tray = null
var _piano_roll: PianoRoll = null

var _level_files: Array[String] = []
var _current_index: int = 0
var _unlocked: Array[bool] = []
var _completed: Array[bool] = []
var _clue_shown: Array[bool] = []

func initialize(sequencer: DeskLayer, tray: Tray, piano_roll: PianoRoll) -> void:
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

func load_level_file(path: String) -> void:
	_load_file(path)

func load_level_at_index(index: int) -> void:
	if index < 0 or index >= _level_files.size():
		return
	if not is_unlocked(index):
		return
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

func is_unlocked(index: int) -> bool:
	if index < 0 or index >= _unlocked.size():
		return false
	return _unlocked[index]

func unlock_level(index: int) -> void:
	if index >= 0 and index < _unlocked.size():
		_unlocked[index] = true

func is_completed(index: int) -> bool:
	if index < 0 or index >= _completed.size():
		return false
	return _completed[index]

func mark_completed(index: int) -> void:
	if index >= 0 and index < _completed.size():
		_completed[index] = true

func is_clue_shown(index: int) -> bool:
	if index < 0 or index >= _clue_shown.size():
		return false
	return _clue_shown[index]

func mark_clue_shown(index: int) -> void:
	if index >= 0 and index < _clue_shown.size():
		_clue_shown[index] = true

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
	_unlocked.resize(_level_files.size())
	_unlocked.fill(false)
	if not _unlocked.is_empty():
		_unlocked[0] = true
	_completed.resize(_level_files.size())
	_completed.fill(false)
	_clue_shown.resize(_level_files.size())
	_clue_shown.fill(false)

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

class RingData: 
	var interval: String = "QUARTER"
	
	func _init(dict: Dictionary) -> void:
		interval = dict['interval'] if dict.has('interval') else ''

class SolutionData:
	var rings: Array[SlotData]
	
	func _init(dict: Variant) -> void:
		var data_rings: Array
		if (dict is Array):
			data_rings = dict
		else:
			data_rings = dict['rings'] if dict.has('rings') else []
		rings = []
		for ring in data_rings:
			rings.append(SlotData.new(ring))
		
class SlotData:
	var orb_type: Orb.OrbType
	var ring: int
	var locked: bool = false
	
	func _init(dict: Variant) -> void:
		if (dict is Array):
			ring = dict[0]
			orb_type = dict[1]
			return
		orb_type = int(dict['orb_type']) as Orb.OrbType if dict.has('orb_type') else Orb.OrbType.F3
		ring = dict['ring'] if dict.has('ring') else 0
		locked = dict['locked'] if dict.has('locked') else false

class LevelData:
	var id: int
	var name: String
	var rings: Array[RingData]
	var tray_orbs: Array[Orb.OrbType]
	var solution: Array[SolutionData]
	
	func _init(dict: Dictionary) -> void:
		id = dict['id'] if dict.has('id') else -1
		name = dict['name'] if dict.has('name') else ''
		tray_orbs = []
		var dict_tray_orbs = dict['tray_orbs'] if dict.has('tray_orbs') else []
		
		var types: Array[Orb.OrbType] = []
		for id: Variant in dict_tray_orbs:
			types.append(int(id) as Orb.OrbType)
		
		var data_rings = dict['rings'] if dict.has('rings') else []
		rings = []
		for ring in data_rings:
			rings.append(RingData.new(ring))
		
		var data_solution = dict['solution'] if dict.has('solution') else []
		solution = []
		for sol in data_solution:
			solution.append(SolutionData.new(sol))



func _load_game(json_data: Dictionary) -> void:
	_sequencer.eject_orbs()
	_sequencer.bpm = 40.0
	var load_data = LevelData.new(json_data)
	if load_data.rings.size() > 0:
		var rings: Array[Ring] = _sequencer.get_rings()
		var ring_data: Array = load_data.rings
		for i: int in range(rings.size()):
			var active: bool = i < ring_data.size()
			rings[i].set_active(active)
			if active:
				var interval_str: String = ring_data[i].interval
				rings[i].interval_type = Ring.IntervalType.get(interval_str, Ring.IntervalType.QUARTER)
	if load_data.tray_orbs.size() > 0:
		var types: Array[Orb.OrbType] = []
		for id: Variant in load_data.tray_orbs:
			types.append(int(id) as Orb.OrbType)
		_tray.populate(types, _current_index)
	elif load_data.solution.size() > 0:
		_tray.populate(_extract_orb_types(load_data.solution), _current_index)

func _extract_orb_types(solution: Array[SolutionData]) -> Array[Orb.OrbType]:
	var counts: Dictionary = {}
	for tick_data: SolutionData in solution:
		for entry: SlotData in tick_data.rings:
			var orb_int: int = entry.orb_type
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
