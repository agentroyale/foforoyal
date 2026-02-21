class_name MainMenu
extends Control
## Main menu screen — entry point of the game.
## Shows title, play/settings/quit buttons.
## Checks for updates on startup via AutoUpdater.

const GAME_WORLD_PATH := "res://scenes/world/game_world.tscn"
const SETTINGS_SCENE_PATH := "res://scenes/ui/settings_menu.tscn"
const MULTIPLAYER_SCENE_PATH := "res://scenes/ui/multiplayer_menu.tscn"
const CHARACTER_SELECT_PATH := "res://scenes/ui/character_select.tscn"
const BG_TEXTURE_PATH := "res://assets/textures/ui/menu_background.png"

@onready var button_container: VBoxContainer = %ButtonContainer
@onready var play_button: Button = %PlayButton
@onready var multiplayer_button: Button = %MultiplayerButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var background: TextureRect = %Background
@onready var bg_fallback: ColorRect = %BackgroundFallback

var _settings_instance: Control = null
var _multiplayer_instance: Control = null
var _char_select_instance: Control = null
var _update_label: Label = null
var _update_progress: ProgressBar = null
var _version_label: Label = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_background()
	_connect_buttons()
	_setup_version_label()
	_setup_update_ui()


func _setup_background() -> void:
	var tex := load(BG_TEXTURE_PATH) as Texture2D
	if tex:
		background.texture = tex
		background.visible = true
		bg_fallback.visible = false
	else:
		background.visible = false
		bg_fallback.visible = true


func _connect_buttons() -> void:
	play_button.pressed.connect(_on_play)
	multiplayer_button.pressed.connect(_on_multiplayer)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)


func _setup_version_label() -> void:
	_version_label = Label.new()
	_version_label.text = "v%s" % GameSettings.GAME_VERSION
	_version_label.add_theme_font_size_override("font_size", 16)
	_version_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
	_version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_version_label.offset_left = -120.0
	_version_label.offset_top = -35.0
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_version_label)


func _setup_update_ui() -> void:
	# Update status label (center-bottom)
	_update_label = Label.new()
	_update_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_update_label.offset_left = -200.0
	_update_label.offset_right = 200.0
	_update_label.offset_top = -80.0
	_update_label.offset_bottom = -55.0
	_update_label.add_theme_font_size_override("font_size", 16)
	_update_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_update_label.visible = false
	add_child(_update_label)

	# Progress bar
	_update_progress = ProgressBar.new()
	_update_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_update_progress.offset_left = -150.0
	_update_progress.offset_right = 150.0
	_update_progress.offset_top = -50.0
	_update_progress.offset_bottom = -35.0
	_update_progress.min_value = 0.0
	_update_progress.max_value = 100.0
	_update_progress.show_percentage = true
	_update_progress.visible = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bar_bg.set_corner_radius_all(4)
	_update_progress.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.7, 0.3, 0.9)
	bar_fill.set_corner_radius_all(4)
	_update_progress.add_theme_stylebox_override("fill", bar_fill)
	add_child(_update_progress)

	# Connect AutoUpdater signals
	var updater: Node = get_node_or_null("/root/AutoUpdater")
	if updater:
		updater.update_available.connect(_on_update_available)
		updater.update_progress.connect(_on_update_progress)
		updater.update_completed.connect(_on_update_completed)
		updater.update_failed.connect(_on_update_failed)
		updater.check_completed.connect(_on_check_completed)


func _on_check_completed(has_update: bool) -> void:
	if has_update:
		var updater: Node = get_node_or_null("/root/AutoUpdater")
		if not updater:
			return
		# Auto-start download
		_update_label.text = "Atualizando..."
		_update_label.visible = true
		_update_progress.visible = true
		_update_progress.value = 0.0
		play_button.disabled = true
		updater.start_download()


func _on_update_available(remote_version: String) -> void:
	_update_label.text = "Nova versao: %s" % remote_version
	_update_label.visible = true


func _on_update_progress(percent: float) -> void:
	_update_progress.value = percent
	_update_label.text = "Baixando atualização... %.0f%%" % percent


func _on_update_completed() -> void:
	_update_label.text = "Atualização completa! Reiniciando..."
	_update_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))


func _on_update_failed(reason: String) -> void:
	_update_label.text = reason if reason != "" else "Falha na atualização"
	_update_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_update_progress.visible = false
	play_button.disabled = false


func _on_play() -> void:
	if _char_select_instance:
		return
	var cs_scene := load(CHARACTER_SELECT_PATH) as PackedScene
	if not cs_scene:
		push_warning("MainMenu: could not load character select scene")
		return
	_char_select_instance = cs_scene.instantiate()
	_char_select_instance.back_pressed.connect(_on_char_select_back)
	_char_select_instance.character_confirmed.connect(_on_char_confirmed)
	add_child(_char_select_instance)
	button_container.visible = false


func _on_char_select_back() -> void:
	if _char_select_instance:
		_char_select_instance.queue_free()
		_char_select_instance = null
	button_container.visible = true


func _on_char_confirmed(_id: String) -> void:
	MatchManager.reset()
	# Always connect to the dedicated server
	var err := NetworkManager.join_server("game.chibiroyale.xyz", NetworkManager.DEFAULT_PORT)
	if err == OK:
		NetworkManager.connection_succeeded.connect(_on_auto_connect_ok, CONNECT_ONE_SHOT)
		NetworkManager.connection_failed.connect(_on_auto_connect_fail, CONNECT_ONE_SHOT)
	else:
		push_warning("[MainMenu] Failed to connect: %s" % error_string(err))


func _on_auto_connect_ok() -> void:
	get_tree().change_scene_to_file(GAME_WORLD_PATH)


func _on_auto_connect_fail() -> void:
	push_warning("[MainMenu] Server unreachable")
	NetworkManager.disconnect_from_server()
	button_container.visible = true
	if _char_select_instance:
		_char_select_instance.queue_free()
		_char_select_instance = null
	# Show error to player
	_update_label.text = "Servidor offline. Tente novamente."
	_update_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_update_label.visible = true


func _on_multiplayer() -> void:
	if _multiplayer_instance:
		return
	var mp_scene := load(MULTIPLAYER_SCENE_PATH) as PackedScene
	if not mp_scene:
		push_warning("MainMenu: could not load multiplayer scene")
		return
	_multiplayer_instance = mp_scene.instantiate()
	_multiplayer_instance.back_pressed.connect(_on_multiplayer_back)
	add_child(_multiplayer_instance)
	button_container.visible = false


func _on_multiplayer_back() -> void:
	if _multiplayer_instance:
		_multiplayer_instance.queue_free()
		_multiplayer_instance = null
	button_container.visible = true


func _on_settings() -> void:
	if _settings_instance:
		return
	var settings_scene := load(SETTINGS_SCENE_PATH) as PackedScene
	if not settings_scene:
		push_warning("MainMenu: could not load settings scene")
		return
	_settings_instance = settings_scene.instantiate()
	_settings_instance.back_pressed.connect(_on_settings_back)
	add_child(_settings_instance)
	button_container.visible = false


func _on_settings_back() -> void:
	if _settings_instance:
		_settings_instance.queue_free()
		_settings_instance = null
	button_container.visible = true


func _on_quit() -> void:
	get_tree().quit()
