extends Node
## Debug tool: press F9 to toggle model adjustment mode.
## Adjust position, rotation, and scale of the player model in real-time.
## Values are saved per-character to settings.cfg via GameSettings.
##
## Controls (while active):
##   View:     Left-click drag = orbit camera, Scroll = zoom
##   Position: I/K = Z, J/L = X, U/O = Y
##   Rotation: Numpad 8/2 = X, 4/6 = Y, 7/9 = Z
##   Scale:    +/- (= and -)
##   Anim:     Tab = cycle preview animation
##   Speed:    Hold Shift for 5x faster
##   Save:     F9 again (auto-saves to settings.cfg)

const POS_STEP := 0.01
const ROT_STEP := 1.0  ## degrees
const SCALE_STEP := 0.01
const ORBIT_SENSITIVITY := 0.005

var _active := false
var _label: Label
var _model: Node3D
var _orbit_dragging := false
var _saved_camera_distance: float
var _camera: PlayerCamera
var _anim_player: AnimationPlayer
var _anim_list: Array[String] = []
var _anim_idx := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.name = "ModelAdjustLabel"
	_label.position = Vector2(10, 10)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color.CYAN)
	_label.visible = false
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		_toggle()
		get_viewport().set_input_as_handled()
		return

	if not _active:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_cycle_anim()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_orbit_dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _camera:
				_camera._camera_distance = maxf(_camera._camera_distance - 0.3, 1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _camera:
				_camera._camera_distance = minf(_camera._camera_distance + 0.3, 8.0)
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _orbit_dragging:
		if _camera:
			_camera._orbit_yaw -= event.relative.x * ORBIT_SENSITIVITY
			_camera.rotation.x -= event.relative.y * ORBIT_SENSITIVITY
			_camera.rotation.x = clampf(_camera.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_active = not _active
	_camera = get_parent().get_node_or_null("CameraPivot") as PlayerCamera
	if _active:
		_model = get_parent().get_node_or_null("PlayerModel")
		if not _model:
			print("[ModelAdjust] No PlayerModel found")
			_active = false
			return
		_anim_player = null
		_anim_list.clear()
		if _model is PlayerModel:
			_anim_player = _model._anim_player
		if _anim_player:
			_anim_list.assign(_anim_player.get_animation_list())
			_anim_list.sort()
		_anim_idx = 0
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if _camera:
			_camera.mouse_captured = false
			_camera.adjust_mode = true
			_saved_camera_distance = _camera._camera_distance
			_camera._camera_distance = 3.5
		_label.visible = true
		print("[ModelAdjust] ACTIVE — F9=save+close, IJKL/UO=pos, Numpad=rot, +/-=scale, Tab=anim")
	else:
		_save_values()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if _camera:
			_camera.mouse_captured = true
			_camera.adjust_mode = false
			_camera._orbit_yaw = 0.0
			_camera._camera_distance = _saved_camera_distance
		_orbit_dragging = false
		_label.visible = false
		_print_values()


func _process(_delta: float) -> void:
	if not _active or not _model:
		return

	var mult := 5.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0

	# Position
	if Input.is_key_pressed(KEY_I):
		_model.position.z -= POS_STEP * mult
	if Input.is_key_pressed(KEY_K):
		_model.position.z += POS_STEP * mult
	if Input.is_key_pressed(KEY_J):
		_model.position.x -= POS_STEP * mult
	if Input.is_key_pressed(KEY_L):
		_model.position.x += POS_STEP * mult
	if Input.is_key_pressed(KEY_U):
		_model.position.y += POS_STEP * mult
	if Input.is_key_pressed(KEY_O):
		_model.position.y -= POS_STEP * mult

	# Rotation
	if Input.is_key_pressed(KEY_KP_8):
		_model.rotation_degrees.x -= ROT_STEP * mult
	if Input.is_key_pressed(KEY_KP_2):
		_model.rotation_degrees.x += ROT_STEP * mult
	if Input.is_key_pressed(KEY_KP_4):
		_model.rotation_degrees.y -= ROT_STEP * mult
	if Input.is_key_pressed(KEY_KP_6):
		_model.rotation_degrees.y += ROT_STEP * mult
	if Input.is_key_pressed(KEY_KP_7):
		_model.rotation_degrees.z -= ROT_STEP * mult
	if Input.is_key_pressed(KEY_KP_9):
		_model.rotation_degrees.z += ROT_STEP * mult

	# Scale (uniform)
	if Input.is_key_pressed(KEY_EQUAL):
		var s: float = _model.scale.x + SCALE_STEP * mult
		_model.scale = Vector3.ONE * s
	if Input.is_key_pressed(KEY_MINUS):
		var s: float = maxf(_model.scale.x - SCALE_STEP * mult, 0.01)
		_model.scale = Vector3.ONE * s

	_update_label()


func _cycle_anim() -> void:
	if _anim_list.is_empty() or not _anim_player:
		return
	_anim_idx = (_anim_idx + 1) % _anim_list.size()
	var anim_name: String = _anim_list[_anim_idx]
	_anim_player.play(anim_name)
	print("[ModelAdjust] Anim: %s" % anim_name)


func _save_values() -> void:
	if not _model:
		return
	var char_id := GameSettings.selected_character
	GameSettings.set_model_override(char_id, {
		"scale": _model.scale.x,
		"offset": _model.position,
		"rot_x": _model.rotation_degrees.x,
		"rot_y": _model.rotation_degrees.y - 180.0,
		"rot_z": _model.rotation_degrees.z,
	})


func _print_values() -> void:
	if not _model:
		return
	var extra_rot_y := _model.rotation_degrees.y - 180.0
	print("\n=== MODEL ADJUST VALUES (saved to settings.cfg) ===")
	print("character = %s" % GameSettings.selected_character)
	print("scale = %.3f" % _model.scale.x)
	print("offset = Vector3(%s)" % _v3_export(_model.position))
	print("rotation (extra) = (%.1f, %.1f, %.1f)" % [
		_model.rotation_degrees.x, extra_rot_y, _model.rotation_degrees.z])
	print("===================================================\n")


func _update_label() -> void:
	if not _model:
		return
	var extra_rot_y := _model.rotation_degrees.y - 180.0
	var anim_name := _anim_list[_anim_idx] if not _anim_list.is_empty() else "none"
	var txt := "[F9] MODEL ADJUST — %s\n" % GameSettings.selected_character
	txt += "LMB drag=orbit  Scroll=zoom  Shift=fast\n"
	txt += "Anim (Tab): %s\n" % anim_name
	txt += "─────────────────────────────\n"
	txt += "Pos (IJKL/UO):   %s\n" % _v3_str(_model.position)
	txt += "Rot (Numpad):    (%.1f, %.1f, %.1f)\n" % [
		_model.rotation_degrees.x, extra_rot_y, _model.rotation_degrees.z]
	txt += "Scale (+/-):     %.3f\n" % _model.scale.x
	_label.text = txt


func _v3_str(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]


func _v3_export(v: Vector3) -> String:
	return "%.3f, %.3f, %.3f" % [v.x, v.y, v.z]
