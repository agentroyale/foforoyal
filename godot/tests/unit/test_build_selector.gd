extends GutTest
## Tests for BuildSelectorUI and BuildingPieceData.get_category().


# ─── Category Classification ───

func test_get_category_foundations() -> void:
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.FOUNDATION), 0)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.TRIANGLE_FOUNDATION), 0)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.PILLAR), 0)


func test_get_category_walls() -> void:
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.WALL), 1)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.DOORWAY), 1)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.DOOR), 1)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.WINDOW_FRAME), 1)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.HALF_WALL), 1)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.WALL_ARCHED), 1)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.WALL_GATED), 1)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.WALL_WINDOW_ARCHED), 1)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.WALL_WINDOW_CLOSED), 1)


func test_get_category_floors() -> void:
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.FLOOR), 2)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.FLOOR_WOOD), 2)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.CEILING), 2)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.STAIRS), 2)


func test_get_category_roofs_utility() -> void:
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.ROOF), 3)
	assert_eq(BuildingPieceData.get_category(BuildingPieceData.PieceType.TOOL_CUPBOARD), 3)


# ─── BuildSelectorUI ───

var _selector: BuildSelectorUI
var _placer_mock: BuildingPlacer


func _make_piece(pname: String, ptype: BuildingPieceData.PieceType) -> BuildingPieceData:
	var data := BuildingPieceData.new()
	data.piece_name = pname
	data.piece_type = ptype
	return data


func _setup_selector() -> void:
	# Create a real BuildingPlacer with mock data (no scene loading)
	_placer_mock = BuildingPlacer.new()
	add_child_autofree(_placer_mock)
	# Inject test pieces directly
	_placer_mock._pieces = [
		_make_piece("Foundation", BuildingPieceData.PieceType.FOUNDATION),       # 0
		_make_piece("Triangle Foundation", BuildingPieceData.PieceType.TRIANGLE_FOUNDATION), # 1
		_make_piece("Pillar", BuildingPieceData.PieceType.PILLAR),               # 2
		_make_piece("Wall", BuildingPieceData.PieceType.WALL),                   # 3
		_make_piece("Doorway", BuildingPieceData.PieceType.DOORWAY),             # 4
		_make_piece("Floor", BuildingPieceData.PieceType.FLOOR),                 # 5
		_make_piece("Roof", BuildingPieceData.PieceType.ROOF),                   # 6
		_make_piece("Tool Cupboard", BuildingPieceData.PieceType.TOOL_CUPBOARD), # 7
	] as Array[BuildingPieceData]
	_placer_mock._current_piece_index = 0
	_placer_mock.current_piece_data = _placer_mock._pieces[0]

	_selector = BuildSelectorUI.new()
	add_child_autofree(_selector)
	_selector.setup(_placer_mock)


func test_default_category_is_foundations() -> void:
	_setup_selector()
	assert_eq(_selector.get_current_category(), 0, "Default category should be 0 (Foundations)")


func test_set_category_changes_category() -> void:
	_setup_selector()
	_selector.set_category(2)
	assert_eq(_selector.get_current_category(), 2, "Category should be 2 (Floors)")
	assert_eq(_selector.get_current_slot(), 0, "Slot should reset to 0 on category change")


func test_cycle_slot_forward() -> void:
	_setup_selector()
	# Category 0 has 3 pieces: Foundation, Triangle Foundation, Pillar
	assert_eq(_selector.get_current_slot(), 0)
	_selector.cycle_slot(1)
	assert_eq(_selector.get_current_slot(), 1)
	_selector.cycle_slot(1)
	assert_eq(_selector.get_current_slot(), 2)


func test_cycle_slot_wraps_forward() -> void:
	_setup_selector()
	# Category 0 has 3 pieces
	_selector.cycle_slot(1)
	_selector.cycle_slot(1)
	_selector.cycle_slot(1)  # Should wrap to 0
	assert_eq(_selector.get_current_slot(), 0, "Should wrap around to first slot")


func test_cycle_slot_wraps_backward() -> void:
	_setup_selector()
	_selector.cycle_slot(-1)  # Should wrap to last (2)
	assert_eq(_selector.get_current_slot(), 2, "Should wrap around to last slot")


func test_select_updates_placer_index() -> void:
	_setup_selector()
	_selector.set_category(1)  # Walls: Wall(3), Doorway(4)
	_selector.cycle_slot(1)    # Select Doorway
	assert_eq(_placer_mock.get_current_piece_index(), 4, "Placer should point to Doorway (global index 4)")


func test_visibility_toggle() -> void:
	_setup_selector()
	_selector.visible = false
	assert_false(_selector.visible)
	_selector.visible = true
	assert_true(_selector.visible)


func test_piece_short_labels_cover_all_names() -> void:
	# Verify all standard piece names have short labels
	var expected_names := [
		"Foundation", "Triangle Foundation", "Pillar",
		"Wall", "Doorway", "Door", "Window Frame", "Half Wall",
		"Wall Arched", "Wall Gated", "Wall Window Arched", "Wall Window Closed",
		"Floor", "Floor Wood", "Ceiling", "Stairs",
		"Roof", "Tool Cupboard",
	]
	for pname in expected_names:
		assert_true(
			BuildSelectorUI.PIECE_SHORT_LABELS.has(pname),
			"Missing short label for: %s" % pname
		)
