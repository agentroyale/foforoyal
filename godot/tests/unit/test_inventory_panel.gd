extends GutTest
## Inventory Panel UI unit tests.


# ── Helpers ──

func _make_item(item_name: String = "Wood", stack_size: int = 100, desc: String = "") -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.description = desc
	item.max_stack_size = stack_size
	item.category = ItemData.Category.RESOURCE
	return item


func _make_player_inventory() -> PlayerInventory:
	var pi := PlayerInventory.new()
	add_child_autofree(pi)
	return pi


func _make_panel(pi: PlayerInventory) -> InventoryPanel:
	var panel := preload("res://scenes/ui/inventory_panel.tscn").instantiate() as InventoryPanel
	add_child_autofree(panel)
	# Wait for _ready and deferred calls
	await get_tree().process_frame
	await get_tree().process_frame
	panel.set_player_inventory(pi)
	return panel


# ── Test 1: Panel starts closed ──

func test_panel_starts_closed() -> void:
	var pi := _make_player_inventory()
	var panel := await _make_panel(pi)
	assert_false(panel.is_open, "Panel should start closed")


# ── Test 2: Open and close toggle ──

func test_open_close_toggle() -> void:
	var pi := _make_player_inventory()
	var panel := await _make_panel(pi)

	panel.open_inventory()
	assert_true(panel.is_open, "Panel should be open after open_inventory()")

	panel.close_inventory()
	assert_false(panel.is_open, "Panel should be closed after close_inventory()")


# ── Test 3: Hotbar slots reflect inventory ──

func test_hotbar_slots_reflect_inventory() -> void:
	var pi := _make_player_inventory()
	var wood := _make_item("Wood", 100)
	pi.add_item_to_inventory(wood, 50)

	var panel := await _make_panel(pi)
	panel.open_inventory()
	await get_tree().process_frame

	# First hotbar slot should have the wood icon
	var slot := pi.hotbar.get_slot(0)
	assert_false(slot.is_empty(), "Hotbar slot 0 should have wood")
	assert_eq(panel._hotbar_slot_icons[0].texture, wood.icon, "Icon should match item icon")


# ── Test 4: Stack count display ──

func test_stack_count_display() -> void:
	var pi := _make_player_inventory()
	var wood := _make_item("Wood", 100)
	pi.add_item_to_inventory(wood, 50)

	var panel := await _make_panel(pi)
	panel.open_inventory()
	await get_tree().process_frame

	assert_eq(panel._hotbar_slot_counts[0].text, "50", "Count label should show 50")


# ── Test 5: Single item shows no count ──

func test_single_item_no_count() -> void:
	var pi := _make_player_inventory()
	var hatchet := _make_item("Hatchet", 1)
	pi.add_item_to_inventory(hatchet, 1)

	var panel := await _make_panel(pi)
	panel.open_inventory()
	await get_tree().process_frame

	assert_eq(panel._hotbar_slot_counts[0].text, "", "Count label should be empty for stack of 1")


# ── Test 6: Main inventory slots ──

func test_main_inventory_slots() -> void:
	var pi := _make_player_inventory()
	var wood := _make_item("Wood", 100)
	# Fill hotbar (6 slots x 100 = 600), then overflow to main
	pi.add_item_to_inventory(wood, 700)

	var panel := await _make_panel(pi)
	panel.open_inventory()
	await get_tree().process_frame

	# Main slot 0 should have the overflow
	var main_slot := pi.main_inventory.get_slot(0)
	assert_false(main_slot.is_empty(), "Main slot 0 should have overflow wood")
	assert_eq(main_slot["count"], 100, "Main slot 0 should have 100 wood")
	assert_eq(panel._main_slot_counts[0].text, "100", "Main count label should show 100")


# ── Test 7: Empty slots show nothing ──

func test_empty_slots_show_nothing() -> void:
	var pi := _make_player_inventory()
	var panel := await _make_panel(pi)
	panel.open_inventory()
	await get_tree().process_frame

	assert_null(panel._hotbar_slot_icons[0].texture, "Empty slot should have null texture")
	assert_eq(panel._hotbar_slot_counts[0].text, "", "Empty slot count should be empty")
	assert_null(panel._main_slot_icons[0].texture, "Empty main slot should have null texture")


# ── Test 8: Live update on inventory change ──

func test_live_update_on_inventory_change() -> void:
	var pi := _make_player_inventory()
	var panel := await _make_panel(pi)
	panel.open_inventory()
	await get_tree().process_frame

	# Add item while panel is open
	var stone := _make_item("Stone", 50)
	pi.add_item_to_inventory(stone, 25)
	await get_tree().process_frame

	assert_eq(panel._hotbar_slot_counts[0].text, "25", "Should update live when item added")


# ── Test 9: Correct slot count totals ──

func test_correct_slot_count_totals() -> void:
	var pi := _make_player_inventory()
	var panel := await _make_panel(pi)
	panel.open_inventory()

	assert_eq(panel._hotbar_slot_panels.size(), 6, "Should have 6 hotbar slots")
	assert_eq(panel._main_slot_panels.size(), 24, "Should have 24 main slots")


# ── Test 10: Open signal emitted ──

func test_open_signal_emitted() -> void:
	var pi := _make_player_inventory()
	var panel := await _make_panel(pi)

	watch_signals(panel)
	panel.open_inventory()
	assert_signal_emitted(panel, "opened", "Should emit opened signal")


# ── Test 11: Close signal emitted ──

func test_close_signal_emitted() -> void:
	var pi := _make_player_inventory()
	var panel := await _make_panel(pi)

	panel.open_inventory()
	watch_signals(panel)
	panel.close_inventory()
	assert_signal_emitted(panel, "closed", "Should emit closed signal")


# ── Test 12: Double open is idempotent ──

func test_double_open_idempotent() -> void:
	var pi := _make_player_inventory()
	var panel := await _make_panel(pi)

	panel.open_inventory()
	panel.open_inventory()
	assert_true(panel.is_open, "Should still be open")

	panel.close_inventory()
	panel.close_inventory()
	assert_false(panel.is_open, "Should still be closed")
