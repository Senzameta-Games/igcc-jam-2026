class_name ClueCard
extends Node2D

signal dismiss_complete

enum State { HIDDEN, PRESENTING, MINIMIZED, INSPECTING }

const OUTLINE_SHADER: Shader = preload("res://core/entities/clue_card/outline.gdshader")

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
var _state: State = State.HIDDEN
var _base_z_index: int = 0
var _is_hovered: bool = false
var _outline_material: ShaderMaterial = null

func _ready() -> void:
	visible = false
	_resting_position = position
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	await get_tree().process_frame
	_area.input_event.connect(_on_area_input_event)
	_area.mouse_entered.connect(_on_mouse_entered)
	_area.mouse_exited.connect(_on_mouse_exited)

func setup(solution: Array) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_dismissed = false
	_state = State.HIDDEN
	scale = Vector2.ONE
	position = _resting_position
	_constellation.setup(solution)

func present() -> void:
	_state = State.PRESENTING
	_update_outline()
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

func inspect() -> void:
	_dismissed = false
	_state = State.INSPECTING
	_update_outline()
	_base_z_index = z_index
	z_index = _base_z_index + 10
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", _resting_position, minimize_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "scale", Vector2.ONE, minimize_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	match _state:
		State.PRESENTING:
			dismiss()
		State.MINIMIZED:
			inspect()
		State.INSPECTING:
			dismiss()

func _update_outline() -> void:
	_sprite.material = _outline_material if (_state == State.MINIMIZED and _is_hovered) else null

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_outline()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_outline()

func reposition_in_pile(new_minimized: Vector2) -> void:
	minimized_position = new_minimized
	if _state != State.MINIMIZED:
		return
	var target_pos: Vector2 = _resting_position + minimized_position
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", target_pos, minimize_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

func _minimize() -> void:
	_state = State.MINIMIZED
	_update_outline()
	z_index = _base_z_index
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
