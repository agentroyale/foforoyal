extends GutTest
## Phase 4: Resource Gathering & Inventory unit tests.


# ─── Helpers ───

func _make_item(item_name: String = "Wood", stack_size: int = 1000) -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.max_stack_size = stack_size
	item.category = ItemData.Category.RESOURCE
	return item


func _make_tool(type: ToolData.ToolType = ToolData.ToolType.HATCHET, power: float = 25.0) -> ToolData:
	var tool := ToolData.new()
	tool.item_name = "TestTool"
	tool.max_stack_size = 1
	tool.category = ItemData.Category.TOOL
	tool.gather_power = power
	tool.max_durability = 100
	tool.tool_type = type
	return tool


func _make_resource_node(type: ResourceNode.NodeType = ResourceNode.NodeType.TREE, hp: float = 100.0) -> ResourceNode:
	var node := ResourceNode.new()
	var visual := Node3D.new()
	visual.name = "Visual"
	node.add_child(visual)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	node.add_child(col)
	var spot := Marker3D.new()
	spot.name = "HitSpot"
	node.add_child(spot)
	add_child_autofree(node)

	node.node_type = type
	node.max_hp = hp
	node.current_hp = hp
	node.yield_item = _make_item("Wood")
	node.base_yield_per_hit = 10
	node.respawn_time = 2.0
	# Manually resolve @onready since we built the tree ourselves
	node.hit_spot = spot
	node._visual = visual
	return node


# ─── Test 1: Inventory Add Item ───

func test_inventory_add_item() -> void:
	var inv := Inventory.new(6)
	var item := _make_item("Wood", 1000)

	var overflow := inv.add_item(item, 50)
	assert_eq(overflow, 0, "No overflow adding 50 to empty inv")
	assert_false(inv.is_slot_empty(0), "Slot 0 occupied")
	assert_eq(inv.get_slot(0)["count"], 50, "Slot 0 has 50")
	assert_eq(inv.get_slot(0)["item"], item, "Slot 0 has the wood item")


# ─── Test 2: Inventory Stack Overflow ───

func test_inventory_stack_overflow() -> void:
	var inv := Inventory.new(6)
	var item := _make_item("Wood", 1000)

	var overflow := inv.add_item(item, 1500)
	assert_eq(overflow, 0, "6 slots can hold 1500 (1000+500)")
	assert_eq(inv.get_slot(0)["count"], 1000, "Slot 0 full at 1000")
	assert_eq(inv.get_slot(1)["count"], 500, "Slot 1 has overflow 500")
	assert_true(inv.is_slot_empty(2), "Slot 2 empty")


# ─── Test 3: Inventory Remove Item ───

func test_inventory_remove_item() -> void:
	var inv := Inventory.new(6)
	var item := _make_item("Wood", 1000)
	inv.add_item(item, 500)

	var removed := inv.remove_item(item, 200)
	assert_eq(removed, 200, "Removed 200")
	assert_eq(inv.get_slot(0)["count"], 300, "300 remaining")

	removed = inv.remove_item(item, 300)
	assert_eq(removed, 300, "Removed remaining 300")
	assert_true(inv.is_slot_empty(0), "Slot empty after full removal")


# ─── Test 4: Inventory Move Slot ───

func test_inventory_move_slot() -> void:
	var inv := Inventory.new(6)
	var item := _make_item("Wood", 1000)
	inv.add_item(item, 100)

	var success := inv.move_slot(0, 3)
	assert_true(success, "Move should succeed")
	assert_true(inv.is_slot_empty(0), "Slot 0 empty after move")
	assert_false(inv.is_slot_empty(3), "Slot 3 occupied after move")
	assert_eq(inv.get_slot(3)["count"], 100, "Slot 3 has 100")


# ─── Test 5: Inventory Split Stack ───

func test_inventory_split_stack() -> void:
	var inv := Inventory.new(6)
	var item := _make_item("Wood", 1000)
	inv.add_item(item, 100)

	var new_slot := inv.split_stack(0, 50)
	assert_ne(new_slot, -1, "Split should return valid slot index")
	assert_eq(inv.get_slot(0)["count"], 50, "Original has 50")
	assert_eq(inv.get_slot(new_slot)["count"], 50, "New slot has 50")


# ─── Test 6: Resource Node Depletion ───

func test_resource_node_depletion() -> void:
	var node := _make_resource_node(ResourceNode.NodeType.TREE, 100.0)
	var tool := _make_tool(ToolData.ToolType.HATCHET, 25.0)

	# Hatchet on tree = 1.0x, so 25 damage/hit. 100/25 = 4 hits.
	node.take_hit(tool)
	assert_almost_eq(node.current_hp, 75.0, 0.01, "After 1 hit: 75 HP")
	assert_false(node.is_depleted, "Not depleted after 1 hit")

	node.take_hit(tool)
	assert_almost_eq(node.current_hp, 50.0, 0.01, "After 2 hits: 50 HP")

	node.take_hit(tool)
	assert_almost_eq(node.current_hp, 25.0, 0.01, "After 3 hits: 25 HP")

	node.take_hit(tool)
	assert_true(node.is_depleted, "Depleted after 4 hits")


# ─── Test 7: Hit Spot Bonus ───

func test_hit_spot_bonus() -> void:
	var node := _make_resource_node(ResourceNode.NodeType.TREE, 10000.0)
	var tool := _make_tool(ToolData.ToolType.HATCHET, 25.0)

	# Normal hit (far from spot)
	var normal_yield := node.take_hit(tool, Vector3(999, 999, 999))

	# Hit spot hit (exactly at the hit spot position)
	var spot_pos := node.hit_spot.global_position
	var bonus_yield := node.take_hit(tool, spot_pos)

	# bonus = int(10 * 1.0 * 1.5) = 15, normal = int(10 * 1.0 * 1.0) = 10
	assert_eq(normal_yield, 10, "Normal yield should be 10")
	assert_eq(bonus_yield, 15, "Hit spot yield should be 15 (1.5x)")


# ─── Test 8: Tool Effectiveness ───

func test_tool_effectiveness() -> void:
	assert_eq(ToolData.get_effectiveness(ToolData.ToolType.HATCHET, ResourceNode.NodeType.TREE), 1.0,
		"Hatchet on tree = 1.0x")
	assert_eq(ToolData.get_effectiveness(ToolData.ToolType.PICKAXE, ResourceNode.NodeType.TREE), 0.5,
		"Pickaxe on tree = 0.5x")
	assert_eq(ToolData.get_effectiveness(ToolData.ToolType.PICKAXE, ResourceNode.NodeType.ROCK), 1.0,
		"Pickaxe on rock = 1.0x")
	assert_eq(ToolData.get_effectiveness(ToolData.ToolType.HATCHET, ResourceNode.NodeType.METAL_ORE), 0.3,
		"Hatchet on metal ore = 0.3x")
	assert_eq(ToolData.get_effectiveness(ToolData.ToolType.HAND, ResourceNode.NodeType.TREE), 0.5,
		"Hand on tree = 0.5x")
	assert_eq(ToolData.get_effectiveness(ToolData.ToolType.PICKAXE, ResourceNode.NodeType.SULFUR_ORE), 1.0,
		"Pickaxe on sulfur = 1.0x")


# ─── Test 9: Resource Respawn Timer ───

func test_resource_respawn_timer() -> void:
	var node := _make_resource_node(ResourceNode.NodeType.TREE, 100.0)
	node.respawn_time = 2.0

	node._deplete()
	assert_true(node.is_depleted, "Should be depleted")

	node._process(1.0)
	assert_true(node.is_depleted, "Still depleted at 1s (need 2s)")

	node._process(1.5)
	assert_false(node.is_depleted, "Respawned after 2.5s total")
	assert_eq(node.current_hp, node.max_hp, "HP restored to max")
