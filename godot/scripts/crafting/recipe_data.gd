class_name RecipeData
extends Resource
## Data resource defining a single crafting recipe.

enum WorkbenchTier {
	HAND = 0,
	WORKBENCH_T1 = 1,
	WORKBENCH_T2 = 2,
	WORKBENCH_T3 = 3,
}

@export var recipe_name: String = ""
@export var description: String = ""
@export var ingredient_items: Array[ItemData] = []
@export var ingredient_counts: Array[int] = []
@export var output_item: ItemData
@export var output_count: int = 1
@export var craft_time: float = 5.0
@export var workbench_tier: WorkbenchTier = WorkbenchTier.HAND
@export var unlock_cost: int = 0
@export var requires_recipes: Array[RecipeData] = []


func get_ingredient_count() -> int:
	return mini(ingredient_items.size(), ingredient_counts.size())


func get_ingredient_item(index: int) -> ItemData:
	if index < 0 or index >= ingredient_items.size():
		return null
	return ingredient_items[index]


func get_ingredient_amount(index: int) -> int:
	if index < 0 or index >= ingredient_counts.size():
		return 0
	return ingredient_counts[index]
