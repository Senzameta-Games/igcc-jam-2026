class_name LevelSelect
extends Node2D

signal level_selected(index: int)

var _items: Array[LevelSelectItem] = []

func _ready() -> void:
	for child: Node in get_children():
		var item := child as LevelSelectItem
		if item == null:
			continue
		_items.append(item)
		item.selected.connect(_on_item_selected)
	_set_items_active(false)

func setup(constellation_points_per_level: Array) -> void:
	for i: int in range(mini(_items.size(), constellation_points_per_level.size())):
		var pts: Array[Vector2] = constellation_points_per_level[i]
		_items[i].setup(i, pts)

func set_completed(index: int, done: bool) -> void:
	if index >= 0 and index < _items.size():
		_items[index].set_completed(done)

func set_locked(index: int, locked: bool) -> void:
	if index >= 0 and index < _items.size():
		_items[index].set_locked(locked)

func on_mode_changed(mode: ConsoleMode.Mode) -> void:
	_set_items_active(mode == ConsoleMode.Mode.LEVEL_SELECT)

func _set_items_active(active: bool) -> void:
	for item: LevelSelectItem in _items:
		item.monitoring = active
		item.monitorable = active

func _on_item_selected(index: int) -> void:
	level_selected.emit(index)
