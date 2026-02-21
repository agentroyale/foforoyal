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

const CHARACTER_MODELS := {
	"knight": "res://assets/kaykit/adventurers/Knight.glb",
	"mage": "res://assets/kaykit/adventurers/Mage.glb",
	"ranger": "res://assets/kaykit/adventurers/Ranger.glb",
	"rogue": "res://assets/kaykit/adventurers/Rogue.glb",
	"rogue_hooded": "res://assets/kaykit/adventurers/Rogue_Hooded.glb",
	"pepe": "res://assets/kaykit/adventurers/Pepe.glb",
	"meshy": "res://assets/kaykit/adventurers/MeshyBiped.glb",
	"camofrog": "res://assets/kaykit/adventurers/CamoFrog.glb",
	"camofrog_s": "res://assets/soldier/CamoFrog_Soldier.glb",
	"frogcommando": "res://assets/kaykit/adventurers/FrogCommando.glb",
	"bandolier": "res://assets/kaykit/adventurers/BandolierRanger.glb",
	"brett": "res://assets/kaykit/adventurers/Brett.glb",
	"pepe_new": "res://assets/kaykit/adventurers/PepeNew.glb",
	"elonzin": "res://assets/kaykit/adventurers/Elonzin.glb",
}


var is_crouching := false
var current_speed := WALK_SPEED
var _previous_velocity_y: float = 0.0
var movement_disabled: bool = false

# Network state for remote players (set by NetworkSync)
var remote_on_floor: bool = true
var network_is_aiming: bool = false
var network_weapon_type: int = -1
var network_move_speed: float = 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot


func _ready() -> void:
	floor_max_angle = deg_to_rad(55.0)
	_set_collision_height(STAND_HEIGHT)
	_swap_player_model()
	add_to_group("players")
	# Only give weapons/init crafting for local player
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
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
	var w := load("res://resources/weapons/assault_rifle.tres") as WeaponData
	if not w:
		return
	inv.hotbar.add_item(w, 1)
	var wc := get_node_or_null("WeaponController") as WeaponController
	if wc:
		wc.equip_weapon(w)


func _swap_player_model() -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	var char_id := GameSettings.selected_character
	if char_id == "barbarian" or char_id == "":
		return
	if char_id not in CHARACTER_MODELS:
		return
	var old_model := get_node_or_null("PlayerModel")
	if not old_model:
		return
	var scene := load(CHARACTER_MODELS[char_id]) as PackedScene
	if not scene:
		return
	remove_child(old_model)
	old_model.queue_free()
	var new_model := scene.instantiate()
	new_model.name = "PlayerModel"
	new_model.set_script(load("res://scripts/player/player_model.gd"))
	print("[PlayerController] Swapped model to '%s'" % char_id)
	add_child(new_model)
	move_child(new_model, 1)


func apply_remote_character(char_id: String) -> void:
	## Swap model on a remote player to match their character selection.
	if char_id == "" or char_id == "barbarian":
		return
	if char_id not in CHARACTER_MODELS:
		return
	var old_model := get_node_or_null("PlayerModel")
	if not old_model:
		return
	var scene := load(CHARACTER_MODELS[char_id]) as PackedScene
	if not scene:
		return
	remove_child(old_model)
	old_model.queue_free()
	var new_model := scene.instantiate()
	new_model.name = "PlayerModel"
	new_model.set_script(load("res://scripts/player/player_model.gd"))
	new_model._char_id = char_id
	print("[PlayerController] Remote model -> '%s'" % char_id)
	add_child(new_model)
	move_child(new_model, 1)


func disable_movement() -> void:
	movement_disabled = true

func enable_movement() -> void:
	movement_disabled = false

func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if movement_disabled:
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
	collision_shape.position.y = shape.height * 0.5

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
		# Skip fall damage if parachute is active
		var pc := get_node_or_null("ParachuteController")
		if pc and pc.get("is_dropping"):
			return
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
	collision_shape.position.y = height * 0.5
	camera_pivot.position.y = 1.8 if height >= STAND_HEIGHT else 1.1
