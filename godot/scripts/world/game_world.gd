extends Node3D
## Main procedural world scene controller.
## Initializes WorldGenerator and positions the player on safe terrain.
## In BR mode, also spawns lobby area, zone controller, drop controller, and victory screen.

const BOT_COUNT := 12
const BOT_SCENE := preload("res://scenes/ai/bot.tscn")

var _zone_controller: Node = null
var _zone_visual: Node3D = null
var _drop_controller: Node = null
var _lobby_hud: CanvasLayer = null
var _victory_screen: CanvasLayer = null


func _ready() -> void:
	$Player.set_physics_process(false)
	var seed_val := _get_seed()
	var wtype := WorldGenerator.WorldType.CITY if MatchManager.is_br_mode() else WorldGenerator.WorldType.TERRAIN
	WorldGenerator.world_initialized.connect(_on_world_ready)
	WorldGenerator.initialize(seed_val, wtype)
	if MatchManager.is_br_mode():
		_setup_br_systems()


func _setup_br_systems() -> void:
	# Lobby area
	var lobby_scene := load("res://scenes/gamemode/lobby_area.tscn") as PackedScene
	if lobby_scene:
		var lobby := lobby_scene.instantiate()
		lobby.name = "LobbyArea"
		add_child(lobby)
	# Zone controller
	var zc_script := load("res://scripts/gamemode/zone_controller.gd") as GDScript
	if zc_script:
		_zone_controller = Node.new()
		_zone_controller.name = "ZoneController"
		_zone_controller.set_script(zc_script)
		add_child(_zone_controller)
	# Zone visual
	var zv_script := load("res://scripts/gamemode/zone_visual.gd") as GDScript
	if zv_script:
		_zone_visual = Node3D.new()
		_zone_visual.name = "ZoneVisual"
		_zone_visual.set_script(zv_script)
		add_child(_zone_visual)
		if _zone_controller:
			_zone_visual.setup(_zone_controller)
	# Drop controller
	var dc_script := load("res://scripts/gamemode/drop_controller.gd") as GDScript
	if dc_script:
		_drop_controller = Node.new()
		_drop_controller.name = "DropController"
		_drop_controller.set_script(dc_script)
		add_child(_drop_controller)
	# Lobby HUD
	var lobby_hud_scene := load("res://scenes/ui/lobby_hud.tscn") as PackedScene
	if lobby_hud_scene:
		_lobby_hud = lobby_hud_scene.instantiate()
		add_child(_lobby_hud)
	# Victory screen
	var victory_scene := load("res://scenes/ui/br_victory_screen.tscn") as PackedScene
	if victory_scene:
		_victory_screen = victory_scene.instantiate()
		add_child(_victory_screen)
	# Connect match state changes
	MatchManager.match_state_changed.connect(_on_match_state_changed)


func _on_match_state_changed(_old: int, new_state: int) -> void:
	if new_state == MatchManager.MatchState.DROPPING:
		if _drop_controller and _drop_controller.has_method("start_drop"):
			_drop_controller.start_drop(float(WorldGenerator.MAP_SIZE), MatchManager.get_match_seed())
	elif new_state == MatchManager.MatchState.IN_PROGRESS:
		if _zone_controller and _zone_controller.has_method("start_zone"):
			_zone_controller.start_zone(float(WorldGenerator.MAP_SIZE), MatchManager.get_match_seed())


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
	if MatchManager.is_br_mode():
		# CLI --br test: skip lobby, spawn on ground in city
		var is_cli_br := false
		var all_args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
		for arg in all_args:
			if arg == "--br":
				is_cli_br = true
				break
		if is_cli_br:
			player.global_position = Vector3(spawn_x, 2.0, spawn_z)
		else:
			# Normal BR: player starts on lobby platform
			var lobby := get_node_or_null("LobbyArea")
			if lobby and lobby.has_method("get_spawn_position"):
				player.global_position = lobby.get_spawn_position(0)
			else:
				player.global_position = Vector3(512, 201, 512)
		player.velocity = Vector3.ZERO
		player.set_physics_process(true)
	else:
		player.global_position = Vector3(spawn_x, safe_y, spawn_z)
		player.velocity = Vector3.ZERO
		player.set_physics_process(true)
	_spawn_bots(Vector3(spawn_x, 0.0, spawn_z))


func _spawn_bots(center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99999
	var space := get_world_3d().direct_space_state
	for i in BOT_COUNT:
		var bot: BotController = BOT_SCENE.instantiate()
		bot.name = "Bot_%d" % i
		var glb: String = BotController.CHARACTER_GLBS[rng.randi() % BotController.CHARACTER_GLBS.size()]
		var wpn: String = BotController.WEAPON_PATHS[rng.randi() % BotController.WEAPON_PATHS.size()]
		add_child(bot)
		bot.setup(glb, wpn)
		bot.global_position = _find_clear_spawn(center, rng, space)


func _find_clear_spawn(center: Vector3, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D) -> Vector3:
	for _attempt in 10:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(15.0, 80.0)
		var x := center.x + cos(angle) * dist
		var z := center.z + sin(angle) * dist
		if not space:
			var h := WorldGenerator.get_height_at(x, z)
			return Vector3(x, maxf(h, 0.0) + 2.0, z)
		# Raycast from sky downward — if we hit a roof (y > 3m), skip this spot
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(x, 100.0, z), Vector3(x, -1.0, z))
		var result := space.intersect_ray(query)
		if result.is_empty():
			var h := WorldGenerator.get_height_at(x, z)
			return Vector3(x, maxf(h, 0.0) + 2.0, z)
		if result.position.y < 3.0:
			return Vector3(x, result.position.y + 1.5, z)
	# Fallback: near center
	return Vector3(center.x + 15.0, 2.0, center.z)


func _get_seed() -> int:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--seed="):
			return int(arg.substr(7))
	return 12345
