class_name CraftingPanel
extends CanvasLayer
## Crafting UI panel: recipe list (left) + selected recipe details (right) + queue.
## Toggle with "crafting" action (C key). Shows mouse cursor when open.

signal panel_opened
signal panel_closed

const RECIPE_DIR := "res://resources/recipes/"

var is_open := false

var _all_recipes: Array[RecipeData] = []
var _selected_recipe: RecipeData = null
var _player_inv: PlayerInventory = null
var _crafting_queue: CraftingQueue = null
var _tech_tree: TechTree = null

# -- UI references (created in _build_ui) --
var _root_panel: PanelContainer
var _recipe_list_container: VBoxContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_desc: Label
var _detail_materials: VBoxContainer
var _craft_button: Button
var _queue_container: VBoxContainer
var _title_label: Label
var _close_button: Button
var _no_selection_label: Label

# -- Style cache --
var _style_bg: StyleBoxFlat
var _style_recipe_normal: StyleBoxFlat
var _style_recipe_hover: StyleBoxFlat
var _style_recipe_selected: StyleBoxFlat
var _style_recipe_dim: StyleBoxFlat
var _style_detail_bg: StyleBoxFlat
var _style_button_normal: StyleBoxFlat
var _style_button_disabled: StyleBoxFlat
var _style_queue_item: StyleBoxFlat

var _recipe_rows: Array[PanelContainer] = []
var _recipe_map: Dictionary = {}  # PanelContainer -> RecipeData
var _queue_progress_bars: Array[ProgressBar] = []


func _ready() -> void:
	layer = 5
	_create_styles()
	_build_ui()
	_load_recipes()
	_find_player.call_deferred()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("crafting"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_all()
	panel_opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	# Only re-capture mouse if no other UI panel is open
	if not _is_other_panel_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	panel_closed.emit()


func _is_other_panel_open() -> bool:
	## Check if inventory panel is open (avoid re-capturing mouse).
	for node in get_tree().root.get_children():
		if node is InventoryPanel and node.is_open:
			return true
		for child in node.get_children():
			if child is InventoryPanel and child.is_open:
				return true
	return false


# ─── Styles ───


func _create_styles() -> void:
	_style_bg = StyleBoxFlat.new()
	_style_bg.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	_style_bg.border_color = Color(0.25, 0.25, 0.3, 0.8)
	_style_bg.set_border_width_all(2)
	_style_bg.set_corner_radius_all(8)
	_style_bg.set_content_margin_all(8)

	_style_recipe_normal = StyleBoxFlat.new()
	_style_recipe_normal.bg_color = Color(0.1, 0.1, 0.14, 0.8)
	_style_recipe_normal.border_color = Color(0.2, 0.2, 0.25, 0.6)
	_style_recipe_normal.set_border_width_all(1)
	_style_recipe_normal.set_corner_radius_all(4)
	_style_recipe_normal.set_content_margin_all(6)

	_style_recipe_hover = StyleBoxFlat.new()
	_style_recipe_hover.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	_style_recipe_hover.border_color = Color(0.4, 0.4, 0.5, 0.8)
	_style_recipe_hover.set_border_width_all(1)
	_style_recipe_hover.set_corner_radius_all(4)
	_style_recipe_hover.set_content_margin_all(6)

	_style_recipe_selected = StyleBoxFlat.new()
	_style_recipe_selected.bg_color = Color(0.12, 0.15, 0.25, 0.95)
	_style_recipe_selected.border_color = Color(0.4, 0.6, 1.0, 0.9)
	_style_recipe_selected.set_border_width_all(2)
	_style_recipe_selected.set_corner_radius_all(4)
	_style_recipe_selected.set_content_margin_all(6)

	_style_recipe_dim = StyleBoxFlat.new()
	_style_recipe_dim.bg_color = Color(0.06, 0.06, 0.08, 0.6)
	_style_recipe_dim.border_color = Color(0.15, 0.15, 0.18, 0.4)
	_style_recipe_dim.set_border_width_all(1)
	_style_recipe_dim.set_corner_radius_all(4)
	_style_recipe_dim.set_content_margin_all(6)

	_style_detail_bg = StyleBoxFlat.new()
	_style_detail_bg.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	_style_detail_bg.border_color = Color(0.2, 0.2, 0.25, 0.6)
	_style_detail_bg.set_border_width_all(1)
	_style_detail_bg.set_corner_radius_all(6)
	_style_detail_bg.set_content_margin_all(12)

	_style_button_normal = StyleBoxFlat.new()
	_style_button_normal.bg_color = Color(0.15, 0.4, 0.15, 0.9)
	_style_button_normal.border_color = Color(0.3, 0.7, 0.3, 0.8)
	_style_button_normal.set_border_width_all(2)
	_style_button_normal.set_corner_radius_all(4)
	_style_button_normal.set_content_margin_all(8)

	_style_button_disabled = StyleBoxFlat.new()
	_style_button_disabled.bg_color = Color(0.12, 0.12, 0.12, 0.6)
	_style_button_disabled.border_color = Color(0.2, 0.2, 0.2, 0.4)
	_style_button_disabled.set_border_width_all(2)
	_style_button_disabled.set_corner_radius_all(4)
	_style_button_disabled.set_content_margin_all(8)

	_style_queue_item = StyleBoxFlat.new()
	_style_queue_item.bg_color = Color(0.08, 0.08, 0.12, 0.7)
	_style_queue_item.border_color = Color(0.2, 0.2, 0.25, 0.5)
	_style_queue_item.set_border_width_all(1)
	_style_queue_item.set_corner_radius_all(3)
	_style_queue_item.set_content_margin_all(4)


# ─── UI Construction ───


func _build_ui() -> void:
	# Root panel — compact centered area
	_root_panel = PanelContainer.new()
	_root_panel.add_theme_stylebox_override("panel", _style_bg)
	_root_panel.anchors_preset = Control.PRESET_CENTER
	_root_panel.anchor_left = 0.5
	_root_panel.anchor_top = 0.5
	_root_panel.anchor_right = 0.5
	_root_panel.anchor_bottom = 0.5
	_root_panel.offset_left = -340
	_root_panel.offset_top = -250
	_root_panel.offset_right = 340
	_root_panel.offset_bottom = 250
	_root_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_root_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_panel.add_child(root_vbox)

	# -- Title bar --
	var title_bar := HBoxContainer.new()
	root_vbox.add_child(title_bar)

	_title_label = Label.new()
	_title_label.text = "Crafting"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(_title_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(28, 28)
	_close_button.add_theme_font_size_override("font_size", 14)
	_close_button.pressed.connect(close)
	title_bar.add_child(_close_button)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	root_vbox.add_child(sep)

	# -- Main content: left (recipe list) + right (details) --
	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(main_hbox)

	# Left side: recipe list
	var left_panel := PanelContainer.new()
	left_panel.add_theme_stylebox_override("panel", _style_detail_bg)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.45
	main_hbox.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_vbox)

	var list_title := Label.new()
	list_title.text = "Recipes"
	list_title.add_theme_font_size_override("font_size", 13)
	list_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	left_vbox.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(scroll)

	_recipe_list_container = VBoxContainer.new()
	_recipe_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_recipe_list_container)

	# Right side: details + queue
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.55
	right_vbox.add_theme_constant_override("separation", 8)
	main_hbox.add_child(right_vbox)

	# Detail panel
	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", _style_detail_bg)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 0.6
	right_vbox.add_child(detail_panel)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.add_theme_constant_override("separation", 8)
	detail_panel.add_child(detail_vbox)

	# No selection label (shown when nothing selected)
	_no_selection_label = Label.new()
	_no_selection_label.text = "Select a recipe to view details"
	_no_selection_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_no_selection_label.add_theme_font_size_override("font_size", 14)
	_no_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_no_selection_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(_no_selection_label)

	# Detail header: icon + name
	var detail_header := HBoxContainer.new()
	detail_header.add_theme_constant_override("separation", 12)
	detail_vbox.add_child(detail_header)

	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(48, 48)
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_header.add_child(_detail_icon)

	var name_desc_vbox := VBoxContainer.new()
	name_desc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_header.add_child(name_desc_vbox)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 16)
	_detail_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	name_desc_vbox.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", 13)
	_detail_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_desc_vbox.add_child(_detail_desc)

	# Materials section
	var mat_title := Label.new()
	mat_title.text = "Required Materials"
	mat_title.add_theme_font_size_override("font_size", 14)
	mat_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	detail_vbox.add_child(mat_title)

	_detail_materials = VBoxContainer.new()
	_detail_materials.add_theme_constant_override("separation", 4)
	detail_vbox.add_child(_detail_materials)

	# Craft button
	_craft_button = Button.new()
	_craft_button.text = "CRAFT"
	_craft_button.custom_minimum_size = Vector2(0, 34)
	_craft_button.add_theme_font_size_override("font_size", 14)
	_craft_button.add_theme_stylebox_override("normal", _style_button_normal)
	_craft_button.add_theme_stylebox_override("disabled", _style_button_disabled)
	_craft_button.pressed.connect(_on_craft_pressed)
	detail_vbox.add_child(_craft_button)

	# Queue panel
	var queue_panel := PanelContainer.new()
	queue_panel.add_theme_stylebox_override("panel", _style_detail_bg)
	queue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_panel.size_flags_stretch_ratio = 0.4
	right_vbox.add_child(queue_panel)

	var queue_vbox := VBoxContainer.new()
	queue_vbox.add_theme_constant_override("separation", 4)
	queue_panel.add_child(queue_vbox)

	var queue_title := Label.new()
	queue_title.text = "Crafting Queue"
	queue_title.add_theme_font_size_override("font_size", 14)
	queue_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	queue_vbox.add_child(queue_title)

	var queue_scroll := ScrollContainer.new()
	queue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	queue_vbox.add_child(queue_scroll)

	_queue_container = VBoxContainer.new()
	_queue_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_container.add_theme_constant_override("separation", 3)
	queue_scroll.add_child(_queue_container)

	# Initially hide detail elements
	_set_detail_visible(false)


func _set_detail_visible(show: bool) -> void:
	_detail_icon.visible = show
	_detail_icon.get_parent().visible = show  # detail_header
	_detail_name.visible = show
	_detail_desc.visible = show
	_detail_materials.visible = show
	_craft_button.visible = show
	# The "Required Materials" label is _detail_materials' sibling
	var mat_label := _detail_materials.get_parent().get_child(_detail_materials.get_index() - 1)
	if mat_label is Label:
		mat_label.visible = show
	_no_selection_label.visible = not show


# ─── Data Loading ───


func _load_recipes() -> void:
	_all_recipes.clear()
	var dir := DirAccess.open(RECIPE_DIR)
	if not dir:
		push_warning("CraftingPanel: Cannot open recipe directory: %s" % RECIPE_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := RECIPE_DIR + file_name
			var res := load(path)
			if res is RecipeData:
				_all_recipes.append(res as RecipeData)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort alphabetically by recipe_name
	_all_recipes.sort_custom(func(a: RecipeData, b: RecipeData) -> bool:
		return a.recipe_name.naturalnocasecmp_to(b.recipe_name) < 0
	)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		# Fallback: sibling Player node
		var player := get_parent().get_node_or_null("Player")
		if player:
			_player_inv = player.get_node_or_null("PlayerInventory") as PlayerInventory
			_crafting_queue = player.get_node_or_null("CraftingQueue") as CraftingQueue
	else:
		_player_inv = players[0].get_node_or_null("PlayerInventory") as PlayerInventory
		_crafting_queue = players[0].get_node_or_null("CraftingQueue") as CraftingQueue

	if _crafting_queue:
		_crafting_queue.queue_changed.connect(_on_queue_changed)
		_crafting_queue.craft_progress.connect(_on_craft_progress)
		_crafting_queue.craft_completed.connect(_on_craft_completed)

	if _player_inv:
		_player_inv.hotbar.inventory_changed.connect(_on_inventory_changed)
		_player_inv.main_inventory.inventory_changed.connect(_on_inventory_changed)

	_build_recipe_list()


## Returns the number of loaded recipes (useful for tests).
func get_recipe_count() -> int:
	return _all_recipes.size()


## Allows setting recipes externally (for testing without loading from disk).
func set_recipes(recipes: Array[RecipeData]) -> void:
	_all_recipes = recipes
	_build_recipe_list()


## Allows setting player inventory externally (for testing).
func set_player_inventory(inv: PlayerInventory) -> void:
	_player_inv = inv
	if _player_inv:
		if not _player_inv.hotbar.inventory_changed.is_connected(_on_inventory_changed):
			_player_inv.hotbar.inventory_changed.connect(_on_inventory_changed)
		if not _player_inv.main_inventory.inventory_changed.is_connected(_on_inventory_changed):
			_player_inv.main_inventory.inventory_changed.connect(_on_inventory_changed)


## Allows setting crafting queue externally (for testing).
func set_crafting_queue(cq: CraftingQueue) -> void:
	_crafting_queue = cq
	if _crafting_queue:
		if not _crafting_queue.queue_changed.is_connected(_on_queue_changed):
			_crafting_queue.queue_changed.connect(_on_queue_changed)
		if not _crafting_queue.craft_progress.is_connected(_on_craft_progress):
			_crafting_queue.craft_progress.connect(_on_craft_progress)
		if not _crafting_queue.craft_completed.is_connected(_on_craft_completed):
			_crafting_queue.craft_completed.connect(_on_craft_completed)


# ─── Recipe List ───


func _build_recipe_list() -> void:
	# Clear existing rows
	for child in _recipe_list_container.get_children():
		child.queue_free()
	_recipe_rows.clear()
	_recipe_map.clear()

	for recipe in _all_recipes:
		var row := _create_recipe_row(recipe)
		_recipe_list_container.add_child(row)
		_recipe_rows.append(row)
		_recipe_map[row] = recipe


func _create_recipe_row(recipe: RecipeData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_recipe_normal)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(hbox)

	# Output icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	if recipe.output_item and recipe.output_item.icon:
		icon.texture = recipe.output_item.icon
	hbox.add_child(icon)

	# Name + ingredients summary
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	info_vbox.add_theme_constant_override("separation", 0)
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = recipe.recipe_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	info_vbox.add_child(name_label)

	# Ingredients summary line
	var ing_hbox := HBoxContainer.new()
	ing_hbox.add_theme_constant_override("separation", 6)
	ing_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	info_vbox.add_child(ing_hbox)

	for i in range(recipe.get_ingredient_count()):
		var item := recipe.get_ingredient_item(i)
		var amount := recipe.get_ingredient_amount(i)
		if not item:
			continue

		var ing_label := Label.new()
		ing_label.text = "%s x%d" % [item.item_name, amount]
		ing_label.add_theme_font_size_override("font_size", 11)
		ing_label.mouse_filter = Control.MOUSE_FILTER_PASS
		# Color will be set during refresh
		ing_label.set_meta("ingredient_index", i)
		ing_label.set_meta("recipe", recipe)
		ing_hbox.add_child(ing_label)

	# Connect hover/click
	panel.gui_input.connect(_on_recipe_row_input.bind(panel))
	panel.mouse_entered.connect(_on_recipe_row_hover.bind(panel, true))
	panel.mouse_exited.connect(_on_recipe_row_hover.bind(panel, false))

	return panel


func _on_recipe_row_input(event: InputEvent, panel: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var recipe: RecipeData = _recipe_map.get(panel)
		if recipe:
			_select_recipe(recipe)


func _on_recipe_row_hover(panel: PanelContainer, entered: bool) -> void:
	if _recipe_map.get(panel) == _selected_recipe:
		return  # Don't change selected style
	if entered:
		panel.add_theme_stylebox_override("panel", _style_recipe_hover)
	else:
		_apply_recipe_row_style(panel)


func _select_recipe(recipe: RecipeData) -> void:
	_selected_recipe = recipe
	_refresh_recipe_list_styles()
	_refresh_detail()


# ─── Refresh ───


func _refresh_all() -> void:
	_refresh_recipe_list_styles()
	_refresh_detail()
	_refresh_queue()


func _refresh_recipe_list_styles() -> void:
	for row in _recipe_rows:
		_apply_recipe_row_style(row)


func _apply_recipe_row_style(row: PanelContainer) -> void:
	var recipe: RecipeData = _recipe_map.get(row)
	if not recipe:
		return

	if recipe == _selected_recipe:
		row.add_theme_stylebox_override("panel", _style_recipe_selected)
	elif _can_craft_recipe(recipe):
		row.add_theme_stylebox_override("panel", _style_recipe_normal)
	else:
		row.add_theme_stylebox_override("panel", _style_recipe_dim)

	# Update ingredient label colors
	_update_ingredient_colors(row, recipe)


func _update_ingredient_colors(row: PanelContainer, recipe: RecipeData) -> void:
	# Find all ingredient labels in the row
	var hbox := row.get_child(0)  # HBoxContainer
	if not hbox or hbox.get_child_count() < 2:
		return
	var info_vbox := hbox.get_child(1)  # VBoxContainer with name + ingredients
	if not info_vbox or info_vbox.get_child_count() < 2:
		return
	var ing_hbox := info_vbox.get_child(1)  # HBoxContainer with ingredient labels

	for label_node in ing_hbox.get_children():
		if not label_node is Label:
			continue
		var label := label_node as Label
		if not label.has_meta("ingredient_index"):
			continue
		var idx: int = label.get_meta("ingredient_index")
		var item := recipe.get_ingredient_item(idx)
		var needed := recipe.get_ingredient_amount(idx)
		var have := _get_player_item_count(item)
		if have >= needed:
			label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
		else:
			label.add_theme_color_override("font_color", Color(0.85, 0.3, 0.3))


func _refresh_detail() -> void:
	if not _selected_recipe:
		_set_detail_visible(false)
		return

	_set_detail_visible(true)

	var recipe := _selected_recipe

	# Icon
	if recipe.output_item and recipe.output_item.icon:
		_detail_icon.texture = recipe.output_item.icon
	else:
		_detail_icon.texture = null

	# Name and description
	_detail_name.text = recipe.recipe_name
	var desc := recipe.description
	if recipe.output_item and recipe.output_item.description and desc.is_empty():
		desc = recipe.output_item.description
	_detail_desc.text = desc if not desc.is_empty() else "No description."

	# Materials list
	for child in _detail_materials.get_children():
		child.queue_free()

	for i in range(recipe.get_ingredient_count()):
		var item := recipe.get_ingredient_item(i)
		var needed := recipe.get_ingredient_amount(i)
		if not item:
			continue

		var mat_row := HBoxContainer.new()
		mat_row.add_theme_constant_override("separation", 8)
		_detail_materials.add_child(mat_row)

		# Small ingredient icon
		var mat_icon := TextureRect.new()
		mat_icon.custom_minimum_size = Vector2(24, 24)
		mat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		if item.icon:
			mat_icon.texture = item.icon
		mat_row.add_child(mat_icon)

		var have := _get_player_item_count(item)
		var mat_label := Label.new()
		mat_label.text = "%s  %d / %d" % [item.item_name, have, needed]
		mat_label.add_theme_font_size_override("font_size", 13)
		if have >= needed:
			mat_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
		else:
			mat_label.add_theme_color_override("font_color", Color(0.85, 0.3, 0.3))
		mat_row.add_child(mat_label)

	# Craft time
	var time_label := Label.new()
	time_label.text = "Craft time: %.1fs" % recipe.craft_time
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_detail_materials.add_child(time_label)

	# Output count if > 1
	if recipe.output_count > 1:
		var out_label := Label.new()
		out_label.text = "Produces: x%d" % recipe.output_count
		out_label.add_theme_font_size_override("font_size", 12)
		out_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_detail_materials.add_child(out_label)

	# Workbench requirement
	if recipe.workbench_tier > RecipeData.WorkbenchTier.HAND:
		var wb_label := Label.new()
		wb_label.text = "Requires: Workbench T%d" % recipe.workbench_tier
		wb_label.add_theme_font_size_override("font_size", 12)
		wb_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		_detail_materials.add_child(wb_label)

	# Update craft button state
	_update_craft_button()


func _update_craft_button() -> void:
	if not _selected_recipe:
		_craft_button.disabled = true
		_craft_button.text = "CRAFT"
		return

	var can := _can_craft_recipe(_selected_recipe)
	_craft_button.disabled = not can

	if _crafting_queue and _crafting_queue.get_queue_size() >= CraftingQueue.MAX_QUEUE_SIZE:
		_craft_button.disabled = true
		_craft_button.text = "QUEUE FULL"
	elif can:
		_craft_button.text = "CRAFT"
	else:
		_craft_button.text = "INSUFFICIENT"


func _refresh_queue() -> void:
	for child in _queue_container.get_children():
		child.queue_free()
	_queue_progress_bars.clear()

	if not _crafting_queue:
		return

	for i in range(_crafting_queue.queue.size()):
		var entry: Dictionary = _crafting_queue.queue[i]
		var recipe: RecipeData = entry["recipe"]

		var item_panel := PanelContainer.new()
		item_panel.add_theme_stylebox_override("panel", _style_queue_item)
		_queue_container.add_child(item_panel)

		var item_vbox := VBoxContainer.new()
		item_vbox.add_theme_constant_override("separation", 2)
		item_panel.add_child(item_vbox)

		var item_hbox := HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 6)
		item_vbox.add_child(item_hbox)

		# Small icon
		var q_icon := TextureRect.new()
		q_icon.custom_minimum_size = Vector2(20, 20)
		q_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		q_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		if recipe.output_item and recipe.output_item.icon:
			q_icon.texture = recipe.output_item.icon
		item_hbox.add_child(q_icon)

		var q_name := Label.new()
		q_name.text = recipe.recipe_name
		q_name.add_theme_font_size_override("font_size", 12)
		q_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_hbox.add_child(q_name)

		# Cancel button
		var cancel_btn := Button.new()
		cancel_btn.text = "X"
		cancel_btn.custom_minimum_size = Vector2(24, 24)
		cancel_btn.add_theme_font_size_override("font_size", 10)
		cancel_btn.pressed.connect(_on_cancel_queue_item.bind(i))
		item_hbox.add_child(cancel_btn)

		# Progress bar
		var progress := ProgressBar.new()
		progress.custom_minimum_size = Vector2(0, 12)
		progress.min_value = 0.0
		progress.max_value = 1.0
		progress.show_percentage = false

		# Style the progress bar
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.1, 0.1, 0.12, 0.8)
		bar_bg.set_corner_radius_all(2)
		progress.add_theme_stylebox_override("background", bar_bg)

		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.3, 0.7, 0.3, 0.9) if i == 0 else Color(0.3, 0.3, 0.5, 0.6)
		bar_fill.set_corner_radius_all(2)
		progress.add_theme_stylebox_override("fill", bar_fill)

		if i == 0:
			progress.value = _crafting_queue.get_current_progress()
		else:
			progress.value = 0.0

		item_vbox.add_child(progress)
		_queue_progress_bars.append(progress)

	if _crafting_queue.queue.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Queue empty"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_queue_container.add_child(empty_label)


# ─── Helpers ───


func _can_craft_recipe(recipe: RecipeData) -> bool:
	if not _player_inv:
		return false
	var tier: RecipeData.WorkbenchTier = RecipeData.WorkbenchTier.HAND
	if _crafting_queue:
		tier = _crafting_queue.available_tier
	var result := CraftingSystem.can_craft(recipe, _player_inv, tier, _tech_tree)
	return result == CraftingSystem.CraftResult.SUCCESS


func _get_player_item_count(item: ItemData) -> int:
	if not _player_inv or not item:
		return 0
	return _player_inv.hotbar.get_item_count(item) + _player_inv.main_inventory.get_item_count(item)


# ─── Callbacks ───


func _on_craft_pressed() -> void:
	if not _selected_recipe:
		return
	if not _crafting_queue:
		push_warning("CraftingPanel: No CraftingQueue connected")
		return

	var result := _crafting_queue.enqueue(_selected_recipe)
	if result == CraftingSystem.CraftResult.SUCCESS:
		_refresh_all()
	else:
		push_warning("CraftingPanel: Craft failed with result %d" % result)


func _on_cancel_queue_item(index: int) -> void:
	if _crafting_queue:
		_crafting_queue.cancel(index)


func _on_queue_changed() -> void:
	if is_open:
		_refresh_all()


func _on_craft_progress(recipe: RecipeData, progress: float) -> void:
	if is_open and not _queue_progress_bars.is_empty():
		_queue_progress_bars[0].value = progress


func _on_craft_completed(_recipe: RecipeData) -> void:
	if is_open:
		_refresh_all()


func _on_inventory_changed() -> void:
	if is_open:
		_refresh_all()
