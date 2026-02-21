extends Node
## Global game settings manager.
## Autoload singleton — persists settings to user://settings.cfg.
## Other scripts read values directly: GameSettings.mouse_sensitivity, etc.

signal settings_changed

const CONFIG_PATH := "user://settings.cfg"
const GAME_VERSION := "0.2.2"

## Gameplay
var mouse_sensitivity: float = 1.0
var fov: float = 75.0

## Audio
var master_volume: float = 80.0
var sfx_volume: float = 80.0

## Multiplayer
var player_name: String = "Fofolete"

## Character
var selected_character: String = "barbarian"

## Model overrides (per-character scale/offset/rotation, set via F9 ModelAdjust)
var model_overrides: Dictionary = {}

## Display
var fullscreen: bool = false
var vsync: bool = true

## Mobile
var touch_sensitivity: float = 1.0
var touch_opacity: float = 0.6
var mobile_quality: int = 1  ## 0=Low, 1=Medium, 2=High


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
	selected_character = config.get_value("character", "selected", "barbarian")
	master_volume = config.get_value("audio", "master_volume", 80.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 80.0)
	fullscreen = config.get_value("display", "fullscreen", false)
	vsync = config.get_value("display", "vsync", true)
	touch_sensitivity = config.get_value("mobile", "touch_sensitivity", 1.0)
	touch_opacity = config.get_value("mobile", "touch_opacity", 0.6)
	mobile_quality = config.get_value("mobile", "mobile_quality", 1)

	# Load per-character model overrides (sections like [model_camofrog_s])
	model_overrides = {}
	var sections: PackedStringArray = config.get_sections()
	for i in sections.size():
		var section: String = sections[i]
		if section.begins_with("model_"):
			var char_id := section.substr(6)
			model_overrides[char_id] = {
				"scale": config.get_value(section, "scale", 1.0),
				"offset": config.get_value(section, "offset", Vector3.ZERO),
				"rot_x": config.get_value(section, "rot_x", 0.0),
				"rot_y": config.get_value(section, "rot_y", 0.0),
				"rot_z": config.get_value(section, "rot_z", 0.0),
			}


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("gameplay", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("gameplay", "fov", fov)
	config.set_value("multiplayer", "player_name", player_name)
	config.set_value("character", "selected", selected_character)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("mobile", "touch_sensitivity", touch_sensitivity)
	config.set_value("mobile", "touch_opacity", touch_opacity)
	config.set_value("mobile", "mobile_quality", mobile_quality)

	# Save per-character model overrides
	var override_keys: Array = model_overrides.keys()
	for i in override_keys.size():
		var cid: String = override_keys[i]
		var data: Dictionary = model_overrides[cid]
		var section: String = "model_" + cid
		config.set_value(section, "scale", data.get("scale", 1.0))
		config.set_value(section, "offset", data.get("offset", Vector3.ZERO))
		config.set_value(section, "rot_x", data.get("rot_x", 0.0))
		config.set_value(section, "rot_y", data.get("rot_y", 0.0))
		config.set_value(section, "rot_z", data.get("rot_z", 0.0))

	config.save(CONFIG_PATH)


func get_model_override(char_id: String) -> Dictionary:
	return model_overrides.get(char_id, {})


func set_model_override(char_id: String, data: Dictionary) -> void:
	model_overrides[char_id] = data
	save_settings()


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
