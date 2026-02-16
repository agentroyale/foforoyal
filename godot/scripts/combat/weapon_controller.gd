class_name WeaponController
extends Node
## Manages weapon fire, reload, recoil, spread/bloom, and recovery.
## TPS: shoots from camera with spread deviation, muzzle flash at weapon visual.

signal weapon_fired(weapon: WeaponData)
signal weapon_reloaded(weapon: WeaponData)
signal ammo_changed(current: int, max_ammo: int)
signal hit_confirmed(hitzone: int, is_kill: bool)
signal muzzle_flash_requested(pos: Vector3)
signal spread_changed(spread_degrees: float)

var _fire_timer: float = 0.0
var _can_fire: bool = true
var _is_reloading: bool = false
var _reload_timer: float = 0.0
var _current_ammo: int = 0
var _shot_count: int = 0
var _accumulated_recoil: Vector2 = Vector2.ZERO
var _current_bloom: float = 0.0
var _time_since_last_shot: float = 999.0
var _pending_shot_spread: float = 0.0


func _process(delta: float) -> void:
	if not get_parent().is_multiplayer_authority():
		return
	_update_fire_cooldown(delta)
	_update_reload(delta)
	_update_recoil_recovery(delta)
	_update_bloom_decay(delta)
	_time_since_last_shot += delta
	_emit_spread_update()


func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().is_multiplayer_authority():
		return
	if event.is_action_pressed("reload"):
		try_reload()


func try_fire() -> Dictionary:
	var weapon := _get_active_weapon()
	if not weapon:
		return {"fired": false, "weapon": null}
	if not _can_fire or _is_reloading:
		return {"fired": false, "weapon": weapon}
	if weapon.magazine_size > 0 and _current_ammo <= 0:
		return {"fired": false, "weapon": weapon}

	_fire(weapon)
	return {"fired": true, "weapon": weapon}


func _fire(weapon: WeaponData) -> void:
	_can_fire = false
	_fire_timer = weapon.fire_rate

	if weapon.magazine_size > 0:
		_current_ammo -= 1
		ammo_changed.emit(_current_ammo, weapon.magazine_size)

	if weapon.recoil_pattern:
		var offset := weapon.recoil_pattern.get_offset(_shot_count)
		_apply_recoil(offset)
	_shot_count += 1

	# Capture spread BEFORE bloom increment (first shot uses pre-bloom spread)
	_pending_shot_spread = _get_shot_spread(weapon)

	# Bloom increment (non-melee only)
	if weapon.weapon_type != WeaponData.WeaponType.MELEE:
		_current_bloom = SpreadSystem.calculate_bloom_after_shot(
			_current_bloom, weapon.bloom_per_shot, weapon.max_bloom
		)
	_time_since_last_shot = 0.0

	_emit_muzzle_flash()
	_spawn_shell(weapon)
	weapon_fired.emit(weapon)

	match weapon.weapon_type:
		WeaponData.WeaponType.SMG:
			WeaponSfx.play_auto()
		WeaponData.WeaponType.PISTOL:
			WeaponSfx.play_gunshot()
		WeaponData.WeaponType.AR:
			WeaponSfx.play_burst()
		WeaponData.WeaponType.SHOTGUN:
			WeaponSfx.play_shotgun()
		WeaponData.WeaponType.SNIPER:
			WeaponSfx.play_sniper()

	if _is_multiplayer_active():
		_fire_networked(weapon)
	else:
		_fire_local(weapon)


func _fire_local(weapon: WeaponData) -> void:
	match weapon.weapon_type:
		WeaponData.WeaponType.MELEE:
			_do_melee(weapon)
		WeaponData.WeaponType.BOW:
			_spawn_projectile(weapon)
		WeaponData.WeaponType.PISTOL, WeaponData.WeaponType.SMG, \
		WeaponData.WeaponType.AR, WeaponData.WeaponType.SHOTGUN, \
		WeaponData.WeaponType.SNIPER:
			_do_hitscan(weapon)


func _fire_networked(weapon: WeaponData) -> void:
	var camera := get_parent().get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return
	var cam_origin := camera.global_position
	var cam_dir := -camera.global_basis.z
	var timestamp := Time.get_ticks_msec() / 1000.0

	# Local VFX (tracer/shell happen immediately for responsiveness)
	match weapon.weapon_type:
		WeaponData.WeaponType.PISTOL, WeaponData.WeaponType.SMG, \
		WeaponData.WeaponType.AR, WeaponData.WeaponType.SHOTGUN, \
		WeaponData.WeaponType.SNIPER:
			var dir := SpreadSystem.apply_spread_to_direction(cam_dir, _pending_shot_spread)
			var end := cam_origin + dir * weapon.max_range
			_spawn_tracer(_get_muzzle_position(), end)
		WeaponData.WeaponType.BOW:
			_spawn_projectile(weapon)

	# Send to server for authoritative hit detection
	var cn := Engine.get_singleton("CombatNetcode") if Engine.has_singleton("CombatNetcode") else get_node_or_null("/root/CombatNetcode")
	if cn:
		cn.request_fire.rpc_id(1, cam_origin, cam_dir,
			weapon.weapon_type, _pending_shot_spread, timestamp)


func _is_multiplayer_active() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	# In a real multiplayer session there are 2+ peers; solo/test = only peer 1
	return NetworkManager.get_peer_count() > 1


func _do_hitscan(weapon: WeaponData) -> void:
	var camera := get_parent().get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return

	var origin := camera.global_position
	var dir := -camera.global_basis.z

	# Apply spread deviation
	dir = SpreadSystem.apply_spread_to_direction(dir, _pending_shot_spread)

	var space: PhysicsDirectSpaceState3D = get_parent().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + dir * weapon.max_range
	)
	query.exclude = [get_parent().get_rid()]

	var hit: Dictionary = space.intersect_ray(query)

	# Spawn bullet tracer
	var muzzle_pos := _get_muzzle_position()
	var end_point: Vector3 = hit["position"] if not hit.is_empty() else origin + dir * weapon.max_range
	_spawn_tracer(muzzle_pos, end_point)

	# Spawn impact sparks at hit point
	if not hit.is_empty():
		_spawn_impact(hit["position"], hit["normal"])

	if hit.is_empty():
		return

	var body: Node3D = hit["collider"]
	var hit_point: Vector3 = hit["position"]
	var hs := body.get_node_or_null("HealthSystem") as HealthSystem
	if not hs:
		return

	var dist := origin.distance_to(hit_point)
	var hitzone := HitzoneSystem.detect_hitzone(hit_point, body.global_position, 1.8)
	var mult := HitzoneSystem.get_multiplier(hitzone)
	var dmg := DamageCalculator.calculate_damage(
		weapon.base_damage, mult, 0.0, dist, weapon.max_range, weapon.falloff_start
	)

	var was_dead := hs.is_dead
	hs.take_damage(dmg, HealthSystem.DamageType.BULLET)
	var is_kill := not was_dead and hs.is_dead
	hit_confirmed.emit(hitzone, is_kill)


func _do_melee(weapon: WeaponData) -> void:
	var camera := get_parent().get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return

	var origin := camera.global_position
	var dir := -camera.global_basis.z
	var space: PhysicsDirectSpaceState3D = get_parent().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + dir * 2.5
	)
	query.exclude = [get_parent().get_rid()]

	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return

	var body: Node3D = hit["collider"]
	var hs := body.get_node_or_null("HealthSystem") as HealthSystem
	if not hs:
		return

	var was_dead := hs.is_dead
	hs.take_damage(weapon.base_damage, HealthSystem.DamageType.MELEE)
	var is_kill := not was_dead and hs.is_dead
	hit_confirmed.emit(HitzoneSystem.Hitzone.CHEST, is_kill)


const PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")

func _spawn_projectile(weapon: WeaponData) -> void:
	var camera := get_parent().get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return

	var cam_origin := camera.global_position
	var cam_dir := -camera.global_basis.z

	# Apply spread to camera direction
	cam_dir = SpreadSystem.apply_spread_to_direction(cam_dir, _pending_shot_spread)
	var target_point := cam_origin + cam_dir * weapon.max_range

	var muzzle_pos := _get_muzzle_position()

	var space: PhysicsDirectSpaceState3D = get_parent().get_world_3d().direct_space_state
	var obs_query := PhysicsRayQueryParameters3D.create(muzzle_pos, target_point)
	obs_query.exclude = [get_parent().get_rid()]
	var obs_hit := space.intersect_ray(obs_query)
	if obs_hit:
		target_point = obs_hit["position"]

	var dir := (target_point - muzzle_pos).normalized()
	var proj: Projectile = PROJECTILE_SCENE.instantiate()
	proj.direction = dir
	proj.speed = weapon.projectile_speed
	proj.projectile_gravity = weapon.projectile_gravity
	proj.damage = weapon.base_damage
	proj.shooter = get_parent()
	proj.global_position = muzzle_pos
	get_tree().current_scene.add_child(proj)


func _apply_recoil(offset_degrees: Vector2) -> void:
	var camera_pivot := _get_camera_pivot()
	var mult := 1.0
	if camera_pivot and camera_pivot is PlayerCamera and camera_pivot.is_aiming:
		mult = 0.5
	# Crouch reduction
	var player := get_parent() as CharacterBody3D
	if player and player is PlayerController and player.is_crouching:
		mult *= SpreadSystem.get_crouch_recoil_multiplier()
	var adjusted := offset_degrees * mult

	_accumulated_recoil += adjusted
	if camera_pivot:
		get_parent().rotate_y(deg_to_rad(-adjusted.x))
		camera_pivot.rotate_x(deg_to_rad(-adjusted.y))
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)


func _update_recoil_recovery(delta: float) -> void:
	if _accumulated_recoil.length() < 0.01:
		_accumulated_recoil = Vector2.ZERO
		return

	var weapon := _get_active_weapon()
	if not weapon or not weapon.recoil_pattern:
		return

	var recovery := weapon.recoil_pattern.recovery_speed * delta
	var recovery_vec := _accumulated_recoil.normalized() * minf(recovery, _accumulated_recoil.length())
	_accumulated_recoil -= recovery_vec

	var camera_pivot := _get_camera_pivot()
	if camera_pivot:
		get_parent().rotate_y(deg_to_rad(recovery_vec.x))
		camera_pivot.rotate_x(deg_to_rad(recovery_vec.y))
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)


func _update_bloom_decay(delta: float) -> void:
	var weapon := _get_active_weapon()
	if not weapon:
		return
	var decay_rate := weapon.bloom_decay_rate if weapon.bloom_decay_rate > 0.0 else SpreadSystem.BLOOM_DECAY_SPEED
	_current_bloom = SpreadSystem.decay_bloom(_current_bloom, delta, decay_rate)


func _emit_spread_update() -> void:
	var weapon := _get_active_weapon()
	if not weapon:
		return
	var spread := get_current_spread()
	spread_changed.emit(spread)


func _get_shot_spread(weapon: WeaponData) -> float:
	var movement_state := _get_movement_state()
	var movement_mult := SpreadSystem.get_movement_multiplier(movement_state)
	if SpreadSystem.is_first_shot_accurate(_time_since_last_shot):
		return SpreadSystem.get_first_shot_spread(weapon.min_spread) * movement_mult
	return SpreadSystem.calculate_current_spread(weapon.base_spread, _current_bloom, movement_mult)


func _get_movement_state() -> SpreadSystem.MovementState:
	var player := get_parent() as CharacterBody3D
	if not player:
		return SpreadSystem.MovementState.IDLE
	var h_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var is_crouching := false
	if player is PlayerController:
		is_crouching = player.is_crouching
	return SpreadSystem.get_movement_state(
		h_speed, is_crouching, player.is_on_floor(),
		PlayerController.WALK_SPEED, PlayerController.SPRINT_SPEED
	)


func get_current_spread() -> float:
	var weapon := _get_active_weapon()
	if not weapon:
		return 0.0
	var movement_state := _get_movement_state()
	var movement_mult := SpreadSystem.get_movement_multiplier(movement_state)
	return SpreadSystem.calculate_current_spread(weapon.base_spread, _current_bloom, movement_mult)


func get_current_bloom() -> float:
	return _current_bloom


func try_reload() -> bool:
	var weapon := _get_active_weapon()
	if not weapon or weapon.magazine_size <= 0:
		return false
	if _is_reloading or _current_ammo >= weapon.magazine_size:
		return false
	_is_reloading = true
	_reload_timer = weapon.reload_time
	WeaponSfx.play_reload()
	if _is_multiplayer_active():
		var cn := get_node_or_null("/root/CombatNetcode")
		if cn:
			cn.request_reload.rpc_id(1)
	return true


func _update_reload(delta: float) -> void:
	if not _is_reloading:
		return
	_reload_timer -= delta
	if _reload_timer <= 0.0:
		_is_reloading = false
		var weapon := _get_active_weapon()
		if weapon:
			_current_ammo = weapon.magazine_size
			ammo_changed.emit(_current_ammo, weapon.magazine_size)
			weapon_reloaded.emit(weapon)


func _update_fire_cooldown(delta: float) -> void:
	if not _can_fire:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_can_fire = true


func equip_weapon(weapon: WeaponData) -> void:
	_shot_count = 0
	_accumulated_recoil = Vector2.ZERO
	_current_bloom = 0.0
	_time_since_last_shot = 999.0
	_is_reloading = false
	_can_fire = true
	_current_ammo = weapon.magazine_size if weapon.magazine_size > 0 else 0
	ammo_changed.emit(_current_ammo, weapon.magazine_size)

	WeaponSfx.play_equip()

	var model := get_parent().get_node_or_null("PlayerModel") as PlayerModel
	if model:
		model.equip_weapon_visual(weapon)


func get_accumulated_recoil() -> Vector2:
	return _accumulated_recoil


func _get_active_weapon() -> WeaponData:
	var inv := get_parent().get_node_or_null("PlayerInventory") as PlayerInventory
	if not inv:
		return null
	var item := inv.get_active_item()
	if item is WeaponData:
		return item as WeaponData
	return null


func _get_camera_pivot() -> Node3D:
	return get_parent().get_node_or_null("CameraPivot") as Node3D


func _get_muzzle_position() -> Vector3:
	var model := get_parent().get_node_or_null("PlayerModel") as PlayerModel
	if model:
		return model.get_muzzle_position()
	var camera := get_parent().get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if camera:
		return camera.global_position + (-camera.global_basis.z) * 0.5
	return get_parent().global_position + Vector3.UP * 1.5


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var tracer := BulletTracer.create(from, to)
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(tracer)


func _emit_muzzle_flash() -> void:
	var pos := _get_muzzle_position()
	muzzle_flash_requested.emit(pos)

	# Spawn muzzle flash VFX
	var camera := get_parent().get_node_or_null("CameraPivot/Camera3D") as Camera3D
	var dir: Vector3 = -camera.global_basis.z if camera else Vector3.FORWARD
	var flash := MuzzleFlash.create(pos, dir)
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(flash)

	var camera_pivot := _get_camera_pivot()
	if camera_pivot and camera_pivot is PlayerCamera:
		camera_pivot.apply_shake(0.03)


func _spawn_shell(weapon: WeaponData) -> void:
	if weapon.weapon_type == WeaponData.WeaponType.MELEE or weapon.weapon_type == WeaponData.WeaponType.BOW:
		return
	var pos := _get_muzzle_position()
	var camera := get_parent().get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if not camera:
		return
	var right := camera.global_basis.x
	var up := Vector3.UP
	var shell := ShellEject.create(pos, right, up)
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(shell)
	WeaponSfx.play_shell_drop()


func _spawn_impact(hit_pos: Vector3, hit_normal: Vector3) -> void:
	var impact := ImpactEffect.create(hit_pos, hit_normal)
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(impact)
	WeaponSfx.play_ricochet()
