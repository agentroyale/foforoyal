class_name TouchControls
extends Control
## Full-screen overlay for mobile touch controls.
## Manages joystick (left 40%), camera zone (right 60%), and action buttons.
## Uses _input() for reliable multi-touch handling.

const JOYSTICK_ZONE_RATIO := 0.4
const CAMERA_SENSITIVITY_BASE := 3.0

var joystick: VirtualJoystick
var btn_fire: TouchButton
var btn_ads: TouchButton
var btn_jump: TouchButton
var btn_crouch: TouchButton
var btn_reload: TouchButton
var btn_interact: TouchButton

## Hotbar buttons
var _hotbar_buttons: Array[TouchButton] = []

## Camera touch tracking
var _camera_touch_index: int = -1
var _camera_last_pos := Vector2.ZERO

## All buttons for hit-testing
var _all_buttons: Array[TouchButton] = []

## Opacity
var _opacity := 0.6


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_controls()
	_apply_settings()
	var gs: Node = get_node_or_null("/root/GameSettings")
	if gs:
		gs.settings_changed.connect(_apply_settings)


func _apply_settings() -> void:
	var gs: Node = get_node_or_null("/root/GameSettings")
	if gs:
		_opacity = gs.touch_opacity
		var mi: Node = get_node_or_null("/root/MobileInput")
		if mi:
			mi.touch_sensitivity = gs.touch_sensitivity
	joystick.set_opacity(_opacity)
	for btn in _all_buttons:
		btn.set_opacity(_opacity)


func _build_controls() -> void:
	var screen := get_viewport_rect().size

	# Joystick (left side, covers full left 40%)
	joystick = VirtualJoystick.new()
	joystick.name = "VirtualJoystick"
	joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(joystick)

	# -- Right side buttons --
	var right_margin := 30.0
	var bottom_margin := 30.0

	# Fire button (large, bottom-right)
	btn_fire = _create_button("Fire", "primary_action", 70.0, Color(0.9, 0.2, 0.2, 0.4), Color(1, 0.3, 0.3, 0.7))
	btn_fire.position = Vector2(screen.x - right_margin - 160, screen.y - bottom_margin - 160)
	btn_fire.icon_text = "FIRE"

	# ADS button (toggle, left of fire)
	btn_ads = _create_button("ADS", "secondary_action", 50.0, Color(0.2, 0.4, 0.9, 0.4), Color(0.3, 0.5, 1, 0.7))
	btn_ads.position = Vector2(screen.x - right_margin - 310, screen.y - bottom_margin - 140)
	btn_ads.toggle_mode = true
	btn_ads.icon_text = "ADS"

	# Reload (above ADS)
	btn_reload = _create_button("Reload", "reload", 40.0, Color(0.7, 0.7, 0.3, 0.4), Color(0.9, 0.9, 0.4, 0.7))
	btn_reload.position = Vector2(screen.x - right_margin - 300, screen.y - bottom_margin - 270)
	btn_reload.icon_text = "R"

	# Interact (above reload)
	btn_interact = _create_button("Interact", "interact", 40.0, Color(0.3, 0.8, 0.3, 0.4), Color(0.4, 1, 0.4, 0.7))
	btn_interact.position = Vector2(screen.x - right_margin - 170, screen.y - bottom_margin - 290)
	btn_interact.icon_text = "E"

	# Jump (left side, bottom)
	btn_jump = _create_button("Jump", "jump", 45.0, Color(0.5, 0.5, 0.8, 0.4), Color(0.6, 0.6, 1, 0.7))
	btn_jump.position = Vector2(30, screen.y - bottom_margin - 200)
	btn_jump.icon_text = "JMP"

	# Crouch (left side, above jump)
	btn_crouch = _create_button("Crouch", "crouch", 40.0, Color(0.5, 0.5, 0.8, 0.4), Color(0.6, 0.6, 1, 0.7))
	btn_crouch.position = Vector2(30, screen.y - bottom_margin - 310)
	btn_crouch.toggle_mode = true
	btn_crouch.icon_text = "C"

	# Hotbar buttons (bottom center)
	var hotbar_start_x := (screen.x - 6 * 60) * 0.5
	for i in range(6):
		var hb := _create_button("HB%d" % (i + 1), "hotbar_%d" % (i + 1), 25.0, Color(0.4, 0.4, 0.4, 0.3), Color(0.6, 0.6, 0.6, 0.6))
		hb.position = Vector2(hotbar_start_x + i * 60, screen.y - bottom_margin - 60)
		hb.icon_text = "%d" % (i + 1)
		_hotbar_buttons.append(hb)


func _create_button(btn_name: String, action: String, radius: float, normal: Color, pressed: Color) -> TouchButton:
	var btn := TouchButton.new()
	btn.name = btn_name
	btn.action_name = action
	btn.button_radius = radius
	btn.normal_color = normal
	btn.pressed_color = pressed
	btn.custom_minimum_size = Vector2(radius * 2, radius * 2)
	btn.size = Vector2(radius * 2, radius * 2)
	btn.set_opacity(_opacity)
	add_child(btn)
	_all_buttons.append(btn)
	return btn


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var idx := event.index
	var pos := event.position

	if event.pressed:
		# Check buttons first
		for btn in _all_buttons:
			if btn.try_press(idx, pos):
				get_viewport().set_input_as_handled()
				return

		# Joystick zone (left 40%)
		var screen_w := get_viewport_rect().size.x
		if pos.x < screen_w * JOYSTICK_ZONE_RATIO:
			joystick.handle_touch_pressed(idx, pos)
			get_viewport().set_input_as_handled()
			return

		# Camera zone (right 60%)
		_camera_touch_index = idx
		_camera_last_pos = pos
		get_viewport().set_input_as_handled()
	else:
		# Release
		joystick.handle_touch_released(idx)
		for btn in _all_buttons:
			btn.try_release(idx)
		if idx == _camera_touch_index:
			_camera_touch_index = -1
		get_viewport().set_input_as_handled()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	var idx := event.index
	var pos := event.position

	# Joystick drag
	joystick.handle_touch_moved(idx, pos)

	# Button drag (for hold buttons)
	for btn in _all_buttons:
		btn.try_move(idx, pos)

	# Camera drag
	if idx == _camera_touch_index:
		var delta := pos - _camera_last_pos
		_camera_last_pos = pos
		var mi: Node = get_node_or_null("/root/MobileInput")
		if mi:
			mi.apply_camera_delta(delta * CAMERA_SENSITIVITY_BASE)
		get_viewport().set_input_as_handled()
