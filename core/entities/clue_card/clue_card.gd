class_name ClueCard
extends Node2D

signal dismiss_complete
signal became_active
signal clue_note_triggered(note_count: int)

enum State { HIDDEN, PRESENTING, MINIMIZED, INSPECTING }

const OUTLINE_SHADER: Shader = preload("res://core/entities/clue_card/outline.gdshader")

@export var slide_in_offset: Vector2 = Vector2(0.0, 800.0)
@export var slide_in_duration: float = 0.5
@export var display_duration: float = 1.0
@export var minimized_position: Vector2 = Vector2.ZERO
@export var minimized_scale: Vector2 = Vector2(0.5, 0.5)
@export var minimize_duration: float = 0.5

@onready var _sprite: Sprite2D = $Sprite
@onready var _area: Area2D = $Area
@onready var _constellation: ConstellationHintDisplay = $Keys/Constellation

var _pile_position: Vector2 = Vector2.ZERO
var _present_position: Vector2 = Vector2.ZERO
var _dismissed: bool = false
var _tween: Tween = null
var _state: State = State.HIDDEN
var _base_z_index: int = 0
var _is_hovered: bool = false
var _outline_material: ShaderMaterial = null

var _solution: Array = []
var _tick_duration: float = 0.125
var _start_tick: int = 0
var _measure_pos: int = 0
var _clock_t: float = 0.0
var _clock_running: bool = false

func _ready() -> void:
	visible = false
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	await get_tree().process_frame
	_area.input_event.connect(_on_area_input_event)
	_area.mouse_entered.connect(_on_mouse_entered)
	_area.mouse_exited.connect(_on_mouse_exited)

## Called by Clues whenever this card's slot in the pile changes.
func set_pile_position(pos: Vector2) -> void:
	_pile_position = pos
	if _state == State.MINIMIZED:
		var target := _pile_position + minimized_position
		if _tween != null and _tween.is_running():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "position", target, minimize_duration) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	elif _state == State.HIDDEN:
		position = _pile_position + minimized_position

## present_pos is in parent (Clues) local space — the shared centre where cards float to.
func setup(solution: Array, present_pos: Vector2, measure_duration: float) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_stop_clock()
	_solution = solution
	_tick_duration = measure_duration / 16.0 if measure_duration > 0.0 else 0.125
	_start_tick = _find_start_tick()
	_present_position = present_pos
	_dismissed = false
	_state = State.HIDDEN
	scale = Vector2.ONE
	_constellation.setup(solution)

func present() -> void:
	_state = State.PRESENTING
	_update_outline()
	became_active.emit()
	_start_clock()
	await get_tree().process_frame
	position = _present_position + slide_in_offset
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", _present_position, slide_in_duration) \
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
	became_active.emit()
	_start_clock()
	_base_z_index = z_index
	z_index = _base_z_index + 10
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", _present_position, minimize_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "scale", Vector2.ONE, minimize_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

func _minimize() -> void:
	_stop_clock()
	_state = State.MINIMIZED
	_update_outline()
	z_index = _base_z_index
	if _tween != null and _tween.is_running():
		_tween.kill()
	var target_pos: Vector2 = _pile_position + minimized_position
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", target_pos, minimize_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "scale", minimized_scale, minimize_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(func() -> void:
		dismiss_complete.emit()
	)

func _process(delta: float) -> void:
	if not _clock_running:
		return
	_clock_t += delta
	while _clock_t >= _tick_duration:
		_clock_t -= _tick_duration
		_fire_current_tick()

func _start_clock() -> void:
	_measure_pos = 0
	_clock_t = 0.0
	_clock_running = true

func _stop_clock() -> void:
	_clock_running = false

func _find_start_tick() -> int:
	for tick: int in range(_solution.size()):
		if not (_solution[tick] as Array).is_empty():
			return (tick - 2 + 16) % 16
	return 0

func _fire_current_tick() -> void:
	var actual_tick: int = (_start_tick + _measure_pos) % 16
	_measure_pos = (_measure_pos + 1) % 16
	if actual_tick >= _solution.size():
		return
	var notes: Array = _solution[actual_tick]
	if notes.is_empty():
		return
	clue_note_triggered.emit(notes.size())
	_constellation.flash_at_tick(actual_tick)

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	match _state:
		State.PRESENTING:
			dismiss()
			get_viewport().set_input_as_handled()
		State.MINIMIZED:
			inspect()
			get_viewport().set_input_as_handled()
		State.INSPECTING:
			dismiss()
			get_viewport().set_input_as_handled()

func _update_outline() -> void:
	_sprite.material = _outline_material if (_state == State.MINIMIZED and _is_hovered) else null

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_outline()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_outline()
