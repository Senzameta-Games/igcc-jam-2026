class_name ClueCard
extends Node2D

signal keys_launched
signal dismiss_complete

@export var slide_in_offset: Vector2 = Vector2(0.0, 800.0)
@export var slide_in_duration: float = 0.5
@export var minimized_position: Vector2 = Vector2(-120.0, 0.0)
@export var minimized_scale: Vector2 = Vector2(0.5, 0.5)
@export var minimize_duration: float = 0.5
@export var key_launch_duration: float = 0.8
@export var key_launch_stagger: float = 0.08
@export var key_launch_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var key_launch_trans: Tween.TransitionType = Tween.TRANS_CUBIC

@onready var _keys_container: Node2D = $Keys
@onready var _sprite: Sprite2D = $Sprite
@onready var _area: Area2D = $Area

var _piano_roll: PianoRoll = null
var _piano_roll_keys: Node2D = null
var _solution: Array = []
var _resting_position: Vector2 = Vector2.ZERO
var _dismissed: bool = false

func _ready() -> void:
	visible = false
	await get_tree().process_frame
	_resting_position = global_position
	_area.input_event.connect(_on_area_input_event)

func setup(piano_roll: PianoRoll, solution: Array, piano_roll_keys: Node2D) -> void:
	_piano_roll = piano_roll
	_piano_roll_keys = piano_roll_keys
	_solution = solution
	_dismissed = false
	scale = Vector2.ONE
	global_position = _resting_position
	for child: Node in _keys_container.get_children():
		var key := child as Sprite2D
		if key == null:
			continue
		key.modulate = Color.BLACK

func present() -> void:
	await get_tree().process_frame
	global_position = _resting_position + slide_in_offset
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", _resting_position, slide_in_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "modulate:a", 1.0, slide_in_duration * 0.6)

func get_key_count() -> int:
	return _keys_container.get_child_count()

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		dismiss()

func dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true

	# Build targets now, when the sky layer is at its final resting rotation
	var key_targets: Array[Vector2] = _build_key_targets()

	if key_targets.is_empty() or _piano_roll_keys == null:
		_minimize()
		return

	var keys: Array[Node] = _keys_container.get_children()
	var launch_count: int = mini(keys.size(), key_targets.size())
	var completed: int = 0
	for i: int in range(launch_count):
		var original := keys[i] as Sprite2D
		if original == null:
			completed += 1
			continue
		var start_pos: Vector2 = original.global_position
		var target: Vector2 = key_targets[i]
		var delay: float = i * key_launch_stagger

		var dupe := Sprite2D.new()
		dupe.texture = original.texture
		dupe.modulate = Color.WHITE
		dupe.z_index = 15
		dupe.position = _piano_roll_keys.to_local(start_pos)
		dupe.scale = original.scale
		_piano_roll_keys.add_child(dupe)  # add AFTER setting position
		var local_target: Vector2 = _piano_roll_keys.to_local(target)
		var tween := dupe.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(dupe, "position", local_target, key_launch_duration) \
			.set_ease(key_launch_ease) \
			.set_trans(key_launch_trans)
		tween.tween_callback(func() -> void:
			dupe.z_index = -1
			completed += 1
			if completed >= launch_count:
				keys_launched.emit()
		)
	_minimize()

func _minimize() -> void:
	var target_pos: Vector2 = _resting_position + minimized_position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_pos, minimize_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", minimized_scale, minimize_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func() -> void:
		dismiss_complete.emit()
	)

func _build_key_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	var key_count: int = _keys_container.get_child_count()
	for tick: int in range(_solution.size()):
		if targets.size() >= key_count:
			break
		for entry: Variant in (_solution[tick] as Array):
			if targets.size() >= key_count:
				break
			var pair := entry as Array
			var ring_idx: int = pair[0]
			targets.append(_piano_roll.get_cell_position(tick, ring_idx))
	return targets
