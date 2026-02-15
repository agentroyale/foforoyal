class_name BuildSelectorUI
extends Control
## Build mode piece selector — replaces hotbar when building.
## Draws categories, piece slots, and hints via _draw().

const CATEGORY_NAMES: Array[String] = ["1 Found.", "2 Walls", "3 Floors", "4 Roofs"]
const SLOT_SIZE := 60.0
const SLOT_GAP := 6.0
const TAB_HEIGHT := 28.0
const HINT_HEIGHT := 22.0
const PADDING := 10.0
const NAME_HEIGHT := 16.0

const COLOR_BG := Color(0.06, 0.06, 0.08, 0.8)
const COLOR_BORDER := Color(0.25, 0.25, 0.3, 0.6)
const COLOR_TAB_ACTIVE := Color(0.15, 0.15, 0.1, 0.9)
const COLOR_TAB_INACTIVE := Color(0.08, 0.08, 0.1, 0.6)
const COLOR_SLOT_BG := Color(0.1, 0.1, 0.15, 0.75)
const COLOR_SLOT_SELECTED := Color(1.0, 0.85, 0.2, 0.9)
const COLOR_SLOT_BORDER := Color(0.3, 0.3, 0.35, 0.8)
const COLOR_TEXT := Color(0.85, 0.85, 0.85, 0.9)
const COLOR_TEXT_DIM := Color(0.6, 0.6, 0.6, 0.7)
const COLOR_HINT := Color(0.7, 0.7, 0.7, 0.8)
const COLOR_COST := Color(0.9, 0.8, 0.4, 0.9)

# Short labels for fallback when icon is null
const PIECE_SHORT_LABELS := {
	"Foundation": "FND",
	"Triangle Foundation": "TRI",
	"Pillar": "PIL",
	"Wall": "WLL",
	"Doorway": "DWY",
	"Door": "DOR",
	"Window Frame": "WIN",
	"Half Wall": "HLF",
	"Wall Arched": "ARC",
	"Wall Gated": "GAT",
	"Wall Window Arched": "WNA",
	"Wall Window Closed": "WNC",
	"Floor": "FLR",
	"Floor Wood": "FLW",
	"Ceiling": "CEL",
	"Stairs": "STR",
	"Roof": "ROF",
	"Tool Cupboard": "TC",
}

var _placer: BuildingPlacer = null
var _categories: Array[Array] = [[], [], [], []]  # Each: Array of {data, global_idx}
var _current_category: int = 0
var _current_slot: int = 0  # Index within current category
var _font: Font = null
var _font_small: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_font_small = _font


func setup(placer: BuildingPlacer) -> void:
	_placer = placer
	_build_categories()
	# Sync to placer's current piece
	_sync_from_placer()
	queue_redraw()


func _build_categories() -> void:
	_categories = [[], [], [], []]
	if not _placer:
		return
	var pieces := _placer.get_pieces()
	for i in range(pieces.size()):
		var data := pieces[i]
		var cat := BuildingPieceData.get_category(data.piece_type)
		_categories[cat].append({"data": data, "global_idx": i})


func _sync_from_placer() -> void:
	if not _placer:
		return
	var idx := _placer.get_current_piece_index()
	# Find which category and slot this index belongs to
	for cat in range(4):
		for slot in range(_categories[cat].size()):
			if _categories[cat][slot]["global_idx"] == idx:
				_current_category = cat
				_current_slot = slot
				return


func set_category(cat: int) -> void:
	if cat < 0 or cat > 3:
		return
	_current_category = cat
	_current_slot = 0
	_apply_selection()
	queue_redraw()


func cycle_slot(direction: int) -> void:
	var cat_pieces: Array = _categories[_current_category]
	if cat_pieces.is_empty():
		return
	_current_slot = (_current_slot + direction) % cat_pieces.size()
	if _current_slot < 0:
		_current_slot += cat_pieces.size()
	_apply_selection()
	queue_redraw()


func get_current_category() -> int:
	return _current_category


func get_current_slot() -> int:
	return _current_slot


func _apply_selection() -> void:
	var cat_pieces: Array = _categories[_current_category]
	if cat_pieces.is_empty() or not _placer:
		return
	var global_idx: int = cat_pieces[_current_slot]["global_idx"]
	_placer.select_piece_by_index(global_idx)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _placer or not _placer.is_build_mode:
		return

	# Category keys 1-4
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				set_category(0)
				get_viewport().set_input_as_handled()
			KEY_2:
				set_category(1)
				get_viewport().set_input_as_handled()
			KEY_3:
				set_category(2)
				get_viewport().set_input_as_handled()
			KEY_4:
				set_category(3)
				get_viewport().set_input_as_handled()

	# Scroll to cycle within category
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_slot(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_slot(-1)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if not _placer:
		return

	var cat_pieces: Array = _categories[_current_category]
	var num_slots := cat_pieces.size()
	if num_slots == 0:
		num_slots = 1

	# Calculate dimensions
	var slots_width := num_slots * SLOT_SIZE + (num_slots - 1) * SLOT_GAP
	var tabs_width := CATEGORY_NAMES.size() * 90.0
	var total_width := maxf(slots_width + PADDING * 2, tabs_width + PADDING * 2)
	var total_height := TAB_HEIGHT + SLOT_SIZE + NAME_HEIGHT + HINT_HEIGHT + PADDING * 3

	# Position: bottom-center of this Control
	var ox := (size.x - total_width) / 2.0
	var oy := size.y - total_height - 8.0

	# Background
	var bg_rect := Rect2(ox, oy, total_width, total_height)
	draw_rect(bg_rect, COLOR_BG)
	draw_rect(bg_rect, COLOR_BORDER, false, 1.0)

	# Category tabs
	var tab_width := (total_width - PADDING * 2) / CATEGORY_NAMES.size()
	for i in range(CATEGORY_NAMES.size()):
		var tx := ox + PADDING + i * tab_width
		var ty := oy + 2.0
		var tab_rect := Rect2(tx, ty, tab_width - 2.0, TAB_HEIGHT - 2.0)
		var tab_color: Color = COLOR_TAB_ACTIVE if i == _current_category else COLOR_TAB_INACTIVE
		draw_rect(tab_rect, tab_color)
		var border_color: Color = COLOR_SLOT_SELECTED if i == _current_category else COLOR_BORDER
		draw_rect(tab_rect, border_color, false, 1.0)
		# Tab text
		var text_size := _font.get_string_size(CATEGORY_NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		var text_x := tx + (tab_width - 2.0 - text_size.x) / 2.0
		var text_y := ty + (TAB_HEIGHT - 2.0 + text_size.y) / 2.0 - 2.0
		var text_col: Color = COLOR_TEXT if i == _current_category else COLOR_TEXT_DIM
		draw_string(_font, Vector2(text_x, text_y), CATEGORY_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_col)

	# Piece slots
	var slots_ox := ox + (total_width - slots_width) / 2.0
	var slots_oy := oy + TAB_HEIGHT + PADDING

	for i in range(cat_pieces.size()):
		var sx := slots_ox + i * (SLOT_SIZE + SLOT_GAP)
		var sy := slots_oy
		var slot_rect := Rect2(sx, sy, SLOT_SIZE, SLOT_SIZE)

		# Slot background
		draw_rect(slot_rect, COLOR_SLOT_BG)

		# Border: gold if selected, normal otherwise
		var is_selected := (i == _current_slot)
		var border_col: Color = COLOR_SLOT_SELECTED if is_selected else COLOR_SLOT_BORDER
		var border_w := 2.0 if is_selected else 1.0
		draw_rect(slot_rect, border_col, false, border_w)

		# Icon or text fallback
		var piece_data: BuildingPieceData = cat_pieces[i]["data"]
		if piece_data.icon:
			draw_texture_rect(piece_data.icon, Rect2(sx + 4, sy + 4, SLOT_SIZE - 8, SLOT_SIZE - 8), false)
		else:
			var short: String = PIECE_SHORT_LABELS.get(piece_data.piece_name, "??")
			var label_size := _font.get_string_size(short, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
			var lx := sx + (SLOT_SIZE - label_size.x) / 2.0
			var ly := sy + (SLOT_SIZE + label_size.y) / 2.0 - 2.0
			draw_string(_font, Vector2(lx, ly), short, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_TEXT)

		# Piece name below slot
		var name_text := piece_data.piece_name
		var name_size := _font_small.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		var nx := sx + (SLOT_SIZE - name_size.x) / 2.0
		var ny := sy + SLOT_SIZE + NAME_HEIGHT - 3.0
		var name_col: Color = COLOR_TEXT if is_selected else COLOR_TEXT_DIM
		draw_string(_font_small, Vector2(nx, ny), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, name_col)

	# Cost for selected piece
	if not cat_pieces.is_empty():
		var sel_data: BuildingPieceData = cat_pieces[_current_slot]["data"]
		var cost_text := "Cost: %d" % sel_data.get_build_cost(BuildingTier.Tier.TWIG)
		var cost_size := _font_small.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
		var cost_x := ox + total_width - PADDING - cost_size.x
		var cost_y := oy + TAB_HEIGHT + PADDING + SLOT_SIZE + NAME_HEIGHT + 2.0 + cost_size.y
		draw_string(_font_small, Vector2(cost_x, cost_y), cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_COST)

	# Hints bar
	var hint_text := "LMB: Place    R: Rotate    Scroll: Cycle    1-4: Category"
	var hint_size := _font_small.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	var hx := ox + (total_width - hint_size.x) / 2.0
	var hy := oy + total_height - 6.0
	draw_string(_font_small, Vector2(hx, hy), hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_HINT)
