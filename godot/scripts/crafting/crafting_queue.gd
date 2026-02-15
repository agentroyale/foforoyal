class_name CraftingQueue
extends Node
## FIFO crafting queue with timers. Max 8 items.

signal craft_started(recipe: RecipeData)
signal craft_completed(recipe: RecipeData)
signal craft_progress(recipe: RecipeData, progress: float)
signal queue_changed()

const MAX_QUEUE_SIZE := 8

var queue: Array[Dictionary] = []
var is_paused: bool = false
var player_inventory: PlayerInventory = null
var available_tier: RecipeData.WorkbenchTier = RecipeData.WorkbenchTier.HAND
var tech_tree: TechTree = null


func _process(delta: float) -> void:
	if is_paused or queue.is_empty():
		return

	var current: Dictionary = queue[0]
	var recipe: RecipeData = current["recipe"]
	current["elapsed"] += delta

	var progress := clampf(current["elapsed"] / recipe.craft_time, 0.0, 1.0)
	craft_progress.emit(recipe, progress)

	if current["elapsed"] >= recipe.craft_time:
		_complete_current()


func enqueue(recipe: RecipeData) -> CraftingSystem.CraftResult:
	if queue.size() >= MAX_QUEUE_SIZE:
		return CraftingSystem.CraftResult.INSUFFICIENT_INGREDIENTS

	var result := CraftingSystem.can_craft(recipe, player_inventory, available_tier, tech_tree)
	if result != CraftingSystem.CraftResult.SUCCESS:
		return result

	CraftingSystem.consume_ingredients(recipe, player_inventory)
	queue.append({"recipe": recipe, "elapsed": 0.0})

	if queue.size() == 1:
		craft_started.emit(recipe)

	queue_changed.emit()
	return CraftingSystem.CraftResult.SUCCESS


func cancel(index: int) -> bool:
	if index < 0 or index >= queue.size():
		return false
	var entry: Dictionary = queue[index]
	var recipe: RecipeData = entry["recipe"]

	for i in range(recipe.get_ingredient_count()):
		player_inventory.add_item_to_inventory(
			recipe.get_ingredient_item(i), recipe.get_ingredient_amount(i)
		)

	queue.remove_at(index)
	queue_changed.emit()
	return true


func pause() -> void:
	is_paused = true


func resume() -> void:
	is_paused = false


func get_queue_size() -> int:
	return queue.size()


func get_current_progress() -> float:
	if queue.is_empty():
		return 0.0
	var current: Dictionary = queue[0]
	var recipe: RecipeData = current["recipe"]
	return clampf(current["elapsed"] / recipe.craft_time, 0.0, 1.0)


func _complete_current() -> void:
	if queue.is_empty():
		return
	var entry: Dictionary = queue[0]
	var recipe: RecipeData = entry["recipe"]

	CraftingSystem.produce_output(recipe, player_inventory)
	craft_completed.emit(recipe)

	queue.pop_front()

	if not queue.is_empty():
		craft_started.emit(queue[0]["recipe"])

	queue_changed.emit()
