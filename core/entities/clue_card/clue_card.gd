class_name ClueCard
extends Node2D

signal dismiss_complete

@export var slide_in_offset: Vector2 = Vector2(0.0, 800.0)
@export var slide_in_duration: float = 0.5
@export var display_duration: float = 1.0
@export var minimized_position: Vector2 = Vector2(-120.0, 0.0)
@export var minimized_scale: Vector2 = Vector2(0.5, 0.5)
@export var minimize_duration: float = 0.5

@onready var _sprite: Sprite2D = $Sprite
@onready var _area: Area2D = $Area
@onready var _constellation: ConstellationHintDisplay = $Keys/Constellation

var _resting_position: Vector2 = Vector2.ZERO
var _dismissed: bool = false
var _tween: Tween = null

func _ready() -> void:
	visible = false
	await get_tree().process_frame
	_resting_position = position
	_area.input_event.connect(_on_area_input_event)

func setup(solution: Array) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_dismissed = false
	scale = Vector2.ONE
	position = _resting_position
	_constellation.setup(solution)

func present() -> void:
	await get_tree().process_frame
	position = _resting_position + slide_in_offset
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", _resting_position, slide_in_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(self, "modulate:a", 1.0, slide_in_duration * 0.6)
	_tween.chain().tween_interval(display_duration)
	_tween.chain().tween_callback(dismiss)

func dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	_minimize()

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		dismiss()

func _minimize() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	var target_pos: Vector2 = _resting_position + minimized_position
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", target_pos, minimize_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "scale", minimized_scale, minimize_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(func() -> void:
		dismiss_complete.emit()
	)
