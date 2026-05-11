class_name LevelSelectItem
extends Area2D

signal selected(index: int)

## Pool of star textures to randomly sample from. Assign in Inspector.
@export var star_textures: Array[Texture2D] = []
## Display scale applied to each star sprite (stars are 2x res, so ~0.2 halves them).
@export var star_scale_min: float = 0.15
@export var star_scale_max: float = 0.3
@export var star_color: Color = Color(1.0, 1.0, 1.0, 0.85)
## Radius (pixels) to scale the normalized constellation points into.
@export var constellation_radius: float = 80.0
## Modulate applied to the container sprite when the level is completed.
@export var completed_color: Color = Color(1.0, 0.92, 0.3, 1.0)

@onready var _sprite: Sprite2D = $Sprite

var _level_index: int = 0

func _ready() -> void:
	input_event.connect(_on_input_event)

## Assigns the level index and spawns star sprites from normalized constellation points.
## Points are in [-1, 1] range, scaled by constellation_radius.
func setup(level_index: int, constellation_points: Array[Vector2]) -> void:
	_level_index = level_index
	_spawn_stars(constellation_points)

func set_completed(done: bool) -> void:
	_sprite.modulate = completed_color if done else Color.WHITE

func _spawn_stars(points: Array[Vector2]) -> void:
	if star_textures.is_empty():
		return
	for p: Vector2 in points:
		var star := Sprite2D.new()
		star.texture = star_textures[randi() % star_textures.size()]
		var scale_val: float = randf_range(star_scale_min, star_scale_max)
		star.scale = Vector2(scale_val, scale_val)
		star.rotation = randf_range(0.0, TAU)
		star.position = p * constellation_radius
		star.modulate = star_color
		add_child(star)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(_level_index)
