class_name Explosive
extends Area3D
## Runtime node for placed/launched explosive (C4, satchel, rocket).
## Handles fuse countdown, dud mechanic, and detonation trigger.

signal detonated(origin: Vector3, results: Array[Dictionary])
signal dud_occurred()
signal fuse_started(time: float)

@export var explosive_data: ExplosiveData

var _armed := false
var _fuse_remaining := 0.0
var _hit_direction := Vector3.ZERO
var _detonated := false


func arm(hit_dir: Vector3 = Vector3.ZERO) -> void:
	if _armed or _detonated:
		return
	_armed = true
	_hit_direction = hit_dir
	_fuse_remaining = explosive_data.fuse_time if explosive_data else 10.0
	fuse_started.emit(_fuse_remaining)


func _physics_process(delta: float) -> void:
	# In multiplayer, only server runs fuse/detonation logic
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not _armed or _detonated:
		return
	_fuse_remaining -= delta
	if _fuse_remaining <= 0.0:
		_try_detonate()


func _try_detonate() -> void:
	if _detonated:
		return
	if explosive_data and explosive_data.dud_chance > 0.0:
		if randf() < explosive_data.dud_chance:
			_armed = false
			dud_occurred.emit()
			return
	_detonate()


func _detonate() -> void:
	_detonated = true
	_armed = false
	var base_damage := explosive_data.base_damage if explosive_data else 275.0
	var radius := explosive_data.explosion_radius if explosive_data else 4.0
	var results := ExplosionDamage.apply_explosion(
		get_tree(), global_position, base_damage, radius, _hit_direction
	)
	detonated.emit(global_position, results)
	queue_free()


func force_detonate() -> void:
	## Bypass fuse for re-igniting duds or testing.
	if _detonated:
		return
	_detonate()


func is_armed() -> bool:
	return _armed


func is_dud() -> bool:
	return not _armed and not _detonated and _fuse_remaining <= 0.0
