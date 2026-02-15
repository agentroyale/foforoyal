class_name CraftingSystem
extends RefCounted
## Pure logic: validate and execute recipes against a PlayerInventory.

enum CraftResult {
	SUCCESS,
	INSUFFICIENT_INGREDIENTS,
	WORKBENCH_REQUIRED,
	RECIPE_LOCKED,
}


static func can_craft(
	recipe: RecipeData,
	player_inv: PlayerInventory,
	available_tier: RecipeData.WorkbenchTier = RecipeData.WorkbenchTier.HAND,
	tech_tree: TechTree = null
) -> CraftResult:
	if tech_tree and not tech_tree.is_unlocked(recipe):
		return CraftResult.RECIPE_LOCKED

	if recipe.workbench_tier > available_tier:
		return CraftResult.WORKBENCH_REQUIRED

	for i in range(recipe.get_ingredient_count()):
		var item := recipe.get_ingredient_item(i)
		var count := recipe.get_ingredient_amount(i)
		if not player_inv.has_item(item, count):
			return CraftResult.INSUFFICIENT_INGREDIENTS

	return CraftResult.SUCCESS


static func consume_ingredients(recipe: RecipeData, player_inv: PlayerInventory) -> bool:
	## Remove all ingredients. Call can_craft() first.
	for i in range(recipe.get_ingredient_count()):
		var item := recipe.get_ingredient_item(i)
		var count := recipe.get_ingredient_amount(i)
		player_inv.remove_item(item, count)
	return true


static func produce_output(recipe: RecipeData, player_inv: PlayerInventory) -> int:
	## Add crafted item to inventory. Returns overflow count.
	return player_inv.add_item_to_inventory(recipe.output_item, recipe.output_count)
