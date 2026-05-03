extends Node

var currentIngredient = null

@export var ingredient_scene: PackedScene

var totalIngredients = randi() % 50 + 5
var ingredientsOnPlate = []

var orderIngredients = randi() % 4 + 2


func add_order():
	var radius = $Pizzas/OrderPizza/CollisionShape2D.get_shape().radius * .3
	for i in orderIngredients:
		var ingred = ingredient_scene.instantiate()
		ingred.scale = Vector2(ingred.scale.x * .6, ingred.scale.y * .6)
		ingred.position = getRandomPos(radius, $Pizzas/OrderPizza.position)
		add_child(ingred)
		$Pizzas/OrderPizza.ingredients.append(ingred)
	$Order.show()
	$Pizzas/OrderPizza.show()
	pass

func getRandomPos(radius, initPos):
	var vec = (Vector2.RIGHT * randf_range(0, radius)).rotated(randf_range(-PI, PI))
	var rand_point = initPos + vec
	return rand_point

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	totalIngredients = max(totalIngredients, orderIngredients)
	$Order.hide()
	$Pizzas/OrderPizza.hide()
	var radius = $Plate/CollisionShape2D.get_shape().radius
	for i in totalIngredients:
		var ingred = ingredient_scene.instantiate()
		ingred.position = getRandomPos(radius, $Plate.position)
		add_child(ingred)
		ingredientsOnPlate.append(ingred)
	self.add_order()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_plate_ingredient_add(type) -> void:
	print('plate click')
	currentIngredient = type


func _on_pizza_pizza_clicked(pos) -> void:
	print('pizza click at ', pos, currentIngredient)
	if currentIngredient and totalIngredients > 0:
		totalIngredients -= 1
		var ingred = ingredientsOnPlate.pop_back()
		ingred.position = pos
		$Pizzas/Pizza.ingredients.append(ingred)
		if not Input.is_key_pressed(KEY_SHIFT):
			currentIngredient = null
		if totalIngredients <= 0:
			currentIngredient = null
			$Plate.hide()
