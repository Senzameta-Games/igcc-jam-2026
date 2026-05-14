class_name LevelSelectItem
extends Area2D

signal selected(index: int)

## Modulate applied to the container sprite when the level is completed.
@export var completed_color: Color = Color(1.0, 0.92, 0.3, 1.0)
@export var locked_color: Color = Color(0.25, 0.25, 0.25, 1.0)

## Hover: shader applied to each star (assign key_star.gdshader in Inspector).
@export var hover_shader: Shader = null
## How much each star scales up individually on hover (multiplier on its base scale).
@export var hover_scale_multiplier: float = 1.5
## Duration of the hover scale tween in seconds.
@export var hover_tween_duration: float = 0.15

@onready var _sprite: Sprite2D = $Sprite
@onready var _constellation: ConstellationDisplay = $Constellation

var _level_index: int = 0
var _hover_tween: Tween = null
var _locked: bool = true
var _completed: bool = false
var _hover_material: ShaderMaterial = null

func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## Assigns the level index and spawns star sprites from normalized constellation points.
## Points are in [-1, 1] range, scaled by the child ConstellationDisplay's constellation_radius.
func setup(level_index: int, constellation_points: Array[Vector2]) -> void:
	_level_index = level_index
	_constellation.setup(constellation_points)

func set_locked(locked: bool) -> void:
	_locked = locked
	_refresh_modulate()

func set_completed(done: bool) -> void:
	_completed = done
	_refresh_modulate()
	_set_hover(done)

func _refresh_modulate() -> void:
	if _completed:
		_sprite.modulate = completed_color
	elif _locked:
		_sprite.modulate = locked_color
	else:
		_sprite.modulate = Color.WHITE
	_constellation.modulate = Color(0.15, 0.15, 0.15, 1.0) if _locked else Color.WHITE

func _on_mouse_entered() -> void:
	if not _locked:
		_set_hover(true)

func _on_mouse_exited() -> void:
	if not _locked and not _completed:
		_set_hover(false)

func _set_hover(active: bool) -> void:
	if _hover_tween != null and _hover_tween.is_running():
		_hover_tween.kill()
	var mat: ShaderMaterial = null
	if active and hover_shader != null:
		if _hover_material == null:
			_hover_material = ShaderMaterial.new()
			_hover_material.shader = hover_shader
		mat = _hover_material
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.set_trans(Tween.TRANS_BACK)
	for i: int in range(_constellation.stars.size()):
		var star: Sprite2D = _constellation.stars[i]
		var target_scale: Vector2 = _constellation.star_base_scales[i] * (hover_scale_multiplier if active else 1.0)
		star.material = mat
		_hover_tween.tween_property(star, "scale", target_scale, hover_tween_duration)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _locked:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(_level_index)
