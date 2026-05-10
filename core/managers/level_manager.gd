class_name LevelManager
extends Node
## LevelManager orchestrates the full level lifecycle:
## loading level data, configuring the sequencer rings, populating the tray,
## building clue card key targets, and sequencing the intro flow.
##
## Main wires node references in via initialize(), then calls load_level().
## Anything a level cares about flows through here.
##
## Long-term: level_data will come from a level index and loading pipeline.
## For now it's a single JSON export for development.
signal level_loaded
signal level_ready
signal all_levels_complete

const LEVELS_DIR: String = "res://core/levels/dev/"

var _sequencer: Sequencer = null
var _tray: Tray = null
var _piano_roll: PianoRoll = null
var _clue_card: ClueCard = null

var _level_files: Array[String] = []
var _current_index: int = 0

## Called by Main after all nodes are ready.
func initialize(
	sequencer: Sequencer,
	tray: Tray,
	piano_roll: PianoRoll,
	clue_card: ClueCard
) -> void:
	_sequencer = sequencer
	_tray = tray
	_piano_roll = piano_roll
	_clue_card = clue_card
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

## Entry point for loading and presenting a level.
## Pass a data dictionary directly, or omit to use the exported level_data.
func load_level() -> void:
	if _level_files.is_empty():
		push_error("LevelManager: no level files found in %s" % LEVELS_DIR)
		return
	_current_index = 0
	_load_file(_level_files[_current_index])

## Advances to the next level. Call after sky transition completes.
## Emits all_levels_complete if no more levels remain.
func load_next_level() -> void:
	_current_index += 1
	if _current_index >= _level_files.size():
		all_levels_complete.emit()
		return
	_load_file(_level_files[_current_index])

## Loads a specific level by passing raw data used by dev tools load button.
func load_level_data(data: Dictionary) -> void:
	_present_level(data)

## Returns the current level index (0-based).
func current_index() -> int:
	return _current_index

## Returns total number of levels found.
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
	var piano_roll_keys: Node2D = _piano_roll.get_node("Keys") as Node2D
	var unique_orbs: Array[Orb.OrbType] = _tray.get_unique_orbs()
	_clue_card.setup(_piano_roll, data["solution"], unique_orbs, piano_roll_keys)
	level_loaded.emit()
	_clue_card.present()
	level_ready.emit()

## Clears all rings and populates slots from solution data.
## solution is a 16-element array where each entry is an array of OrbType ints.
## Ring order in solution: index 0 = outermost ring, index 2 = innermost ring.
func _load_game(json_data: Dictionary) -> void:
	_sequencer.eject_orbs()

func _load_solution(json_data: Dictionary) -> void:
	_sequencer.eject_orbs()
	var rings: Array[Ring] = _sequencer.get_rings()
	var solution: Array = json_data["solution"]
	for index: int in range(solution.size()):
		var orb_arr: Array = solution[index]
		match orb_arr.size():
			1:
				_add_orb_to_slot(rings[2].slot_at_modified_index(index), orb_arr[0])
			2:
				_add_orb_to_slot(rings[2].slot_at_modified_index(index), orb_arr[0])
				_add_orb_to_slot(rings[1].slot_at_modified_index(index), orb_arr[1])
			3:
				_add_orb_to_slot(rings[2].slot_at_modified_index(index), orb_arr[0])
				_add_orb_to_slot(rings[1].slot_at_modified_index(index), orb_arr[1])
				_add_orb_to_slot(rings[0].slot_at_modified_index(index), orb_arr[2])

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

func _build_key_targets(solution: Array) -> Array[Vector2]:
	var targets: Array[Vector2] = []
	var unique_orbs: Array[Orb.OrbType] = _tray.get_unique_orbs()
	var key_count: int = _clue_card.get_key_count()

	# # Solution tick 0 = first slot detected = leftmost piano roll column.
	# Iterate forward so key stars are placed left to right matching detection order.

	for tick: int in range(solution.size()):
		if targets.size() >= key_count:
			break
		var orb_arr: Array = solution[tick]
		for orb_type_int: int in orb_arr:
			if targets.size() >= key_count:
				break
			var orb_id := orb_type_int as Orb.OrbType
			var note_row: int = unique_orbs.find(orb_id)
			if note_row == -1:
				continue
			targets.append(_piano_roll.get_cell_position(tick, orb_id))
	return targets
