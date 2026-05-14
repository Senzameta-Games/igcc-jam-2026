class_name ConstellationDisplay
extends Node2D

@export var star_textures: Array[Texture2D] = []
@export var star_scale_min: float = 0.15
@export var star_scale_max: float = 0.3
@export var star_color: Color = Color.WHITE
@export var constellation_radius: float = 80.0

@export var line_star_spacing: float = 12.0
@export var line_star_scale_min: float = 0.06
@export var line_star_scale_max: float = 0.10
@export var line_star_color: Color = Color(1.0, 1.0, 1.0, 0.5)
## Maximum segment length (in post-radius pixels) before the line is omitted.
## 0 = no limit — all sequential points are connected.
@export var max_line_distance: float = 0.0

var stars: Array[Sprite2D] = []
var star_base_scales: Array[Vector2] = []

func setup(points: Array[Vector2]) -> void:
	clear()
	if star_textures.is_empty():
		return

	var scaled: Array[Vector2] = []
	for p: Vector2 in points:
		scaled.append(p * constellation_radius)

	for i: int in range(scaled.size() - 1):
		var a: Vector2 = scaled[i]
		var b: Vector2 = scaled[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len < 0.001 or (max_line_distance > 0.0 and seg_len > max_line_distance):
			continue
		var steps: int = int(seg_len / line_star_spacing)
		for s: int in range(1, steps):
			var t: float = float(s) / float(steps)
			var dot := Sprite2D.new()
			dot.texture = star_textures[randi() % star_textures.size()]
			var scale_val: float = randf_range(line_star_scale_min, line_star_scale_max)
			dot.scale = Vector2(scale_val, scale_val)
			dot.rotation = randf_range(0.0, TAU)
			dot.position = a.lerp(b, t)
			dot.modulate = line_star_color
			add_child(dot)

	for p: Vector2 in scaled:
		var star := Sprite2D.new()
		star.texture = star_textures[randi() % star_textures.size()]
		var scale_val: float = randf_range(star_scale_min, star_scale_max)
		star.scale = Vector2(scale_val, scale_val)
		star.rotation = randf_range(0.0, TAU)
		star.position = p
		star.modulate = star_color
		add_child(star)
		stars.append(star)
		star_base_scales.append(star.scale)

func clear() -> void:
	for child: Node in get_children():
		child.queue_free()
	stars.clear()
	star_base_scales.clear()
