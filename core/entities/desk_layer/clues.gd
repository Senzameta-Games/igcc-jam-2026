class_name Clues
extends Node2D

const CLUE_CARD_SCENE: PackedScene = preload("res://core/entities/clue_card/clue_card.tscn")

## Position in Clues-node local space where each card slides in and rests for display.
## Default centers the card on screen: Clues origin (960,1001) + (0,-412) = DeskLayer (960,589).
@export var present_position: Vector2 = Vector2(0.0, -412.0)
## Y position of the pile row in Clues-node local space.
## Default: Clues origin y(1001) + (-151) = DeskLayer y(850).
@export var pile_y: float = -151.0
## Left and right x bounds of the pile row in Clues-node local space.
## Defaults span DeskLayer x 200–1720 (Clues origin x is 960).
@export var pile_left_x: float = -760.0
@export var pile_right_x: float = 760.0
## Total slots — determines even distribution spacing regardless of how many cards exist yet.
@export var max_cards: int = 5
@export var card_z_index: int = 50

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
	var index: int = _cards.size()
	var card := CLUE_CARD_SCENE.instantiate() as ClueCard
	card.z_index = card_z_index
	card.z_as_relative = false
	card.position = present_position
	card.minimized_position = _pile_position(index) - present_position
	_cards.append(card)
	add_child(card)
	card.setup(solution)
	card.present()

func _pile_position(index: int) -> Vector2:
	var x: float
	if max_cards <= 1:
		x = (pile_left_x + pile_right_x) * 0.5
	else:
		x = lerpf(pile_left_x, pile_right_x, float(index) / float(max_cards - 1))
	return Vector2(x, pile_y)
