class_name PlayerInteraction
extends RayCast3D
## Interaction system via RayCast3D. Detects objects with interact() method.

const INTERACT_DISTANCE := 4.0

signal interaction_target_changed(target: Node3D)

var current_target: Node3D = null


func _ready() -> void:
	target_position = Vector3(0, 0, -INTERACT_DISTANCE)
	enabled = true


func _physics_process(_delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not get_parent().get_parent().is_multiplayer_authority():
		return
	_update_target()

	if current_target and Input.is_action_just_pressed("interact"):
		_interact_with(current_target)


func _update_target() -> void:
	var new_target: Node3D = null

	if is_colliding():
		var collider := get_collider()
		if collider is Node3D and collider.has_method("interact"):
			new_target = collider as Node3D

	if new_target != current_target:
		current_target = new_target
		interaction_target_changed.emit(current_target)


func _interact_with(target: Node3D) -> void:
	target.interact(get_parent().get_parent()) # Pass the player (CharacterBody3D)


func get_interact_target() -> Node3D:
	return current_target
