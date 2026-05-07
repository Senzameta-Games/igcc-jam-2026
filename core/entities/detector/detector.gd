class_name Detector
extends Area2D

signal orb_passed(orb_id: Orb.OrbType, texture: Texture2D, from_pos: Vector2)

@export var flash_color: Color = Color(1.0, 1.0, 1.0, 0.8)
@export var flash_duration: float = 0.12

@onready var _sprite: Sprite2D = $Sprite

var _world_position: Vector2

func _ready() -> void:
	await get_tree().process_frame
	_world_position = global_position
	monitoring = false
	area_entered.connect(_on_area_entered)
	Playback.stopped.connect(_on_playback_stopped)
	Playback.started.connect(_on_playback_started)

func _process(_delta: float) -> void:
	global_rotation = 0.0
	global_position = _world_position

func _on_area_entered(area: Area2D) -> void:
	var orb := area.get_parent() as Orb
	if orb == null:
		return
	orb.play_note()
	orb_passed.emit(orb.orb_id, orb.texture, global_position)
	_flash()

func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", flash_color, 0.0)
	tween.tween_property(_sprite, "modulate", Color.WHITE, flash_duration)

func _on_playback_stopped() -> void:
	monitoring = false

func _on_playback_started() -> void:
	monitoring = true
