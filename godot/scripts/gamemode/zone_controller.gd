extends Node
## Runtime zone controller — manages shrinking zone phases, timers, and damage.
## Added as child of game world in BR mode.

signal zone_phase_changed(phase: int)
signal zone_shrinking(phase: int, radius: float)
signal zone_damage_tick(peer_id: int, damage: float)

var current_phase: int = 0
var is_shrinking: bool = false
var phase_elapsed: float = 0.0
var current_radius: float = 480.0
var current_center: Vector3 = Vector3(512.0, 0.0, 512.0)
var _damage_timer: float = 0.0
var _active: bool = false
var _map_size: float = 1024.0
var _seed: int = 0

const DAMAGE_TICK_INTERVAL := 1.0


func start_zone(map_size: float, seed_val: int) -> void:
	_map_size = map_size
	_seed = seed_val
	current_phase = 0
	is_shrinking = false
	phase_elapsed = 0.0
	current_center = ZoneSystem.get_zone_center(0, _map_size, _seed)
	current_radius = ZoneSystem.get_current_radius(0, 0.0, false)
	_active = true
	zone_phase_changed.emit(0)


func _process(delta: float) -> void:
	if not _active:
		return
	if not MatchManager.is_br_mode():
		return
	if MatchManager.match_state != MatchManager.MatchState.IN_PROGRESS:
		return
	phase_elapsed += delta
	_damage_timer += delta
	var data := ZoneSystem.get_phase_data(current_phase)
	if data.is_empty():
		return
	if not is_shrinking:
		# Hold phase
		if phase_elapsed >= data["hold_time"]:
			is_shrinking = true
			phase_elapsed = 0.0
	else:
		# Shrinking phase
		current_radius = ZoneSystem.get_current_radius(current_phase, phase_elapsed, true)
		zone_shrinking.emit(current_phase, current_radius)
		if phase_elapsed >= data["shrink_time"]:
			# Advance to next phase
			current_phase += 1
			if current_phase < ZoneSystem.PHASE_COUNT:
				current_center = ZoneSystem.get_zone_center(current_phase, _map_size, _seed)
				current_radius = ZoneSystem.get_current_radius(current_phase, 0.0, false)
				is_shrinking = false
				phase_elapsed = 0.0
				zone_phase_changed.emit(current_phase)
			else:
				current_radius = 0.0
	# Apply zone damage every second
	if _damage_timer >= DAMAGE_TICK_INTERVAL:
		_damage_timer -= DAMAGE_TICK_INTERVAL
		_apply_zone_damage()


func _apply_zone_damage() -> void:
	if not multiplayer.is_server() and NetworkManager.get_peer_count() > 1:
		return
	var damage := ZoneSystem.get_damage_per_second(current_phase)
	if damage <= 0.0:
		return
	var players := get_tree().get_nodes_in_group("players")
	for player in players:
		if not player is Node3D:
			continue
		var pos: Vector3 = (player as Node3D).global_position
		if ZoneSystem.is_outside_zone(pos, current_center, current_radius):
			var hs := player.get_node_or_null("HealthSystem") as HealthSystem
			if hs and not hs.is_dead:
				hs.take_damage(damage, HealthSystem.DamageType.ZONE)
				var peer_id := player.get_multiplayer_authority() if multiplayer.has_multiplayer_peer() else 1
				zone_damage_tick.emit(peer_id, damage)


func get_time_until_shrink() -> float:
	if not _active:
		return 0.0
	var data := ZoneSystem.get_phase_data(current_phase)
	if data.is_empty():
		return 0.0
	if is_shrinking:
		return maxf(data["shrink_time"] - phase_elapsed, 0.0)
	return maxf(data["hold_time"] - phase_elapsed, 0.0)


# === RPCs ===

@rpc("authority", "reliable")
func _sync_zone_state(phase: int, shrinking: bool, elapsed: float, center: Vector3, radius: float) -> void:
	current_phase = phase
	is_shrinking = shrinking
	phase_elapsed = elapsed
	current_center = center
	current_radius = radius
