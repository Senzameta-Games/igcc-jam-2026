class_name Clues
extends Node2D

const CLUE_CARD_SCENE: PackedScene = preload("res://core/entities/clue_card/clue_card.tscn")

## Position in Clues-node local space where each card slides in and rests for display.
## Default centers the card on screen: Clues origin (960,1001) + (0,-412) = DeskLayer (960,589).
@export var present_position: Vector2 = Vector2(0.0, -412.0)
## Y position of the pile row in Clues-node local space.
## Default: Clues origin y(1001) + (-151) = DeskLayer y(850).
@export var pile_y: float = -151.0
## Gap in pixels between each card center in the pile.
@export var pile_gap: float = 64.0

var _cards: Array[ClueCard] = []
var _pending_solution: Array = []
var _has_pending: bool = false

func queue_clue(solution: Array) -> void:
	_pending_solution = solution
	_has_pending = true

func on_desk_settled() -> void:
	if not _has_pending:
		return
	_has_pending = false
	_spawn_card(_pending_solution)

func _spawn_card(solution: Array) -> void:
	var card := CLUE_CARD_SCENE.instantiate() as ClueCard
	card.position = present_position
	_cards.append(card)
	add_child(card)
	_redistribute()
	card.setup(solution)
	card.present()

func _redistribute() -> void:
	var total: int = _cards.size()
	for i: int in range(total):
		var new_minimized: Vector2 = _pile_position(i, total) - present_position
		_cards[i].reposition_in_pile(new_minimized)

func _pile_position(index: int, total: int) -> Vector2:
	var group_width: float = float(total - 1) * pile_gap
	var x: float = -group_width * 0.5 + float(index) * pile_gap
	return Vector2(x, pile_y)
