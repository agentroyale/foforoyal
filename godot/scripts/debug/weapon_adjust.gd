class_name WeaponAdjust
extends Node
## Debug tool: press F8 to toggle weapon adjustment mode.
## Frees mouse, lets you orbit camera with left-click drag to see weapon from all angles.
## Press F8 again to print final values and return to gameplay.
##
## Controls (while active):
##   View:     Left-click drag = orbit camera, Scroll = zoom
##   Position: I/K = Z, J/L = X, U/O = Y
##   Rotation: Numpad 8/2 = X, 4/6 = Y, 7/9 = Z
##   Scale:    +/- (= and -)
##   Muzzle:   Arrow keys = X/Z, PgUp/PgDn = Y
##   Anim:    Tab = cycle preview animation
##   Speed:    Hold Shift for 5x faster

const POS_STEP := 0.01
const ROT_STEP := 5.0  ## degrees
const SCALE_STEP := 0.02
const MUZZLE_STEP := 0.01
const ORBIT_SENSITIVITY := 0.005

const PREVIEW_ANIMS := [
	"general/Idle_A",
	"ranged/Ranged_1H_Aiming",
	"advanced/Running_HoldingRifle",
	"movement/Running_A",
	"ranged/Ranged_1H_Shoot",
]

var _active := false
var _label: Label
var _pivot: Node3D
var _muzzle: Marker3D
var _orbit_dragging := false
var _saved_camera_distance: float
var _camera: PlayerCamera
var _preview_idx := 0
var _model: PlayerModel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.name = "WeaponAdjustLabel"
	_label.position = Vector2(10, 10)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color.YELLOW)
	_label.visible = false
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		_toggle()
		get_viewport().set_input_as_handled()
		return

	if not _active:
		return

	# Tab to cycle preview animation
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_cycle_preview_anim()
		get_viewport().set_input_as_handled()
		return

	# Orbit camera with left-click drag
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_orbit_dragging = event.pressed
			get_viewport().set_input_as_handled()
		# Scroll to zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _camera:
				_camera._camera_distance = maxf(_camera._camera_distance - 0.3, 1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _camera:
				_camera._camera_distance = minf(_camera._camera_distance + 0.3, 8.0)
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _orbit_dragging:
		# Orbit camera around character (don't move the player)
		if _camera:
			_camera._orbit_yaw -= event.relative.x * ORBIT_SENSITIVITY
			_camera.rotation.x -= event.relative.y * ORBIT_SENSITIVITY
			_camera.rotation.x = clampf(_camera.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_active = not _active
	_camera = get_parent().get_node_or_null("CameraPivot") as PlayerCamera
	if _active:
		_find_pivot()
		if not _pivot:
			print("[WeaponAdjust] No weapon pivot found")
			_active = false
			return
		# Free mouse for orbiting
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if _camera:
			_camera.mouse_captured = false
			_camera.adjust_mode = true
			_saved_camera_distance = _camera._camera_distance
			_camera._camera_distance = 3.0  # zoom in to see weapon
		_model = get_parent().get_node_or_null("PlayerModel") as PlayerModel
		_preview_idx = 0
		_label.visible = true
		print("[WeaponAdjust] ACTIVE — LMB drag=orbit, Scroll=zoom, Tab=anim, IJKL/UO=pos, Numpad=rot, +/-=scale")
	else:
		# Restore gameplay
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
	if not _active or not _pivot:
		return

	var mult := 5.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0

	# Position
	if Input.is_key_pressed(KEY_I):
		_pivot.position.z -= POS_STEP * mult
	if Input.is_key_pressed(KEY_K):
		_pivot.position.z += POS_STEP * mult
	if Input.is_key_pressed(KEY_J):
		_pivot.position.x -= POS_STEP * mult
	if Input.is_key_pressed(KEY_L):
		_pivot.position.x += POS_STEP * mult
	if Input.is_key_pressed(KEY_U):
		_pivot.position.y += POS_STEP * mult
	if Input.is_key_pressed(KEY_O):
		_pivot.position.y -= POS_STEP * mult

	# Rotation
	if Input.is_key_pressed(KEY_KP_8):
		_pivot.rotation_degrees.x -= ROT_STEP * mult
	if Input.is_key_pressed(KEY_KP_2):
		_pivot.rotation_degrees.x += ROT_STEP * mult
	if Input.is_key_pressed(KEY_KP_4):
		_pivot.rotation_degrees.y -= ROT_STEP * mult
	if Input.is_key_pressed(KEY_KP_6):
		_pivot.rotation_degrees.y += ROT_STEP * mult
	if Input.is_key_pressed(KEY_KP_7):
		_pivot.rotation_degrees.z -= ROT_STEP * mult
	if Input.is_key_pressed(KEY_KP_9):
		_pivot.rotation_degrees.z += ROT_STEP * mult

	# Scale (uniform)
	if Input.is_key_pressed(KEY_EQUAL):
		_pivot.scale += Vector3.ONE * SCALE_STEP * mult
	if Input.is_key_pressed(KEY_MINUS):
		_pivot.scale -= Vector3.ONE * SCALE_STEP * mult
		if _pivot.scale.x < 0.01:
			_pivot.scale = Vector3.ONE * 0.01

	# Muzzle offset
	if _muzzle:
		if Input.is_key_pressed(KEY_LEFT):
			_muzzle.position.x -= MUZZLE_STEP * mult
		if Input.is_key_pressed(KEY_RIGHT):
			_muzzle.position.x += MUZZLE_STEP * mult
		if Input.is_key_pressed(KEY_UP):
			_muzzle.position.z -= MUZZLE_STEP * mult
		if Input.is_key_pressed(KEY_DOWN):
			_muzzle.position.z += MUZZLE_STEP * mult
		if Input.is_key_pressed(KEY_PAGEUP):
			_muzzle.position.y += MUZZLE_STEP * mult
		if Input.is_key_pressed(KEY_PAGEDOWN):
			_muzzle.position.y -= MUZZLE_STEP * mult

	_update_label()


func _find_pivot() -> void:
	_pivot = null
	_muzzle = null
	var player := get_parent()
	if not player:
		return
	var model := player.get_node_or_null("PlayerModel") as PlayerModel
	if not model or not model._weapon_visual:
		return
	_pivot = model._weapon_visual.get_pivot()
	if _pivot:
		_muzzle = _pivot.get_node_or_null("MuzzlePoint") as Marker3D
	if not _muzzle:
		var ba := model._weapon_visual._bone_attachment
		if ba:
			_muzzle = ba.get_node_or_null("MuzzlePoint") as Marker3D


func _cycle_preview_anim() -> void:
	_preview_idx = (_preview_idx + 1) % PREVIEW_ANIMS.size()
	var anim_name: String = PREVIEW_ANIMS[_preview_idx]
	if _model and _model._anim_player and _model._anim_player.has_animation(anim_name):
		_model._anim_player.play(anim_name)
		_model._current_anim = anim_name
		print("[WeaponAdjust] Preview: %s" % anim_name)


func _update_label() -> void:
	if not _pivot:
		return
	var txt := "[F8] WEAPON ADJUST\n"
	txt += "LMB drag=orbit  Scroll=zoom  Shift=fast\n"
	txt += "Anim (Tab):    %s\n" % PREVIEW_ANIMS[_preview_idx]
	txt += "─────────────────────────────\n"
	txt += "Pos (IJKL/UO): %s\n" % _v3_str(_pivot.position)
	txt += "Rot (Numpad):  %s\n" % _v3_str(_pivot.rotation_degrees)
	txt += "Scale (+/-):   %.3f\n" % _pivot.scale.x
	if _muzzle:
		txt += "Muzzle (Arrows/PgUp/PgDn): %s\n" % _v3_str(_muzzle.position)
	_label.text = txt


func _print_values() -> void:
	if not _pivot:
		return
	print("\n=== WEAPON ADJUST VALUES (copy to WeaponData) ===")
	print("model_position_offset = Vector3(%s)" % _v3_export(_pivot.position))
	print("model_rotation_offset = Vector3(%s)" % _v3_export(_pivot.rotation_degrees))
	print("model_scale = %.3f" % _pivot.scale.x)
	if _muzzle:
		print("muzzle_offset = Vector3(%s)" % _v3_export(_muzzle.position))
	print("=================================================\n")


func _v3_str(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]


func _v3_export(v: Vector3) -> String:
	return "%.3f, %.3f, %.3f" % [v.x, v.y, v.z]
