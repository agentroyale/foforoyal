class_name TouchButton
extends Control
## Circular touch button for mobile controls.
## Injects an input action on press/release. Supports multi-touch via touch index tracking.

signal button_pressed
signal button_released

@export var action_name := ""
@export var button_radius := 45.0
@export var icon_text := ""
@export var normal_color := Color(1, 1, 1, 0.3)
@export var pressed_color := Color(1, 1, 1, 0.6)
@export var toggle_mode := false

var is_pressed := false
var _touch_index: int = -1
var _opacity := 0.6


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(button_radius * 2, button_radius * 2)


func set_opacity(value: float) -> void:
	_opacity = value
	queue_redraw()


func try_press(index: int, pos: Vector2) -> bool:
	## Returns true if pos is within this button's circle.
	var center := global_position + size * 0.5
	if pos.distance_to(center) > button_radius:
		return false
	if toggle_mode:
		if is_pressed:
			_do_release()
		else:
			_do_press(index)
	else:
		_do_press(index)
	return true


func try_move(index: int, _pos: Vector2) -> void:
	# For non-toggle hold buttons, we just keep it pressed
	if index == _touch_index and not toggle_mode:
		pass


func try_release(index: int) -> void:
	if index != _touch_index:
		return
	if not toggle_mode:
		_do_release()


func _do_press(index: int) -> void:
	_touch_index = index
	is_pressed = true
	if action_name != "":
		Input.action_press(action_name)
	button_pressed.emit()
	queue_redraw()


func _do_release() -> void:
	_touch_index = -1
	is_pressed = false
	if action_name != "":
		Input.action_release(action_name)
	button_released.emit()
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var color: Color = pressed_color if is_pressed else normal_color
	color.a *= _opacity

	# Filled circle
	draw_circle(center, button_radius, Color(color.r, color.g, color.b, color.a * 0.5))
	# Border
	draw_arc(center, button_radius, 0, TAU, 48, color, 2.0)

	# Icon text
	if icon_text != "":
		var font := ThemeDB.fallback_font
		var font_size := int(button_radius * 0.5)
		var text_size := font.get_string_size(icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := center - text_size * 0.5 + Vector2(0, text_size.y * 0.35)
		draw_string(font, text_pos, icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, _opacity * 0.9))
