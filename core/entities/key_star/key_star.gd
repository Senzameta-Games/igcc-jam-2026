class_name KeyStar
extends Node2D

const KEY_STAR_TEXTURES: Dictionary = {
	Orb.OrbType.Bb3: preload("res://core/assets/stars/keys/Bb.png"),
	Orb.OrbType.F3:  preload("res://core/assets/stars/keys/F.png"),
	Orb.OrbType.G3:  preload("res://core/assets/stars/keys/G.png"),
	Orb.OrbType.A4:  preload("res://core/assets/stars/keys/A.png"),
	Orb.OrbType.D4:  preload("res://core/assets/stars/keys/D.png"),
}

const _COLORS: Dictionary = {
	Orb.OrbType.Bb3: Color(0.795, 0.998, 0.801, 1.0),
	Orb.OrbType.F3:  Color(0.997, 0.936, 0.929, 1.0),
	Orb.OrbType.G3:  Color(1.0, 0.949, 0.878, 1.0),
	Orb.OrbType.A4:  Color(0.963, 0.94, 0.995, 1.0),
	Orb.OrbType.D4:  Color(0.878, 0.985, 0.998, 1.0),
}

@onready var _sprite: Sprite2D = $Sprite

func setup(orb_type: Orb.OrbType, mat: ShaderMaterial = null) -> void:
	_sprite.texture = KEY_STAR_TEXTURES.get(orb_type) as Texture2D
	modulate = _COLORS.get(orb_type, Color.WHITE)
	_sprite.material = mat
