extends Area2D

signal pizza_clicked

var canBeClicked = true
@export var ingredients = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input_event(viewport, event, shape_idx):
	if canBeClicked and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		self.on_click(event.position)

func on_click(pos):
	emit_signal("pizza_clicked", pos)
