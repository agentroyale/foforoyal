extends Node
## Global game settings manager.
## Autoload singleton — persists settings to user://settings.cfg.
## Other scripts read values directly: GameSettings.mouse_sensitivity, etc.

signal settings_changed

const CONFIG_PATH := "user://settings.cfg"

## Gameplay
var mouse_sensitivity: float = 1.0
var fov: float = 75.0

## Audio
var master_volume: float = 80.0
var sfx_volume: float = 80.0

## Multiplayer
var player_name: String = "Fofolete"

## Display
var fullscreen: bool = false
var vsync: bool = true


func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err != OK:
		# First run — save defaults
		save_settings()
		return

	mouse_sensitivity = config.get_value("gameplay", "mouse_sensitivity", 1.0)
	fov = config.get_value("gameplay", "fov", 75.0)
	player_name = config.get_value("multiplayer", "player_name", "Fofolete")
	master_volume = config.get_value("audio", "master_volume", 80.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 80.0)
	fullscreen = config.get_value("display", "fullscreen", false)
	vsync = config.get_value("display", "vsync", true)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("gameplay", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("gameplay", "fov", fov)
	config.set_value("multiplayer", "player_name", player_name)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.save(CONFIG_PATH)


func apply_all() -> void:
	_apply_audio()
	_apply_display()
	settings_changed.emit()


func _apply_audio() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		var master_db := linear_to_db(master_volume / 100.0)
		AudioServer.set_bus_volume_db(master_idx, master_db)
		AudioServer.set_bus_mute(master_idx, master_volume <= 0.0)

	# SFX bus — if it exists, use it; otherwise SFX rides on Master
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		var sfx_db := linear_to_db(sfx_volume / 100.0)
		AudioServer.set_bus_volume_db(sfx_idx, sfx_db)
		AudioServer.set_bus_mute(sfx_idx, sfx_volume <= 0.0)


func _apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
