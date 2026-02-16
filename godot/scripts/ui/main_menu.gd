class_name MainMenu
extends Control
## Main menu screen — entry point of the game.
## Shows title, play/settings/quit buttons.

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


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_background()
	_connect_buttons()


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
	get_tree().change_scene_to_file(GAME_WORLD_PATH)


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
