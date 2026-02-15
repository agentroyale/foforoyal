extends Node
## Server-authoritative combat networking.
## Handles fire requests, hit validation with lag compensation,
## damage sync, death broadcast, and VFX replication.

signal kill_event(killer_name: String, victim_name: String, weapon_name: String)

const MAX_FIRE_RATE_TOLERANCE := 0.02  # Allow slight timing variance


func _ready() -> void:
	# Clean up lag comp data when peers disconnect
	if multiplayer.has_multiplayer_peer():
		NetworkManager.player_disconnected.connect(_on_peer_disconnected)


func _on_peer_disconnected(peer_id: int) -> void:
	# Find that player's NetworkSync and clear lag comp
	var container := get_tree().current_scene.get_node_or_null("Players")
	if not container:
		container = get_tree().current_scene
	var player_node := container.get_node_or_null(str(peer_id))
	if player_node:
		var ns := player_node.get_node_or_null("NetworkSync") as NetworkSync
		if ns and ns.get_lag_compensation():
			ns.get_lag_compensation().clear_peer(peer_id)


# === CLIENT: Request fire ===

@rpc("any_peer", "reliable")
func request_fire(cam_origin: Vector3, cam_dir: Vector3, weapon_type: int,
		spread: float, timestamp: float) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	var shooter := _get_player_node(sender_id)
	if not shooter:
		return

	var wc := shooter.get_node_or_null("WeaponController") as WeaponController
	if not wc:
		return

	# Server validates fire (fire rate, ammo handled by WeaponController state)
	# We trust the client's local WeaponController state for now but validate position
	var shooter_pos := shooter.global_position
	if cam_origin.distance_to(shooter_pos) > 5.0:
		return  # Camera too far from player, suspicious

	# Perform hit detection based on weapon type
	match weapon_type:
		WeaponData.WeaponType.PISTOL, WeaponData.WeaponType.SMG:
			_server_hitscan(sender_id, shooter, cam_origin, cam_dir, spread, timestamp)
		WeaponData.WeaponType.MELEE:
			_server_melee(sender_id, shooter, cam_origin, cam_dir)

	# Broadcast fire VFX to all other clients
	var muzzle_pos := Vector3.ZERO
	var model := shooter.get_node_or_null("PlayerModel") as PlayerModel
	if model:
		muzzle_pos = model.get_muzzle_position()
	else:
		muzzle_pos = shooter_pos + Vector3.UP * 1.5

	for peer_id in NetworkManager.connected_peers:
		if peer_id != sender_id:
			_replicate_fire_vfx.rpc_id(peer_id, sender_id, muzzle_pos,
				cam_origin + cam_dir * 120.0, weapon_type)


func _server_hitscan(sender_id: int, shooter: CharacterBody3D,
		cam_origin: Vector3, cam_dir: Vector3, spread: float,
		timestamp: float) -> void:
	# Apply spread server-side
	var dir := SpreadSystem.apply_spread_to_direction(cam_dir, spread)

	# Get weapon data for damage calc
	var wc := shooter.get_node_or_null("WeaponController") as WeaponController
	var inv := shooter.get_node_or_null("PlayerInventory") as PlayerInventory
	if not inv:
		return
	var item := inv.get_active_item()
	if not item is WeaponData:
		return
	var weapon := item as WeaponData

	# Raycast on server
	var space := shooter.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		cam_origin, cam_origin + dir * weapon.max_range
	)
	query.exclude = [shooter.get_rid()]
	var hit := space.intersect_ray(query)

	var end_point: Vector3 = hit["position"] if not hit.is_empty() else cam_origin + dir * weapon.max_range

	if hit.is_empty():
		return

	var body: Node3D = hit["collider"]
	var hit_point: Vector3 = hit["position"]
	var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
	var hs := body.get_node_or_null("HealthSystem") as HealthSystem
	if not hs:
		# Hit non-damageable (wall, terrain) -- broadcast impact
		_broadcast_impact(hit_point, hit_normal)
		return

	# Calculate damage
	var dist := cam_origin.distance_to(hit_point)
	var hitzone := HitzoneSystem.detect_hitzone(hit_point, body.global_position, 1.8)
	var mult := HitzoneSystem.get_multiplier(hitzone)
	var dmg := DamageCalculator.calculate_damage(
		weapon.base_damage, mult, 0.0, dist, weapon.max_range, weapon.falloff_start
	)

	# Validate damage range
	if not ServerValidation.validate_damage(dmg, weapon.base_damage):
		return

	# Apply damage on server
	var was_dead := hs.is_dead
	hs.take_damage(dmg, HealthSystem.DamageType.BULLET)
	var is_kill := not was_dead and hs.is_dead

	# Notify shooter of hit
	_confirm_hit.rpc_id(sender_id, hitzone, is_kill)

	# Broadcast damage to victim and all clients
	var victim_peer := body.get_multiplayer_authority()
	_sync_damage.rpc(victim_peer, dmg, HealthSystem.DamageType.BULLET,
		hs.current_hp, hs.is_dead)

	# Broadcast impact VFX
	_broadcast_impact(hit_point, hit_normal)

	# Kill event
	if is_kill:
		var killer_name := "Player %d" % sender_id
		var victim_name := "Player %d" % victim_peer
		_broadcast_kill.rpc(killer_name, victim_name, weapon.item_name)
		_handle_br_kill(victim_peer, sender_id, body)


func _handle_br_kill(victim_peer: int, killer_peer: int, victim_node: Node) -> void:
	if not MatchManager.is_br_mode():
		return
	# Spawn death bag
	var inv := victim_node.get_node_or_null("PlayerInventory") as PlayerInventory
	if inv:
		var bag := DeathBag.new()
		bag.set_items_from_inventory(inv)
		bag.global_position = (victim_node as Node3D).global_position
		if get_tree() and get_tree().current_scene:
			get_tree().current_scene.add_child(bag)
		inv.clear_all()
	MatchManager.eliminate_player(victim_peer, killer_peer)


func _server_melee(sender_id: int, shooter: CharacterBody3D,
		cam_origin: Vector3, cam_dir: Vector3) -> void:
	var inv := shooter.get_node_or_null("PlayerInventory") as PlayerInventory
	if not inv:
		return
	var item := inv.get_active_item()
	if not item is WeaponData:
		return
	var weapon := item as WeaponData

	var space := shooter.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		cam_origin, cam_origin + cam_dir * 2.5
	)
	query.exclude = [shooter.get_rid()]
	var hit := space.intersect_ray(query)

	if hit.is_empty():
		return

	var body: Node3D = hit["collider"]
	var hs := body.get_node_or_null("HealthSystem") as HealthSystem
	if not hs:
		return

	var was_dead := hs.is_dead
	hs.take_damage(weapon.base_damage, HealthSystem.DamageType.MELEE)
	var is_kill := not was_dead and hs.is_dead

	_confirm_hit.rpc_id(sender_id, HitzoneSystem.Hitzone.CHEST, is_kill)

	var victim_peer := body.get_multiplayer_authority()
	_sync_damage.rpc(victim_peer, weapon.base_damage, HealthSystem.DamageType.MELEE,
		hs.current_hp, hs.is_dead)

	if is_kill:
		var killer_name := "Player %d" % sender_id
		var victim_name := "Player %d" % victim_peer
		_broadcast_kill.rpc(killer_name, victim_name, weapon.item_name)
		_handle_br_kill(victim_peer, sender_id, body)


# === SERVER -> CLIENT: Confirm hit to shooter ===

@rpc("authority", "reliable")
func _confirm_hit(hitzone: int, is_kill: bool) -> void:
	# Find local player's weapon controller and emit hit_confirmed
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if p.is_multiplayer_authority():
			var wc := p.get_node_or_null("WeaponController") as WeaponController
			if wc:
				wc.hit_confirmed.emit(hitzone, is_kill)
			break


# === SERVER -> ALL: Sync damage state ===

@rpc("authority", "reliable")
func _sync_damage(victim_peer_id: int, damage: float, damage_type: int,
		new_hp: float, is_dead: bool) -> void:
	var victim := _get_player_node(victim_peer_id)
	if not victim:
		return
	var hs := victim.get_node_or_null("HealthSystem") as HealthSystem
	if not hs:
		return

	# Sync health state
	hs.current_hp = new_hp
	hs.is_dead = is_dead
	hs.damage_taken.emit(damage, damage_type)
	if is_dead:
		hs.died.emit()


# === SERVER -> ALL: Kill event for kill feed ===

@rpc("authority", "reliable")
func _broadcast_kill(killer_name: String, victim_name: String, weapon_name: String) -> void:
	kill_event.emit(killer_name, victim_name, weapon_name)


# === SERVER -> ALL: Replicate fire VFX on remote clients ===

@rpc("authority", "unreliable")
func _replicate_fire_vfx(shooter_peer_id: int, muzzle_pos: Vector3,
		end_point: Vector3, weapon_type: int) -> void:
	# Spawn tracer
	if get_tree() and get_tree().current_scene:
		var tracer := BulletTracer.create(muzzle_pos, end_point)
		get_tree().current_scene.add_child(tracer)

	# Play gunshot sound
	match weapon_type:
		WeaponData.WeaponType.SMG:
			WeaponSfx.play_auto()
		WeaponData.WeaponType.PISTOL:
			WeaponSfx.play_gunshot()

	# Spawn muzzle flash at shooter's muzzle
	var dir := (end_point - muzzle_pos).normalized()
	var flash := MuzzleFlash.create(muzzle_pos, dir)
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(flash)


func _broadcast_impact(hit_pos: Vector3, hit_normal: Vector3) -> void:
	for peer_id in NetworkManager.connected_peers:
		_replicate_impact.rpc_id(peer_id, hit_pos, hit_normal)


@rpc("authority", "unreliable")
func _replicate_impact(hit_pos: Vector3, hit_normal: Vector3) -> void:
	var impact := ImpactEffect.create(hit_pos, hit_normal)
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(impact)
	WeaponSfx.play_ricochet()


# === CLIENT: Request reload ===

@rpc("any_peer", "reliable")
func request_reload() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var player := _get_player_node(sender_id)
	if not player:
		return
	var wc := player.get_node_or_null("WeaponController") as WeaponController
	if wc:
		wc.try_reload()


# === CLIENT: Request equip ===

@rpc("any_peer", "reliable")
func request_equip(slot_index: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var player := _get_player_node(sender_id)
	if not player:
		return
	# Broadcast equip SFX to other clients
	for peer_id in NetworkManager.connected_peers:
		if peer_id != sender_id:
			_replicate_equip.rpc_id(peer_id, sender_id)


@rpc("authority", "unreliable")
func _replicate_equip(_shooter_peer_id: int) -> void:
	WeaponSfx.play_equip()


# === SERVER -> ALL: Projectile spawn ===

@rpc("any_peer", "reliable")
func request_spawn_projectile(muzzle_pos: Vector3, direction: Vector3,
		speed: float, gravity: float, damage: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	# Broadcast to all clients to spawn visual projectile
	_replicate_projectile.rpc(sender_id, muzzle_pos, direction, speed, gravity, damage)


@rpc("authority", "reliable")
func _replicate_projectile(shooter_peer_id: int, muzzle_pos: Vector3,
		direction: Vector3, speed: float, gravity: float, damage: float) -> void:
	var proj_scene := load("res://scenes/combat/projectile.tscn") as PackedScene
	if not proj_scene:
		return
	var proj: Projectile = proj_scene.instantiate()
	proj.direction = direction
	proj.speed = speed
	proj.projectile_gravity = gravity
	proj.damage = damage
	# Find shooter node to set as excluded
	var shooter := _get_player_node(shooter_peer_id)
	proj.shooter = shooter
	proj.global_position = muzzle_pos
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(proj)


# === SERVER -> ALL: Respawn ===

@rpc("any_peer", "reliable")
func request_respawn() -> void:
	if not multiplayer.is_server():
		return
	# Block respawn in Battle Royale
	if MatchManager.is_br_mode():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var player := _get_player_node(sender_id)
	if not player:
		return
	var hs := player.get_node_or_null("HealthSystem") as HealthSystem
	if not hs:
		return

	hs.respawn()

	# Get spawn position
	var spawn_pos := _get_spawn_position(sender_id)
	player.global_position = spawn_pos
	player.velocity = Vector3.ZERO

	# Sync respawn to all clients
	_sync_respawn.rpc(sender_id, spawn_pos, hs.current_hp, hs.max_hp)


@rpc("authority", "reliable")
func _sync_respawn(peer_id: int, spawn_pos: Vector3, hp: float, max_hp: float) -> void:
	var player := _get_player_node(peer_id)
	if not player:
		return
	var hs := player.get_node_or_null("HealthSystem") as HealthSystem
	if hs:
		hs.current_hp = hp
		hs.is_dead = false
		hs.respawned.emit()
	player.global_position = spawn_pos
	player.velocity = Vector3.ZERO


# === Helpers ===

func _get_player_node(peer_id: int) -> CharacterBody3D:
	# Try Players container first
	var container := get_tree().current_scene.get_node_or_null("Players")
	if container:
		var node := container.get_node_or_null(str(peer_id))
		if node:
			return node as CharacterBody3D

	# Fallback: search in players group
	for p in get_tree().get_nodes_in_group("players"):
		if p.get_multiplayer_authority() == peer_id:
			return p as CharacterBody3D

	# Fallback: single player scene (Player node directly)
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player and player.get_multiplayer_authority() == peer_id:
		return player as CharacterBody3D

	return null


func _get_spawn_position(peer_id: int) -> Vector3:
	# Use WorldGenerator if available
	var center := 528.0  # Default center
	var wg := get_node_or_null("/root/WorldGenerator")
	if wg and wg.has_method("get_height_at"):
		var height: float = wg.get_height_at(center, center) + 2.0
		return Vector3(center, height, center)
	return Vector3(0, 5, 0)
