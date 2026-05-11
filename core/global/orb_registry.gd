extends Node

## Global registry mapping orb_id to its PackedScene.
## Any system that needs to spawn an orb calls OrbRegistry.spawn(orb_id).
## Add new orb types here as they are created.

const _scenes: Dictionary = {
	Orb.OrbType.Bb3: preload("res://core/entities/orbs/Bb3_orb.tscn"),
	Orb.OrbType.F3: preload("res://core/entities/orbs/F3_orb.tscn"),
	Orb.OrbType.G3: preload("res://core/entities/orbs/G3_orb.tscn"),
	Orb.OrbType.A4: preload("res://core/entities/orbs/A4_orb.tscn"),
	Orb.OrbType.Bb4: preload("res://core/entities/orbs/Bb4_orb.tscn"),
	Orb.OrbType.D4: preload("res://core/entities/orbs/D4_orb.tscn"),
	Orb.OrbType.F4: preload("res://core/entities/orbs/F4_orb.tscn"),
	Orb.OrbType.G4: preload("res://core/entities/orbs/G4_orb.tscn"),
}

func spawn(orb_id: Orb.OrbType) -> Orb:
	if not _scenes.has(orb_id):
		return null
	return _scenes[orb_id].instantiate() as Orb

func is_registered(orb_id: Orb.OrbType) -> bool:
	return _scenes.has(orb_id)
