extends Node

## Global registry mapping orb_id to its PackedScene.
## Any system that needs to spawn an orb calls OrbRegistry.spawn(orb_id).
## Add new orb types here as they are created.

const _scenes: Dictionary = {
	&"f3": preload("res://core/entities/orbs/F3_orb.tscn"),
	&"c4": preload("res://core/entities/orbs/C4_orb.tscn"),
	&"f4": preload("res://core/entities/orbs/F4_orb.tscn"),
	&"g4": preload("res://core/entities/orbs/G4_orb.tscn"),
}

func spawn(orb_id: StringName) -> Orb:
	if not _scenes.has(orb_id):
		return null
	return _scenes[orb_id].instantiate() as Orb

func is_registered(orb_id: StringName) -> bool:
	return _scenes.has(orb_id)
