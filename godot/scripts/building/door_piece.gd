class_name DoorPiece
extends BuildingPiece
## Door: open/close on interact instead of upgrade.

var is_open: bool = false


func interact(player: Node3D) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_toggle.rpc_id(1)
		return
	toggle_door()


@rpc("any_peer", "reliable")
func _request_toggle() -> void:
	if not multiplayer.is_server():
		return
	_sync_toggle.rpc()


@rpc("call_local", "reliable")
func _sync_toggle() -> void:
	_do_toggle()


func toggle_door() -> void:
	if multiplayer.has_multiplayer_peer():
		_sync_toggle.rpc()
	else:
		_do_toggle()


func _do_toggle() -> void:
	is_open = not is_open
	var pivot := get_node_or_null("DoorPivot") as Node3D
	if not pivot:
		return
	var target_rot := -90.0 if is_open else 0.0
	var tween := create_tween()
	tween.tween_property(pivot, "rotation_degrees:y", target_rot, 0.3)
