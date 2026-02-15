class_name PauseMenu
extends CanvasLayer
## In-game pause menu overlay.
## Pauses the tree and shows resume/settings/main menu/quit buttons.
## Process mode ALWAYS so it runs while tree is paused.

const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
const SETTINGS_SCENE_PATH := "res://scenes/ui/settings_menu.tscn"

var is_paused := false

@onready var overlay: ColorRect = %Overlay
@onready var button_container: VBoxContainer = %ButtonContainer
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton

var _settings_instance: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_connect_buttons()
	_hide_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if is_paused:
			_unpause()
		else:
			_pause()


func _connect_buttons() -> void:
	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	main_menu_button.pressed.connect(_on_main_menu)
	quit_button.pressed.connect(_on_quit)


func _pause() -> void:
	is_paused = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_menu()


func _unpause() -> void:
	_close_settings()
	is_paused = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_hide_menu()


func _show_menu() -> void:
	overlay.visible = true
	button_container.visible = true


func _hide_menu() -> void:
	overlay.visible = false
	button_container.visible = false


func _on_resume() -> void:
	_unpause()


func _on_settings() -> void:
	if _settings_instance:
		return
	var settings_scene := load(SETTINGS_SCENE_PATH) as PackedScene
	if not settings_scene:
		push_warning("PauseMenu: could not load settings scene")
		return
	_settings_instance = settings_scene.instantiate()
	_settings_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_instance.back_pressed.connect(_on_settings_back)
	add_child(_settings_instance)
	button_container.visible = false


func _on_settings_back() -> void:
	_close_settings()
	button_container.visible = true


func _close_settings() -> void:
	if _settings_instance:
		_settings_instance.queue_free()
		_settings_instance = null


func _on_main_menu() -> void:
	_close_settings()
	is_paused = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_quit() -> void:
	get_tree().quit()
