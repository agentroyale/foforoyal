class_name SettingsMenu
extends Control
## Settings panel — standalone scene, embedded in main menu and pause menu.
## Reads/writes values through the GameSettings autoload.

signal back_pressed

@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value: Label = %SensitivityValue
@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_value: Label = %SFXValue
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var fov_slider: HSlider = %FOVSlider
@onready var fov_value: Label = %FOVValue
@onready var vsync_check: CheckButton = %VSyncCheck
@onready var back_button: Button = %BackButton

## Mobile-only controls (created dynamically)
var _touch_sens_slider: HSlider
var _touch_sens_value: Label
var _touch_opacity_slider: HSlider
var _touch_opacity_value: Label
var _quality_option: OptionButton


func _ready() -> void:
	_build_mobile_settings()
	_load_from_settings()
	_connect_signals()


func _load_from_settings() -> void:
	var gs: Node = _get_game_settings()
	if not gs:
		return
	sensitivity_slider.value = gs.mouse_sensitivity
	master_slider.value = gs.master_volume
	sfx_slider.value = gs.sfx_volume
	fullscreen_check.button_pressed = gs.fullscreen
	fov_slider.value = gs.fov
	vsync_check.button_pressed = gs.vsync
	# Mobile settings
	if _touch_sens_slider:
		_touch_sens_slider.value = gs.touch_sensitivity
	if _touch_opacity_slider:
		_touch_opacity_slider.value = gs.touch_opacity
	if _quality_option:
		_quality_option.selected = gs.mobile_quality
	_update_labels()


func _connect_signals() -> void:
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	fov_slider.value_changed.connect(_on_fov_changed)
	vsync_check.toggled.connect(_on_vsync_toggled)
	back_button.pressed.connect(_on_back_pressed)


func _update_labels() -> void:
	sensitivity_value.text = "%.1f" % sensitivity_slider.value
	master_value.text = "%d%%" % int(master_slider.value)
	sfx_value.text = "%d%%" % int(sfx_slider.value)
	fov_value.text = "%d" % int(fov_slider.value)
	if _touch_sens_value:
		_touch_sens_value.text = "%.1f" % _touch_sens_slider.value
	if _touch_opacity_value:
		_touch_opacity_value.text = "%d%%" % int(_touch_opacity_slider.value * 100)


func _on_sensitivity_changed(value: float) -> void:
	var gs: Node = _get_game_settings()
	if gs:
		gs.mouse_sensitivity = value
	sensitivity_value.text = "%.1f" % value


func _on_master_changed(value: float) -> void:
	var gs: Node = _get_game_settings()
	if gs:
		gs.master_volume = value
		gs._apply_audio()
	master_value.text = "%d%%" % int(value)


func _on_sfx_changed(value: float) -> void:
	var gs: Node = _get_game_settings()
	if gs:
		gs.sfx_volume = value
		gs._apply_audio()
	sfx_value.text = "%d%%" % int(value)


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	var gs: Node = _get_game_settings()
	if gs:
		gs.fullscreen = toggled_on
		gs._apply_display()


func _on_fov_changed(value: float) -> void:
	var gs: Node = _get_game_settings()
	if gs:
		gs.fov = value
	fov_value.text = "%d" % int(value)


func _on_vsync_toggled(toggled_on: bool) -> void:
	var gs: Node = _get_game_settings()
	if gs:
		gs.vsync = toggled_on
		gs._apply_display()


func _build_mobile_settings() -> void:
	var mi: Node = get_node_or_null("/root/MobileInput")
	if not mi or not mi.is_mobile:
		return
	# Insert mobile settings before the back button separator
	var vbox: VBoxContainer = back_button.get_parent()

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)
	vbox.move_child(sep, back_button.get_index() - 1)

	var mobile_label := Label.new()
	mobile_label.text = "MOBILE"
	mobile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mobile_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(mobile_label)
	vbox.move_child(mobile_label, sep.get_index() + 1)

	# Touch Sensitivity
	var ts_row := HBoxContainer.new()
	vbox.add_child(ts_row)
	vbox.move_child(ts_row, mobile_label.get_index() + 1)
	var ts_label := Label.new()
	ts_label.text = "Touch Sensitivity"
	ts_label.custom_minimum_size.x = 180
	ts_row.add_child(ts_label)
	_touch_sens_slider = HSlider.new()
	_touch_sens_slider.min_value = 0.1
	_touch_sens_slider.max_value = 3.0
	_touch_sens_slider.step = 0.1
	_touch_sens_slider.value = 1.0
	_touch_sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ts_row.add_child(_touch_sens_slider)
	_touch_sens_value = Label.new()
	_touch_sens_value.custom_minimum_size.x = 50
	_touch_sens_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ts_row.add_child(_touch_sens_value)
	_touch_sens_slider.value_changed.connect(_on_touch_sens_changed)

	# Touch Opacity
	var to_row := HBoxContainer.new()
	vbox.add_child(to_row)
	vbox.move_child(to_row, ts_row.get_index() + 1)
	var to_label := Label.new()
	to_label.text = "Touch Opacity"
	to_label.custom_minimum_size.x = 180
	to_row.add_child(to_label)
	_touch_opacity_slider = HSlider.new()
	_touch_opacity_slider.min_value = 0.2
	_touch_opacity_slider.max_value = 1.0
	_touch_opacity_slider.step = 0.05
	_touch_opacity_slider.value = 0.6
	_touch_opacity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	to_row.add_child(_touch_opacity_slider)
	_touch_opacity_value = Label.new()
	_touch_opacity_value.custom_minimum_size.x = 50
	_touch_opacity_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	to_row.add_child(_touch_opacity_value)
	_touch_opacity_slider.value_changed.connect(_on_touch_opacity_changed)

	# Quality Preset
	var q_row := HBoxContainer.new()
	vbox.add_child(q_row)
	vbox.move_child(q_row, to_row.get_index() + 1)
	var q_label := Label.new()
	q_label.text = "Graphics Quality"
	q_label.custom_minimum_size.x = 180
	q_row.add_child(q_label)
	_quality_option = OptionButton.new()
	_quality_option.add_item("Low", 0)
	_quality_option.add_item("Medium", 1)
	_quality_option.add_item("High", 2)
	_quality_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_row.add_child(_quality_option)
	_quality_option.item_selected.connect(_on_quality_changed)


func _on_touch_sens_changed(value: float) -> void:
	var gs: Node = _get_game_settings()
	if gs:
		gs.touch_sensitivity = value
	var mi: Node = get_node_or_null("/root/MobileInput")
	if mi:
		mi.touch_sensitivity = value
	if _touch_sens_value:
		_touch_sens_value.text = "%.1f" % value


func _on_touch_opacity_changed(value: float) -> void:
	var gs: Node = _get_game_settings()
	if gs:
		gs.touch_opacity = value
		gs.settings_changed.emit()
	if _touch_opacity_value:
		_touch_opacity_value.text = "%d%%" % int(value * 100)


func _on_quality_changed(index: int) -> void:
	var gs: Node = _get_game_settings()
	if gs:
		gs.mobile_quality = index
		gs.settings_changed.emit()


func _on_back_pressed() -> void:
	var gs: Node = _get_game_settings()
	if gs:
		gs.save_settings()
		gs.settings_changed.emit()
	back_pressed.emit()


func _get_game_settings() -> Node:
	return Engine.get_singleton("GameSettings") if Engine.has_singleton("GameSettings") else get_node_or_null("/root/GameSettings")
