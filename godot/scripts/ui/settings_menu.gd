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


func _ready() -> void:
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


func _on_back_pressed() -> void:
	var gs: Node = _get_game_settings()
	if gs:
		gs.save_settings()
		gs.settings_changed.emit()
	back_pressed.emit()


func _get_game_settings() -> Node:
	return Engine.get_singleton("GameSettings") if Engine.has_singleton("GameSettings") else get_node_or_null("/root/GameSettings")
