class_name InventoryPanel
extends CanvasLayer
## Full inventory UI panel. Toggled with Tab key.
## Displays hotbar (6 slots) + main inventory (24 slots) in a grid layout.
## Connects to PlayerInventory signals to stay in sync.

signal opened
signal closed

const COLUMNS := 6
const HOTBAR_SIZE := 6
const MAIN_SIZE := 24
const SLOT_SIZE := 64
const SLOT_SPACING := 4
const ICON_MARGIN := 6

var is_open := false
var _player_inv: PlayerInventory = null

var _hotbar_slot_panels: Array[PanelContainer] = []
var _hotbar_slot_icons: Array[TextureRect] = []
var _hotbar_slot_counts: Array[Label] = []
var _main_slot_panels: Array[PanelContainer] = []
var _main_slot_icons: Array[TextureRect] = []
var _main_slot_counts: Array[Label] = []

var _style_empty: StyleBoxFlat
var _style_occupied: StyleBoxFlat
var _style_hovered: StyleBoxFlat
var _style_panel_bg: StyleBoxFlat

@onready var _background: ColorRect = $Background
@onready var _panel: PanelContainer = $CenterPanel
@onready var _title: Label = $CenterPanel/MarginContainer/VBox/Header/Title
@onready var _close_button: Button = $CenterPanel/MarginContainer/VBox/Header/CloseButton
@onready var _hotbar_grid: GridContainer = $CenterPanel/MarginContainer/VBox/HotbarSection/HotbarGrid
@onready var _main_grid: GridContainer = $CenterPanel/MarginContainer/VBox/MainSection/MainGrid
@onready var _tooltip_panel: PanelContainer = $TooltipPanel
@onready var _tooltip_name: Label = $TooltipPanel/TooltipMargin/TooltipVBox/TooltipName
@onready var _tooltip_desc: Label = $TooltipPanel/TooltipMargin/TooltipVBox/TooltipDesc


func _ready() -> void:
	layer = 5
	_create_styles()
	_build_slot_widgets(_hotbar_grid, HOTBAR_SIZE, _hotbar_slot_panels, _hotbar_slot_icons, _hotbar_slot_counts)
	_build_slot_widgets(_main_grid, MAIN_SIZE, _main_slot_panels, _main_slot_icons, _main_slot_counts)
	_close_button.pressed.connect(_toggle)
	_tooltip_panel.visible = false
	_set_visible(false)
	_connect_inventory.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if is_open:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	if is_open:
		return
	is_open = true
	_set_visible(true)
	_refresh_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit()


func close_inventory() -> void:
	if not is_open:
		return
	is_open = false
	_set_visible(false)
	_tooltip_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _set_visible(show: bool) -> void:
	_background.visible = show
	_panel.visible = show


# ── Style Creation ──

func _create_styles() -> void:
	_style_empty = StyleBoxFlat.new()
	_style_empty.bg_color = Color(0.08, 0.08, 0.1, 0.6)
	_style_empty.border_color = Color(0.2, 0.2, 0.25, 0.6)
	_style_empty.set_border_width_all(1)
	_style_empty.set_corner_radius_all(4)

	_style_occupied = StyleBoxFlat.new()
	_style_occupied.bg_color = Color(0.12, 0.12, 0.16, 0.8)
	_style_occupied.border_color = Color(0.35, 0.35, 0.4, 0.8)
	_style_occupied.set_border_width_all(2)
	_style_occupied.set_corner_radius_all(4)

	_style_hovered = StyleBoxFlat.new()
	_style_hovered.bg_color = Color(0.18, 0.18, 0.22, 0.9)
	_style_hovered.border_color = Color(0.5, 0.5, 0.55, 0.9)
	_style_hovered.set_border_width_all(2)
	_style_hovered.set_corner_radius_all(4)

	_style_panel_bg = StyleBoxFlat.new()
	_style_panel_bg.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	_style_panel_bg.border_color = Color(0.25, 0.25, 0.3, 0.8)
	_style_panel_bg.set_border_width_all(2)
	_style_panel_bg.set_corner_radius_all(8)

	_panel.add_theme_stylebox_override("panel", _style_panel_bg)


# ── Slot Widget Building ──

func _build_slot_widgets(
	grid: GridContainer,
	count: int,
	panels: Array[PanelContainer],
	icons: Array[TextureRect],
	counts: Array[Label]
) -> void:
	grid.columns = COLUMNS
	for i in range(count):
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_panel.add_theme_stylebox_override("panel", _style_empty)
		slot_panel.mouse_filter = Control.MOUSE_FILTER_PASS

		# Icon centered in slot
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(SLOT_SIZE - ICON_MARGIN * 2, SLOT_SIZE - ICON_MARGIN * 2)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(ICON_MARGIN, ICON_MARGIN)
		slot_panel.add_child(icon)

		# Count label at bottom-right
		var count_label := Label.new()
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
		count_label.position = Vector2(2, 2)
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		count_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
		count_label.add_theme_constant_override("shadow_offset_x", 1)
		count_label.add_theme_constant_override("shadow_offset_y", 1)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.text = ""
		slot_panel.add_child(count_label)

		# Hover events for tooltip
		var is_hotbar := (grid == _hotbar_grid)
		var slot_index := i
		slot_panel.mouse_entered.connect(_on_slot_mouse_entered.bind(is_hotbar, slot_index))
		slot_panel.mouse_exited.connect(_on_slot_mouse_exited.bind(is_hotbar, slot_index))

		grid.add_child(slot_panel)
		panels.append(slot_panel)
		icons.append(icon)
		counts.append(count_label)


# ── Inventory Connection ──

func _connect_inventory() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		var game_world := get_parent()
		if game_world:
			var player := game_world.get_node_or_null("Player")
			if player:
				_player_inv = player.get_node_or_null("PlayerInventory") as PlayerInventory
	else:
		_player_inv = players[0].get_node_or_null("PlayerInventory") as PlayerInventory

	if _player_inv:
		_player_inv.hotbar.inventory_changed.connect(_refresh_all)
		_player_inv.main_inventory.inventory_changed.connect(_refresh_all)
		_player_inv.hotbar.slot_changed.connect(_on_hotbar_slot_changed)
		_player_inv.main_inventory.slot_changed.connect(_on_main_slot_changed)


func set_player_inventory(pi: PlayerInventory) -> void:
	## Allows external code (e.g. HUD) to set the inventory reference directly.
	if _player_inv:
		# Disconnect old signals
		if _player_inv.hotbar.inventory_changed.is_connected(_refresh_all):
			_player_inv.hotbar.inventory_changed.disconnect(_refresh_all)
		if _player_inv.main_inventory.inventory_changed.is_connected(_refresh_all):
			_player_inv.main_inventory.inventory_changed.disconnect(_refresh_all)
		if _player_inv.hotbar.slot_changed.is_connected(_on_hotbar_slot_changed):
			_player_inv.hotbar.slot_changed.disconnect(_on_hotbar_slot_changed)
		if _player_inv.main_inventory.slot_changed.is_connected(_on_main_slot_changed):
			_player_inv.main_inventory.slot_changed.disconnect(_on_main_slot_changed)

	_player_inv = pi
	if _player_inv:
		_player_inv.hotbar.inventory_changed.connect(_refresh_all)
		_player_inv.main_inventory.inventory_changed.connect(_refresh_all)
		_player_inv.hotbar.slot_changed.connect(_on_hotbar_slot_changed)
		_player_inv.main_inventory.slot_changed.connect(_on_main_slot_changed)
		if is_open:
			_refresh_all()


# ── Slot Refresh ──

func _on_hotbar_slot_changed(slot_index: int) -> void:
	if is_open:
		_refresh_slot(true, slot_index)


func _on_main_slot_changed(slot_index: int) -> void:
	if is_open:
		_refresh_slot(false, slot_index)


func _refresh_all() -> void:
	if not _player_inv:
		return
	for i in range(HOTBAR_SIZE):
		_refresh_slot(true, i)
	for i in range(MAIN_SIZE):
		_refresh_slot(false, i)


func _refresh_slot(is_hotbar: bool, index: int) -> void:
	if not _player_inv:
		return
	var inv: Inventory = _player_inv.hotbar if is_hotbar else _player_inv.main_inventory
	var panels: Array[PanelContainer] = _hotbar_slot_panels if is_hotbar else _main_slot_panels
	var icons: Array[TextureRect] = _hotbar_slot_icons if is_hotbar else _main_slot_icons
	var count_labels: Array[Label] = _hotbar_slot_counts if is_hotbar else _main_slot_counts

	if index < 0 or index >= panels.size():
		return

	var slot := inv.get_slot(index)
	var slot_empty := slot.is_empty()

	if slot_empty:
		icons[index].texture = null
		count_labels[index].text = ""
		panels[index].add_theme_stylebox_override("panel", _style_empty)
	else:
		var item: ItemData = slot["item"]
		var count: int = slot["count"]
		icons[index].texture = item.icon
		count_labels[index].text = str(count) if count > 1 else ""
		panels[index].add_theme_stylebox_override("panel", _style_occupied)


# ── Tooltip ──

func _on_slot_mouse_entered(is_hotbar: bool, slot_index: int) -> void:
	if not is_open or not _player_inv:
		return
	var inv: Inventory = _player_inv.hotbar if is_hotbar else _player_inv.main_inventory
	var slot := inv.get_slot(slot_index)
	if slot.is_empty():
		_tooltip_panel.visible = false
		return

	var item: ItemData = slot["item"]
	_tooltip_name.text = item.item_name
	_tooltip_desc.text = item.description if item.description != "" else "No description."
	_tooltip_panel.visible = true

	# Apply hover style to the slot
	var panels: Array[PanelContainer] = _hotbar_slot_panels if is_hotbar else _main_slot_panels
	if slot_index >= 0 and slot_index < panels.size():
		panels[slot_index].add_theme_stylebox_override("panel", _style_hovered)


func _on_slot_mouse_exited(is_hotbar: bool, slot_index: int) -> void:
	_tooltip_panel.visible = false
	if not _player_inv:
		return
	# Restore normal style
	_refresh_slot(is_hotbar, slot_index)


func _process(_delta: float) -> void:
	if is_open and _tooltip_panel.visible:
		# Follow mouse cursor with offset
		var mouse_pos := get_viewport().get_mouse_position()
		var viewport_size := get_viewport().get_visible_rect().size
		var tooltip_size := _tooltip_panel.size

		var pos := mouse_pos + Vector2(16, 16)
		# Keep tooltip on screen
		if pos.x + tooltip_size.x > viewport_size.x:
			pos.x = mouse_pos.x - tooltip_size.x - 8
		if pos.y + tooltip_size.y > viewport_size.y:
			pos.y = mouse_pos.y - tooltip_size.y - 8

		_tooltip_panel.position = pos
