class_name KeyStar
extends Node2D

const _TEXTURES: Dictionary = {
	Orb.OrbType.Bb3: preload("res://core/assets/stars/keys/Bb.png"),
	Orb.OrbType.F3:  preload("res://core/assets/stars/keys/F.png"),
	Orb.OrbType.G3:  preload("res://core/assets/stars/keys/G.png"),
	Orb.OrbType.A4:  preload("res://core/assets/stars/keys/A.png"),
	Orb.OrbType.D4:  preload("res://core/assets/stars/keys/D.png"),
}

const _COLORS: Dictionary = {
	Orb.OrbType.Bb3: Color(0.165, 0.545, 0.220, 1.0),
	Orb.OrbType.F3:  Color(0.545, 0.118, 0.118, 1.0),
	Orb.OrbType.G3:  Color(0.831, 0.573, 0.039, 1.0),
	Orb.OrbType.A4:  Color(0.482, 0.184, 0.722, 1.0),
	Orb.OrbType.D4:  Color(0.082, 0.722, 0.784, 1.0),
}

@onready var _sprite: Sprite2D = $Sprite

func setup(orb_type: Orb.OrbType, shader: Shader = null) -> void:
	_sprite.texture = _TEXTURES.get(orb_type) as Texture2D
	modulate = _COLORS.get(orb_type, Color.WHITE)
	if shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_sprite.material = mat
