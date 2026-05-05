class_name Detector
extends Area2D

signal orb_passed(orb_id: StringName, texture: Texture2D, from_pos: Vector2, ring_idx: int)
 
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 0.8)
@export var flash_duration: float = 0.12
@export var ring_idx: int = 0
 
@onready var _sprite: Sprite2D = $Sprite
 
func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)
	Playback.stopped.connect(_on_playback_stopped)
	Playback.started.connect(_on_playback_started)
 
func _on_area_entered(area: Area2D) -> void:
	var orb := area.get_parent() as Orb
	if orb == null:
		return
	orb.play_note()
	orb_passed.emit(orb.orb_id, orb.texture, global_position, ring_idx)
	_flash()
 
func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", flash_color, 0.0)
	tween.tween_property(_sprite, "modulate", Color.WHITE, flash_duration)

func _on_playback_stopped() -> void:
	monitoring = false

func _on_playback_started() -> void:
	monitoring = true
