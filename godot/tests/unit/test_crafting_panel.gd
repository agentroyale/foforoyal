extends GutTest
## Unit tests for CraftingPanel UI.


# ─── Helpers ───

func _make_item(item_name: String = "Wood", stack_size: int = 1000) -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.max_stack_size = stack_size
	item.category = ItemData.Category.RESOURCE
	return item


func _make_recipe(
	recipe_name: String,
	items: Array[ItemData],
	counts: Array[int],
	output: ItemData,
	output_count: int = 1,
	craft_time: float = 2.0,
) -> RecipeData:
	var recipe := RecipeData.new()
	recipe.recipe_name = recipe_name
	recipe.description = "Test recipe for %s" % recipe_name
	recipe.ingredient_items = items
	recipe.ingredient_counts = counts
	recipe.output_item = output
	recipe.output_count = output_count
	recipe.craft_time = craft_time
	recipe.workbench_tier = RecipeData.WorkbenchTier.HAND
	recipe.unlock_cost = 0
	return recipe


func _make_player_inventory() -> PlayerInventory:
	var pi := PlayerInventory.new()
	add_child_autofree(pi)
	return pi


func _make_crafting_queue(player_inv: PlayerInventory) -> CraftingQueue:
	var cq := CraftingQueue.new()
	cq.player_inventory = player_inv
	cq.available_tier = RecipeData.WorkbenchTier.HAND
	add_child_autofree(cq)
	return cq


func _make_panel() -> CraftingPanel:
	var panel := CraftingPanel.new()
	add_child_autofree(panel)
	return panel


# ─── Test 1: Panel opens and closes ───

func test_panel_toggle() -> void:
	var panel := _make_panel()
	assert_false(panel.is_open, "Panel should start closed")

	panel.open()
	assert_true(panel.is_open, "Panel should be open after open()")
	assert_true(panel.visible, "Panel should be visible when open")

	panel.close()
	assert_false(panel.is_open, "Panel should be closed after close()")
	assert_false(panel.visible, "Panel should not be visible when closed")


# ─── Test 2: Panel toggle via method ───

func test_panel_toggle_method() -> void:
	var panel := _make_panel()

	panel.toggle()
	assert_true(panel.is_open, "Toggle from closed -> open")

	panel.toggle()
	assert_false(panel.is_open, "Toggle from open -> closed")


# ─── Test 3: Recipes can be set externally ───

func test_set_recipes() -> void:
	var wood := _make_item("Wood")
	var stone := _make_item("Stone")
	var hatchet := _make_item("Stone Hatchet", 1)
	var campfire := _make_item("Campfire", 1)

	var r1 := _make_recipe("Stone Hatchet", [wood, stone] as Array[ItemData], [200, 100] as Array[int], hatchet)
	var r2 := _make_recipe("Campfire", [wood, stone] as Array[ItemData], [100, 50] as Array[int], campfire)

	var panel := _make_panel()
	panel.set_recipes([r1, r2] as Array[RecipeData])

	assert_eq(panel.get_recipe_count(), 2, "Panel should have 2 recipes")


# ─── Test 4: Crafting enqueues correctly ───

func test_craft_enqueues_recipe() -> void:
	var wood := _make_item("Wood")
	var plank := _make_item("Plank")

	var recipe := _make_recipe("Plank", [wood] as Array[ItemData], [10] as Array[int], plank, 5, 1.0)

	var pi := _make_player_inventory()
	pi.add_item_to_inventory(wood, 100)

	var cq := _make_crafting_queue(pi)
	var panel := _make_panel()
	panel.set_player_inventory(pi)
	panel.set_crafting_queue(cq)
	panel.set_recipes([recipe] as Array[RecipeData])

	# Simulate selecting and crafting
	panel._select_recipe(recipe)
	panel._on_craft_pressed()

	assert_eq(cq.get_queue_size(), 1, "Queue should have 1 item after craft")
	assert_true(pi.has_item(wood, 90), "Should have 90 wood remaining")


# ─── Test 5: Cannot craft without materials ───

func test_craft_button_disabled_without_materials() -> void:
	var wood := _make_item("Wood")
	var plank := _make_item("Plank")

	var recipe := _make_recipe("Plank", [wood] as Array[ItemData], [10] as Array[int], plank, 5, 1.0)

	var pi := _make_player_inventory()
	# No wood added - empty inventory

	var cq := _make_crafting_queue(pi)
	var panel := _make_panel()
	panel.set_player_inventory(pi)
	panel.set_crafting_queue(cq)
	panel.set_recipes([recipe] as Array[RecipeData])

	panel._select_recipe(recipe)
	panel.open()
	panel._refresh_detail()

	assert_true(panel._craft_button.disabled, "Craft button should be disabled without materials")


# ─── Test 6: Craft button enabled with materials ───

func test_craft_button_enabled_with_materials() -> void:
	var wood := _make_item("Wood")
	var plank := _make_item("Plank")

	var recipe := _make_recipe("Plank", [wood] as Array[ItemData], [10] as Array[int], plank, 5, 1.0)

	var pi := _make_player_inventory()
	pi.add_item_to_inventory(wood, 100)

	var cq := _make_crafting_queue(pi)
	var panel := _make_panel()
	panel.set_player_inventory(pi)
	panel.set_crafting_queue(cq)
	panel.set_recipes([recipe] as Array[RecipeData])

	panel._select_recipe(recipe)
	panel.open()
	panel._refresh_detail()

	assert_false(panel._craft_button.disabled, "Craft button should be enabled with sufficient materials")


# ─── Test 7: Queue full disables craft ───

func test_queue_full_disables_craft() -> void:
	var wood := _make_item("Wood")
	var plank := _make_item("Plank")

	var recipe := _make_recipe("Plank", [wood] as Array[ItemData], [10] as Array[int], plank, 5, 100.0)

	var pi := _make_player_inventory()
	pi.add_item_to_inventory(wood, 1000)

	var cq := _make_crafting_queue(pi)
	var panel := _make_panel()
	panel.set_player_inventory(pi)
	panel.set_crafting_queue(cq)
	panel.set_recipes([recipe] as Array[RecipeData])

	# Fill queue to max
	for i in range(CraftingQueue.MAX_QUEUE_SIZE):
		cq.enqueue(recipe)

	assert_eq(cq.get_queue_size(), CraftingQueue.MAX_QUEUE_SIZE, "Queue should be full")

	panel._select_recipe(recipe)
	panel.open()
	panel._update_craft_button()

	assert_true(panel._craft_button.disabled, "Craft button disabled when queue is full")
	assert_eq(panel._craft_button.text, "QUEUE FULL", "Button text should say QUEUE FULL")


# ─── Test 8: Queue cancel restores materials ───

func test_queue_cancel_restores_materials() -> void:
	var wood := _make_item("Wood")
	var plank := _make_item("Plank")

	var recipe := _make_recipe("Plank", [wood] as Array[ItemData], [10] as Array[int], plank, 5, 10.0)

	var pi := _make_player_inventory()
	pi.add_item_to_inventory(wood, 100)

	var cq := _make_crafting_queue(pi)
	var panel := _make_panel()
	panel.set_player_inventory(pi)
	panel.set_crafting_queue(cq)

	cq.enqueue(recipe)
	assert_true(pi.has_item(wood, 90), "90 wood after enqueue")

	panel._on_cancel_queue_item(0)
	assert_true(pi.has_item(wood, 100), "100 wood after cancel (materials refunded)")
	assert_eq(cq.get_queue_size(), 0, "Queue should be empty after cancel")


# ─── Test 9: Open/close signals emitted ───

func test_open_close_signals() -> void:
	var panel := _make_panel()

	# Use arrays — GDScript lambdas capture primitives by value
	var counts := [0, 0]  # [opened, closed]
	panel.panel_opened.connect(func() -> void: counts[0] += 1)
	panel.panel_closed.connect(func() -> void: counts[1] += 1)

	panel.open()
	assert_eq(counts[0], 1, "Opened signal emitted once")

	panel.close()
	assert_eq(counts[1], 1, "Closed signal emitted once")

	# Double open should not re-emit
	panel.open()
	panel.open()
	assert_eq(counts[0], 2, "Opened signal not duplicated on double open")


# ─── Test 10: Multiple crafts consume correctly ───

func test_multiple_crafts_consume_ingredients() -> void:
	var wood := _make_item("Wood")
	var plank := _make_item("Plank")

	var recipe := _make_recipe("Plank", [wood] as Array[ItemData], [10] as Array[int], plank, 5, 1.0)

	var pi := _make_player_inventory()
	pi.add_item_to_inventory(wood, 50)

	var cq := _make_crafting_queue(pi)
	var panel := _make_panel()
	panel.set_player_inventory(pi)
	panel.set_crafting_queue(cq)
	panel.set_recipes([recipe] as Array[RecipeData])

	panel._select_recipe(recipe)

	# Craft 3 times (30 wood consumed)
	panel._on_craft_pressed()
	panel._on_craft_pressed()
	panel._on_craft_pressed()

	assert_eq(cq.get_queue_size(), 3, "Queue should have 3 items")
	assert_true(pi.has_item(wood, 20), "20 wood remaining after 3 crafts")

	# 4th craft should still work (10 more wood)
	panel._on_craft_pressed()
	assert_eq(cq.get_queue_size(), 4, "Queue should have 4 items")
	assert_true(pi.has_item(wood, 10), "10 wood remaining after 4 crafts")

	# 5th craft should still work (last 10 wood)
	panel._on_craft_pressed()
	assert_eq(cq.get_queue_size(), 5, "Queue should have 5 items")
	assert_false(pi.has_item(wood, 1), "No wood remaining after 5 crafts")

	# 6th craft should fail
	panel._on_craft_pressed()
	assert_eq(cq.get_queue_size(), 5, "Queue should still have 5 (6th failed)")
