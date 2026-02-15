extends GutTest
## Phase 5: Crafting System unit tests.


# ─── Helpers ───

func _make_item(item_name: String = "Wood", stack_size: int = 1000) -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.max_stack_size = stack_size
	item.category = ItemData.Category.RESOURCE
	return item


func _make_recipe(
	items: Array[ItemData],
	counts: Array[int],
	output: ItemData,
	output_count: int = 1,
	craft_time: float = 2.0,
	wb_tier: RecipeData.WorkbenchTier = RecipeData.WorkbenchTier.HAND,
	unlock_cost: int = 0
) -> RecipeData:
	var recipe := RecipeData.new()
	recipe.recipe_name = "TestRecipe"
	recipe.ingredient_items = items
	recipe.ingredient_counts = counts
	recipe.output_item = output
	recipe.output_count = output_count
	recipe.craft_time = craft_time
	recipe.workbench_tier = wb_tier
	recipe.unlock_cost = unlock_cost
	return recipe


func _make_player_inventory() -> PlayerInventory:
	var pi := PlayerInventory.new()
	add_child_autofree(pi)
	return pi


func _make_crafting_queue(
	player_inv: PlayerInventory,
	tier: RecipeData.WorkbenchTier = RecipeData.WorkbenchTier.HAND
) -> CraftingQueue:
	var cq := CraftingQueue.new()
	cq.player_inventory = player_inv
	cq.available_tier = tier
	add_child_autofree(cq)
	return cq


# ─── Test 1: Craft With Sufficient Ingredients ───

func test_craft_with_sufficient_ingredients() -> void:
	var wood := _make_item("Wood", 1000)
	var stone := _make_item("Stone", 1000)
	var hatchet := _make_item("Stone Hatchet", 1)

	var recipe := _make_recipe(
		[wood, stone] as Array[ItemData],
		[200, 100] as Array[int],
		hatchet
	)

	var pi := _make_player_inventory()
	pi.add_item_to_inventory(wood, 500)
	pi.add_item_to_inventory(stone, 300)

	var result := CraftingSystem.can_craft(recipe, pi)
	assert_eq(result, CraftingSystem.CraftResult.SUCCESS, "Should succeed with sufficient ingredients")

	CraftingSystem.consume_ingredients(recipe, pi)
	assert_true(pi.has_item(wood, 300), "300 wood remaining")
	assert_true(pi.has_item(stone, 200), "200 stone remaining")

	var overflow := CraftingSystem.produce_output(recipe, pi)
	assert_eq(overflow, 0, "No overflow producing 1 hatchet")
	assert_true(pi.has_item(hatchet, 1), "Should have the crafted hatchet")


# ─── Test 2: Craft Insufficient Ingredients ───

func test_craft_insufficient_ingredients() -> void:
	var wood := _make_item("Wood", 1000)
	var stone := _make_item("Stone", 1000)
	var hatchet := _make_item("Stone Hatchet", 1)

	var recipe := _make_recipe(
		[wood, stone] as Array[ItemData],
		[200, 100] as Array[int],
		hatchet
	)

	var pi := _make_player_inventory()
	pi.add_item_to_inventory(wood, 50)

	var result := CraftingSystem.can_craft(recipe, pi)
	assert_eq(result, CraftingSystem.CraftResult.INSUFFICIENT_INGREDIENTS,
		"Should fail with insufficient wood")
	assert_false(pi.has_item(hatchet, 1), "Should NOT have a hatchet")


# ─── Test 3: Craft Requires Workbench ───

func test_craft_requires_workbench() -> void:
	var metal := _make_item("Metal Fragments", 1000)
	var wood := _make_item("Wood", 1000)
	var metal_hatchet := _make_item("Metal Hatchet", 1)

	var recipe := _make_recipe(
		[wood, metal] as Array[ItemData],
		[100, 75] as Array[int],
		metal_hatchet, 1, 15.0,
		RecipeData.WorkbenchTier.WORKBENCH_T1
	)

	var pi := _make_player_inventory()
	pi.add_item_to_inventory(wood, 500)
	pi.add_item_to_inventory(metal, 500)

	var result := CraftingSystem.can_craft(recipe, pi, RecipeData.WorkbenchTier.HAND)
	assert_eq(result, CraftingSystem.CraftResult.WORKBENCH_REQUIRED,
		"Should require workbench at HAND tier")

	result = CraftingSystem.can_craft(recipe, pi, RecipeData.WorkbenchTier.WORKBENCH_T1)
	assert_eq(result, CraftingSystem.CraftResult.SUCCESS, "Should succeed at T1")

	result = CraftingSystem.can_craft(recipe, pi, RecipeData.WorkbenchTier.WORKBENCH_T2)
	assert_eq(result, CraftingSystem.CraftResult.SUCCESS, "Should succeed at T2 (higher tier)")


# ─── Test 4: Crafting Queue Order (FIFO) ───

func test_crafting_queue_order() -> void:
	var wood := _make_item("Wood", 1000)
	var plank := _make_item("Plank", 1000)
	var stone := _make_item("Stone", 1000)
	var tool := _make_item("StoneTool", 1)

	var recipe_a := _make_recipe(
		[wood] as Array[ItemData], [10] as Array[int], plank, 5, 1.0
	)
	var recipe_b := _make_recipe(
		[stone] as Array[ItemData], [10] as Array[int], tool, 1, 1.0
	)

	var pi := _make_player_inventory()
	pi.add_item_to_inventory(wood, 100)
	pi.add_item_to_inventory(stone, 100)

	var cq := _make_crafting_queue(pi)

	var result_a := cq.enqueue(recipe_a)
	var result_b := cq.enqueue(recipe_b)
	assert_eq(result_a, CraftingSystem.CraftResult.SUCCESS, "Recipe A enqueued")
	assert_eq(result_b, CraftingSystem.CraftResult.SUCCESS, "Recipe B enqueued")
	assert_eq(cq.get_queue_size(), 2, "Queue has 2 items")

	# First recipe completes
	cq._process(1.1)
	assert_eq(cq.get_queue_size(), 1, "First completed, 1 remaining")
	assert_true(pi.has_item(plank, 5), "Received 5 planks from recipe A")
	assert_false(pi.has_item(tool, 1), "Tool not yet crafted")

	# Second recipe completes
	cq._process(1.1)
	assert_eq(cq.get_queue_size(), 0, "Queue empty")
	assert_true(pi.has_item(tool, 1), "Received tool from recipe B")


# ─── Test 5: Crafting Queue Pause On Leave ───

func test_crafting_queue_pause_on_leave() -> void:
	var wood := _make_item("Wood", 1000)
	var plank := _make_item("Plank", 1000)

	var recipe := _make_recipe(
		[wood] as Array[ItemData], [10] as Array[int], plank, 5, 2.0
	)

	var pi := _make_player_inventory()
	pi.add_item_to_inventory(wood, 100)

	var cq := _make_crafting_queue(pi)
	cq.enqueue(recipe)

	# 0.5s of crafting
	cq._process(0.5)
	assert_eq(cq.get_queue_size(), 1, "Still crafting")
	assert_almost_eq(cq.get_current_progress(), 0.25, 0.01, "25% at 0.5s/2.0s")

	# Pause
	cq.pause()
	cq._process(5.0)
	assert_eq(cq.get_queue_size(), 1, "Still in queue while paused")
	assert_almost_eq(cq.get_current_progress(), 0.25, 0.01, "Progress unchanged while paused")

	# Resume
	cq.resume()
	cq._process(1.5)
	assert_eq(cq.get_queue_size(), 0, "Completed after resume")
	assert_true(pi.has_item(plank, 5), "Received planks")


# ─── Test 6: Tech Tree Unlock ───

func test_tech_tree_unlock() -> void:
	var scrap := _make_item("Scrap", 1000)
	var metal := _make_item("Metal Fragments", 1000)
	var wood := _make_item("Wood", 1000)
	var metal_hatchet := _make_item("Metal Hatchet", 1)

	var recipe := _make_recipe(
		[wood, metal] as Array[ItemData],
		[100, 75] as Array[int],
		metal_hatchet, 1, 15.0,
		RecipeData.WorkbenchTier.WORKBENCH_T1,
		75
	)

	var pi := _make_player_inventory()
	pi.add_item_to_inventory(wood, 500)
	pi.add_item_to_inventory(metal, 500)
	pi.add_item_to_inventory(scrap, 100)

	var tech := TechTree.new()
	tech.scrap_item = scrap

	assert_false(tech.is_unlocked(recipe), "Recipe starts locked")

	var result := CraftingSystem.can_craft(recipe, pi, RecipeData.WorkbenchTier.WORKBENCH_T1, tech)
	assert_eq(result, CraftingSystem.CraftResult.RECIPE_LOCKED, "Locked recipe blocked")

	var unlocked := tech.unlock(recipe, pi)
	assert_true(unlocked, "Unlock succeeded")
	assert_true(tech.is_unlocked(recipe), "Recipe now unlocked")
	assert_true(pi.has_item(scrap, 25), "25 scrap remaining (100-75)")

	result = CraftingSystem.can_craft(recipe, pi, RecipeData.WorkbenchTier.WORKBENCH_T1, tech)
	assert_eq(result, CraftingSystem.CraftResult.SUCCESS, "Unlocked recipe now craftable")
