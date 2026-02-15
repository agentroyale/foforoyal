class_name WeaponController
extends Node
## Manages weapon fire, reload, recoil application and recovery.

signal weapon_fired(weapon: WeaponData)
signal weapon_reloaded(weapon: WeaponData)
signal ammo_changed(current: int, max_ammo: int)

var _fire_timer: float = 0.0
var _can_fire: bool = true
var _is_reloading: bool = false
var _reload_timer: float = 0.0
var _current_ammo: int = 0
var _shot_count: int = 0
var _accumulated_recoil: Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
	if not get_parent().is_multiplayer_authority():
		return
	_update_fire_cooldown(delta)
	_update_reload(delta)
	_update_recoil_recovery(delta)


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

	weapon_fired.emit(weapon)


func _apply_recoil(offset_degrees: Vector2) -> void:
	_accumulated_recoil += offset_degrees
	var camera_pivot := _get_camera_pivot()
	if camera_pivot:
		get_parent().rotate_y(deg_to_rad(-offset_degrees.x))
		camera_pivot.rotate_x(deg_to_rad(-offset_degrees.y))
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


func try_reload() -> bool:
	var weapon := _get_active_weapon()
	if not weapon or weapon.magazine_size <= 0:
		return false
	if _is_reloading or _current_ammo >= weapon.magazine_size:
		return false
	_is_reloading = true
	_reload_timer = weapon.reload_time
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
	_is_reloading = false
	_can_fire = true
	_current_ammo = weapon.magazine_size if weapon.magazine_size > 0 else 0
	ammo_changed.emit(_current_ammo, weapon.magazine_size)


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
