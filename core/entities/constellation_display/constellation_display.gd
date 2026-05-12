class_name ConstellationDisplay
extends Node2D

@export var star_textures: Array[Texture2D] = []
@export var star_scale_min: float = 0.15
@export var star_scale_max: float = 0.3
@export var star_color: Color = Color.WHITE
@export var constellation_radius: float = 80.0

var stars: Array[Sprite2D] = []
var star_base_scales: Array[Vector2] = []

func setup(points: Array[Vector2]) -> void:
	clear()
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
		stars.append(star)
		star_base_scales.append(star.scale)

func clear() -> void:
	for child: Node in get_children():
		child.queue_free()
	stars.clear()
	star_base_scales.clear()
