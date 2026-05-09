class_name ClueCard
extends Node2D

signal keys_launched
signal dismiss_complete

@export var slide_in_offset: Vector2 = Vector2(-300.0, 0.0)
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

var _key_targets: Array[Vector2] = []
var _piano_roll_keys: Node2D = null
var _resting_position: Vector2 = Vector2.ZERO
var _dismissed: bool = false

func _ready() -> void:
	_resting_position = global_position
	visible = false
	_area.input_event.connect(_on_area_input_event)

func setup(key_targets: Array[Vector2], piano_roll_keys: Node2D) -> void:
	_key_targets = key_targets
	_piano_roll_keys = piano_roll_keys
	_dismissed = false
	scale = Vector2.ONE
	global_position = _resting_position
	for child: Node in _keys_container.get_children():
		var key := child as Sprite2D
		if key == null:
			continue
		key.modulate = Color.BLACK

func present() -> void:
	global_position = _resting_position + slide_in_offset
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", _resting_position, slide_in_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
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
	if _key_targets.is_empty() or _piano_roll_keys == null:
		_minimize()
		return
	var keys: Array[Node] = _keys_container.get_children()
	var launch_count: int = mini(keys.size(), _key_targets.size())
	var completed: int = 0
	for i: int in range(launch_count):
		var original := keys[i] as Sprite2D
		if original == null:
			completed += 1
			continue
		var dupe := Sprite2D.new()
		dupe.texture = original.texture
		dupe.modulate = Color.WHITE
		_piano_roll_keys.add_child(dupe)
		dupe.global_position = original.global_position
		dupe.scale = original.scale
		dupe.z_index = 12
		var target: Vector2 = _key_targets[i]
		var delay: float = i * key_launch_stagger
		var tween := dupe.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(dupe, "global_position", target, key_launch_duration) \
			.set_ease(key_launch_ease) \
			.set_trans(key_launch_trans)
		tween.tween_callback(func() -> void:
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
