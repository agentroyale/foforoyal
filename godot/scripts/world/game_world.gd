extends Node3D
## Main procedural world scene controller.
## Initializes WorldGenerator and positions the player on safe terrain.

func _ready() -> void:
	$Player.set_physics_process(false)
	var seed_val := _get_seed()
	WorldGenerator.world_initialized.connect(_on_world_ready)
	WorldGenerator.initialize(seed_val)


func _on_world_ready(_seed: int) -> void:
	var center := float(WorldGenerator.MAP_SIZE) / 2.0
	# Offset from exact chunk boundary to be well inside a chunk
	var spawn_x := center + 16.0
	var spawn_z := center + 16.0

	# Force-load chunks around spawn before placing the player
	ChunkManager.update_chunks(Vector3(spawn_x, 0.0, spawn_z))

	# Wait for physics to register collision shapes
	await get_tree().physics_frame
	await get_tree().physics_frame

	var height := WorldGenerator.get_height_at(spawn_x, spawn_z)
	var safe_y := maxf(height, WaterSystem.BASE_WATER_LEVEL) + 2.0

	var player := $Player as CharacterBody3D
	player.global_position = Vector3(spawn_x, safe_y, spawn_z)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)


func _get_seed() -> int:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--seed="):
			return int(arg.substr(7))
	return 12345
