extends GutTest
## Tests for ground items, death bags, loot tables, and loot spawner.


# ─── Helpers ───

func _make_item(item_name: String = "TestItem", stack: int = 10) -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.max_stack_size = stack
	item.category = ItemData.Category.RESOURCE
	return item


func _make_inventory_with_items() -> PlayerInventory:
	var inv := PlayerInventory.new()
	add_child_autofree(inv)
	var item_a := _make_item("Wood", 50)
	var item_b := _make_item("Stone", 50)
	inv.add_item_to_inventory(item_a, 10)
	inv.add_item_to_inventory(item_b, 5)
	return inv


# ─── Test 1: GroundItem holds data ───

func test_ground_item_data() -> void:
	var item := _make_item("Sword", 1)
	var gi := GroundItem.new()
	gi.item_data = item
	gi.item_count = 1
	add_child_autofree(gi)
	assert_eq(gi.item_data.item_name, "Sword")
	assert_eq(gi.item_count, 1)


# ─── Test 2: GroundItem pickup adds to inventory ───

func test_ground_item_pickup() -> void:
	var item := _make_item("Rock", 50)
	var gi := GroundItem.new()
	gi.item_data = item
	gi.item_count = 5
	add_child_autofree(gi)

	var player := CharacterBody3D.new()
	var inv := PlayerInventory.new()
	inv.name = "PlayerInventory"
	player.add_child(inv)
	add_child_autofree(player)

	var result := gi.interact(player)
	assert_true(result, "Pickup should succeed")
	assert_eq(inv.hotbar.get_item_count(item), 5)


# ─── Test 3: Pickup overflow leaves item on ground ───

func test_ground_item_overflow() -> void:
	var item := _make_item("Ammo", 5)
	# Fill all slots
	var player := CharacterBody3D.new()
	var inv := PlayerInventory.new()
	inv.name = "PlayerInventory"
	player.add_child(inv)
	add_child_autofree(player)

	# Fill all 6 hotbar + 24 main = 30 slots
	for i in range(30):
		var filler := _make_item("Filler%d" % i, 1)
		inv.add_item_to_inventory(filler, 1)

	var gi := GroundItem.new()
	gi.item_data = item
	gi.item_count = 3
	add_child_autofree(gi)

	var result := gi.interact(player)
	assert_false(result, "Pickup should fail (full inventory)")
	assert_eq(gi.item_count, 3, "Item stays on ground")


# ─── Test 4: DeathBag contains inventory items ───

func test_death_bag_contents() -> void:
	var inv := _make_inventory_with_items()
	var bag := DeathBag.new()
	add_child_autofree(bag)
	bag.set_items_from_inventory(inv)
	assert_gt(bag.items.size(), 0, "Bag should have items")
	assert_gt(bag.get_item_count(), 0)


# ─── Test 5: DeathBag interact transfers items ───

func test_death_bag_transfer() -> void:
	var inv := _make_inventory_with_items()
	var bag := DeathBag.new()
	add_child_autofree(bag)
	bag.set_items_from_inventory(inv)
	var original_count := bag.get_item_count()

	# New player picks up
	var player := CharacterBody3D.new()
	var player_inv := PlayerInventory.new()
	player_inv.name = "PlayerInventory"
	player.add_child(player_inv)
	add_child_autofree(player)

	bag.interact(player)
	var all_items := player_inv.get_all_items()
	var total := 0
	for entry in all_items:
		total += entry["count"]
	assert_eq(total, original_count, "All items transferred")


# ─── Test 6: LootTable rolls with weights ───

func test_loot_table_rolls() -> void:
	var table := LootTable.new()
	var item_a := _make_item("Common", 10)
	var item_b := _make_item("Rare", 1)
	table.entries = [
		{ "item": item_a, "weight": 90.0, "min_count": 1, "max_count": 5 },
		{ "item": item_b, "weight": 10.0, "min_count": 1, "max_count": 1 },
	]
	# Roll many times, should get at least some common
	var common_count := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(100):
		var result := LootTable.roll(table, rng)
		assert_gt(result.size(), 0, "Roll should return items")
		if result[0]["item"].item_name == "Common":
			common_count += 1
	assert_gt(common_count, 50, "Common should dominate")


# ─── Test 7: LootTable empty returns empty ───

func test_loot_table_empty() -> void:
	var table := LootTable.new()
	var result := LootTable.roll(table)
	assert_eq(result.size(), 0)


# ─── Test 8: LootSpawner deterministic ───

func test_loot_spawner_deterministic() -> void:
	var result1 := LootSpawner.generate_loot_positions(5, 5, 42)
	var result2 := LootSpawner.generate_loot_positions(5, 5, 42)
	assert_eq(result1.size(), result2.size())
	for i in range(result1.size()):
		assert_eq(result1[i]["position"], result2[i]["position"], "Same seed = same positions")
		assert_eq(result1[i]["table_tier"], result2[i]["table_tier"], "Same seed = same tiers")


# ─── Test 9: LootSpawner density ───

func test_loot_spawner_density() -> void:
	var normal := LootSpawner.generate_loot_positions(0, 0, 123, false)
	var poi := LootSpawner.generate_loot_positions(0, 0, 123, true)
	assert_eq(normal.size(), LootSpawner.DENSITY_NORMAL)
	assert_eq(poi.size(), LootSpawner.DENSITY_POI)


# ─── Test 10: PlayerInventory get_all_items ───

func test_inventory_get_all_items() -> void:
	var inv := _make_inventory_with_items()
	var all := inv.get_all_items()
	assert_gt(all.size(), 0)
	var total := 0
	for entry in all:
		total += entry["count"]
	assert_eq(total, 15, "10 wood + 5 stone")


# ─── Test 11: PlayerInventory clear_all ───

func test_inventory_clear_all() -> void:
	var inv := _make_inventory_with_items()
	inv.clear_all()
	var all := inv.get_all_items()
	assert_eq(all.size(), 0, "All slots empty after clear")


# ─── Test 12: LootSpawner tier distribution ───

func test_loot_spawner_tiers() -> void:
	var common := 0
	var uncommon := 0
	var rare := 0
	for chunk_x in range(20):
		var loot := LootSpawner.generate_loot_positions(chunk_x, 0, 777)
		for entry in loot:
			match entry["table_tier"]:
				"common": common += 1
				"uncommon": uncommon += 1
				"rare": rare += 1
	assert_gt(common, uncommon, "Common > uncommon")
	assert_gt(uncommon, rare, "Uncommon > rare")
