class_name TechTree
extends RefCounted
## Tracks which recipes the player has unlocked. Costs scrap.

signal recipe_unlocked(recipe: RecipeData)

var unlocked_recipes: Array[RecipeData] = []
var scrap_item: ItemData = null


func is_unlocked(recipe: RecipeData) -> bool:
	if recipe.unlock_cost <= 0:
		return true
	return recipe in unlocked_recipes


func can_unlock(recipe: RecipeData, player_inv: PlayerInventory) -> bool:
	if is_unlocked(recipe):
		return false

	for prereq in recipe.requires_recipes:
		if not is_unlocked(prereq):
			return false

	if recipe.unlock_cost > 0 and scrap_item:
		if not player_inv.has_item(scrap_item, recipe.unlock_cost):
			return false

	return true


func unlock(recipe: RecipeData, player_inv: PlayerInventory) -> bool:
	if not can_unlock(recipe, player_inv):
		return false

	if recipe.unlock_cost > 0 and scrap_item:
		player_inv.remove_item(scrap_item, recipe.unlock_cost)

	unlocked_recipes.append(recipe)
	recipe_unlocked.emit(recipe)
	return true
