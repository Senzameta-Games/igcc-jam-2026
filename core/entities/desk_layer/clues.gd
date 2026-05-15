class_name Clues
extends Node2D

signal clue_active_changed(active: bool)

const CLUE_CARD_SCENE: PackedScene = preload("res://core/entities/clue_card/clue_card.tscn")

## Position in Clues-node local space where each card floats to when presenting or inspecting.
@export var present_position: Vector2 = Vector2(960.0, 540.0)
## Shared x position of the pile column in Clues-node local space.
@export var pile_x: float = 100.0
## Y position of the topmost card in the pile.
@export var pile_top_y: float = 200.0
## Vertical gap in pixels between each card center in the pile.
@export var pile_gap: float = 120.0
## Target opacity of the scrim while a card is presenting or being inspected.
@export var scrim_opacity: float = 0.2
@export var scrim_fade_duration: float = 0.3

@onready var _scrim: Sprite2D = $Scrim
@onready var _clue_note_player: AudioStreamPlayer = $ClueNote

var _cards: Array[ClueCard] = []
var _pending_solution: Array[LevelManager.SolutionData] = []
var _pending_measure_duration: float = 0.125
var _has_pending: bool = false
var _active_card_count: int = 0
var _scrim_tween: Tween = null

func clear() -> void:
	_has_pending = false
	for card: ClueCard in _cards:
		card.queue_free()
	_cards.clear()
	if _active_card_count > 0:
		clue_active_changed.emit(false)
	_active_card_count = 0
	_fade_scrim(0.0)

func queue_clue(solution: Array[LevelManager.SolutionData], measure_duration: float) -> void:
	_pending_solution = solution
	_pending_measure_duration = measure_duration
	_has_pending = true

func on_desk_settled() -> void:
	if not _has_pending:
		return
	_has_pending = false
	_spawn_card(_pending_solution, _pending_measure_duration)

func _spawn_card(solution: Array[LevelManager.SolutionData], measure_duration: float) -> void:
	var card := CLUE_CARD_SCENE.instantiate() as ClueCard
	_cards.append(card)
	add_child(card)
	_redistribute()
	card.became_active.connect(_on_card_became_active)
	card.dismiss_complete.connect(_on_card_dismiss_complete)
	card.clue_note_triggered.connect(_on_clue_note_triggered)
	card.setup(solution, present_position, measure_duration)
	card.present()

func _on_card_became_active() -> void:
	_active_card_count += 1
	if _active_card_count == 1:
		_fade_scrim(scrim_opacity)
		clue_active_changed.emit(true)

func _on_card_dismiss_complete() -> void:
	_active_card_count = maxi(_active_card_count - 1, 0)
	if _active_card_count == 0:
		_fade_scrim(0.0)
		clue_active_changed.emit(false)

func _on_clue_note_triggered(note_count: int) -> void:
	_clue_note_player.play()
	for i: int in range(note_count - 1):
		await get_tree().process_frame
		_clue_note_player.play()

func _fade_scrim(target_alpha: float) -> void:
	if _scrim_tween != null and _scrim_tween.is_running():
		_scrim_tween.kill()
	_scrim_tween = create_tween()
	_scrim_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_scrim_tween.tween_property(_scrim, "modulate:a", target_alpha, scrim_fade_duration)

func _redistribute() -> void:
	for i: int in range(_cards.size()):
		_cards[i].set_pile_position(_pile_position(i))

func _pile_position(index: int) -> Vector2:
	return Vector2(pile_x, pile_top_y + float(index) * pile_gap)
