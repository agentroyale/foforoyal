class_name PlayerController
extends CharacterBody3D
## FPS player movement: WASD, sprint, jump, crouch.

const WALK_SPEED := 4.0
const SPRINT_SPEED := 6.5
const CROUCH_SPEED := 2.0
const JUMP_VELOCITY := 5.0
const GRAVITY := 12.0

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const CROUCH_LERP_SPEED := 10.0

const FALL_DAMAGE_THRESHOLD := 8.0
const FALL_DAMAGE_MULTIPLIER := 10.0

var is_crouching := false
var current_speed := WALK_SPEED
var _previous_velocity_y: float = 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot


func _ready() -> void:
	floor_max_angle = deg_to_rad(55.0)
	_set_collision_height(STAND_HEIGHT)
	add_to_group("players")
	_give_starter_weapon.call_deferred()
	_init_crafting_queue.call_deferred()


func _init_crafting_queue() -> void:
	var cq := get_node_or_null("CraftingQueue") as CraftingQueue
	var inv := get_node_or_null("PlayerInventory") as PlayerInventory
	if cq and inv:
		cq.player_inventory = inv


func _give_starter_weapon() -> void:
	var inv := get_node_or_null("PlayerInventory") as PlayerInventory
	if not inv:
		return
	var w := WeaponData.new()
	w.item_name = "Assault Rifle"
	w.max_stack_size = 1
	w.category = ItemData.Category.WEAPON
	w.weapon_type = WeaponData.WeaponType.SMG
	w.base_damage = 22.0
	w.fire_rate = 0.1
	w.max_range = 120.0
	w.falloff_start = 60.0
	w.magazine_size = 30
	w.reload_time = 2.0
	w.model_position_offset = Vector3.ZERO
	w.model_rotation_offset = Vector3.ZERO
	w.model_scale = 0.4
	w.muzzle_offset = Vector3(2.92, 0.19, 0.0)
	w.base_spread = 0.3
	w.min_spread = 0.05
	w.bloom_per_shot = 0.6
	w.max_bloom = 4.0
	w.bloom_decay_rate = 8.0
	var rifle_scene := load("res://assets/weapons/AssaultRifle_1.fbx") as PackedScene
	if rifle_scene:
		w.weapon_mesh_scene = rifle_scene
	var rifle_icon := load("res://assets/textures/icons/assault_rifle.png") as Texture2D
	if rifle_icon:
		w.icon = rifle_icon
	var rp := RecoilPattern.new()
	rp.offsets = [Vector2(0.1, 0.8), Vector2(-0.2, 1.0), Vector2(0.15, 0.9), Vector2(-0.1, 1.1)] as Array[Vector2]
	rp.recovery_speed = 6.0
	w.recoil_pattern = rp
	inv.hotbar.add_item(w, 1)
	var wc := get_node_or_null("WeaponController") as WeaponController
	if wc:
		wc.equip_weapon(w)


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	_previous_velocity_y = velocity.y
	_apply_gravity(delta)
	_handle_jump()
	_handle_crouch(delta)
	_handle_movement()
	move_and_slide()
	_check_fall_damage()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY


func _handle_crouch(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed("crouch")

	if wants_crouch and not is_crouching:
		is_crouching = true
		current_speed = CROUCH_SPEED
	elif not wants_crouch and is_crouching:
		is_crouching = false
		current_speed = WALK_SPEED

	var target_height := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	var shape: CapsuleShape3D = collision_shape.shape
	shape.height = lerp(shape.height, target_height, CROUCH_LERP_SPEED * delta)

	# Adjust camera pivot to follow crouch (TPS: keep at head height)
	var target_y := 1.8 if not is_crouching else 1.1
	camera_pivot.position.y = lerp(camera_pivot.position.y, target_y, CROUCH_LERP_SPEED * delta)


func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Sprint only when moving forward, not crouching, and have stamina
	var stamina: StaminaSystem = get_node_or_null("StaminaSystem") as StaminaSystem
	var wants_sprint: bool = Input.is_action_pressed("sprint") and not is_crouching and input_dir.y < 0
	var can_do_sprint: bool = wants_sprint and (stamina == null or stamina.can_sprint())

	if can_do_sprint:
		current_speed = SPRINT_SPEED
		if stamina:
			stamina.set_draining(true)
	else:
		if not is_crouching:
			current_speed = WALK_SPEED
		if stamina:
			stamina.set_draining(false)

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)


func get_current_speed() -> float:
	return current_speed


func get_collision_height() -> float:
	var shape: CapsuleShape3D = collision_shape.shape
	return shape.height


func _check_fall_damage() -> void:
	if is_on_floor() and _previous_velocity_y < -FALL_DAMAGE_THRESHOLD:
		var fall_speed := absf(_previous_velocity_y)
		var damage := calculate_fall_damage(fall_speed)
		var hs := get_node_or_null("HealthSystem") as HealthSystem
		if hs:
			hs.take_damage(damage, HealthSystem.DamageType.FALL)


func calculate_fall_damage(fall_speed: float) -> float:
	## Pure calculation for testing.
	if fall_speed <= FALL_DAMAGE_THRESHOLD:
		return 0.0
	return (fall_speed - FALL_DAMAGE_THRESHOLD) * FALL_DAMAGE_MULTIPLIER


func _set_collision_height(height: float) -> void:
	var shape: CapsuleShape3D = collision_shape.shape
	shape.height = height
	camera_pivot.position.y = height * 0.5 - 0.1
