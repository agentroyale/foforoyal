class_name VirtualJoystick
extends Control
## Floating virtual joystick for mobile movement.
## Appears at touch position, injects movement actions via Input.action_press/release.
## Auto-sprint when pushed >90% forward.

signal joystick_input(direction: Vector2)

const BASE_RADIUS := 100.0
const KNOB_RADIUS := 40.0
const DEADZONE := 0.15
const AUTO_SPRINT_THRESHOLD := 0.9

var _touch_index: int = -1
var _base_center := Vector2.ZERO
var _knob_offset := Vector2.ZERO
var _is_active := false
var _opacity := 0.6

## Actions to inject
var _action_forward := "move_forward"
var _action_backward := "move_backward"
var _action_left := "move_left"
var _action_right := "move_right"
var _action_sprint := "sprint"

var _last_strength := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_opacity(value: float) -> void:
	_opacity = value
	queue_redraw()


func handle_touch_pressed(index: int, pos: Vector2) -> void:
	if _is_active:
		return
	_touch_index = index
	_is_active = true
	_base_center = pos
	_knob_offset = Vector2.ZERO
	_last_strength = Vector2.ZERO
	queue_redraw()


func handle_touch_moved(index: int, pos: Vector2) -> void:
	if not _is_active or index != _touch_index:
		return
	var diff := pos - _base_center
	if diff.length() > BASE_RADIUS:
		diff = diff.normalized() * BASE_RADIUS
	_knob_offset = diff
	var strength := diff / BASE_RADIUS
	_apply_movement(strength)
	queue_redraw()


func handle_touch_released(index: int) -> void:
	if not _is_active or index != _touch_index:
		return
	_is_active = false
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	_release_all_actions()
	_last_strength = Vector2.ZERO
	queue_redraw()


func _apply_movement(strength: Vector2) -> void:
	_release_all_actions()
	_last_strength = strength

	var mag := strength.length()
	if mag < DEADZONE:
		joystick_input.emit(Vector2.ZERO)
		return

	# Normalize past deadzone
	var adjusted := strength * ((mag - DEADZONE) / (1.0 - DEADZONE) / mag)
	joystick_input.emit(adjusted)

	# Inject actions with analog strength
	if adjusted.y < 0.0:
		Input.action_press(_action_forward, absf(adjusted.y))
	elif adjusted.y > 0.0:
		Input.action_press(_action_backward, absf(adjusted.y))

	if adjusted.x < 0.0:
		Input.action_press(_action_left, absf(adjusted.x))
	elif adjusted.x > 0.0:
		Input.action_press(_action_right, absf(adjusted.x))

	# Auto-sprint: push forward >90%
	if adjusted.y < -AUTO_SPRINT_THRESHOLD and absf(adjusted.x) < 0.3:
		Input.action_press(_action_sprint)
	else:
		Input.action_release(_action_sprint)


func _release_all_actions() -> void:
	Input.action_release(_action_forward)
	Input.action_release(_action_backward)
	Input.action_release(_action_left)
	Input.action_release(_action_right)
	Input.action_release(_action_sprint)


func _draw() -> void:
	if not _is_active:
		return

	var local_center := _base_center - global_position
	var knob_pos := local_center + _knob_offset

	# Base circle
	draw_circle(local_center, BASE_RADIUS, Color(1, 1, 1, 0.15 * _opacity))
	draw_arc(local_center, BASE_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.3 * _opacity), 2.0)

	# Knob
	draw_circle(knob_pos, KNOB_RADIUS, Color(1, 1, 1, 0.5 * _opacity))
	draw_arc(knob_pos, KNOB_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.7 * _opacity), 2.0)
