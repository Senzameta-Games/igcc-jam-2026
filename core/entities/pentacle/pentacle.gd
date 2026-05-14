class_name Pentacle
extends Node2D

func _ready() -> void:
	var pearls_node: Node = get_node_or_null("Pearls")
	if pearls_node == null:
		return
	for child: Node in pearls_node.get_children():
		var slot := child as Slot
		if slot != null:
			slot.disabled = true

func on_mode_changed(mode: ConsoleMode.Mode) -> void:
	if mode == ConsoleMode.Mode.DESK:
		visible = true

## Returns a count of each OrbType held in the Pentacle that originated from level_index.
## Keys are int(OrbType). Filters by source_level so cross-level orbs don't
## deplete the wrong level's pool.
func get_orb_counts(level_index: int) -> Dictionary:
	var counts: Dictionary = {}
	_scan_node(self, counts, level_index)
	return counts

func _scan_node(node: Node, counts: Dictionary, level_index: int) -> void:
	for child: Node in node.get_children():
		var slot := child as Slot
		if slot != null and slot.is_occupied():
			var orb: Orb = slot.get_orb()
			if orb.source_level == level_index:
				var key: int = int(orb.orb_id)
				counts[key] = counts.get(key, 0) + 1
		_scan_node(child, counts, level_index)
