extends Node
## Mobile platform detection + touch camera delta relay.
## Autoload singleton. Other scripts check MobileInput.is_mobile and consume camera_delta.

## True on Android/iOS or when launched with --mobile flag.
var is_mobile := false

## Touch camera delta accumulated this frame, consumed by player_camera.gd.
var camera_delta := Vector2.ZERO

## Touch sensitivity multiplier (separate from mouse sensitivity).
var touch_sensitivity: float = 1.0


func _ready() -> void:
	is_mobile = OS.has_feature("mobile") or _has_mobile_flag()
	if is_mobile:
		# Prevent touch events from generating mouse events (avoids double camera movement)
		Input.emulate_mouse_from_touch = false


func _has_mobile_flag() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--mobile":
			return true
	return false


func apply_camera_delta(delta: Vector2) -> void:
	## Called by touch_controls to accumulate camera rotation this frame.
	camera_delta += delta


func consume_camera_delta() -> Vector2:
	## Called by player_camera.gd each frame. Returns and clears the accumulated delta.
	var d := camera_delta
	camera_delta = Vector2.ZERO
	return d
