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
var _is_replaying: bool = false
var _prediction: ClientPrediction = null
var _visual_offset: Vector3 = Vector3.ZERO

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
	var input := _gather_local_input()
	simulate_tick(input, delta)
	# Record for client-side prediction (multiplayer only)
	if _prediction:
		var state := {
			"position": global_position,
			"velocity_y": velocity.y,
			"is_crouching": is_crouching,
		}
		_prediction.record_input(input, state)
	# Decay visual offset (smoothing corrections)
	if _visual_offset.length() > 0.01:
		_visual_offset *= 0.85
	else:
		_visual_offset = Vector3.ZERO


func _process(_delta: float) -> void:
	# Apply visual offset to model (not CharacterBody3D position)
	var model := get_node_or_null("PlayerModel") as Node3D
	if not model:
		return
	if _visual_offset.length() > 0.001:
		model.position = _visual_offset
	else:
		model.position = Vector3.ZERO


func apply_server_correction(server_pos: Vector3, server_vel_y: float,
		server_seq: int, server_is_crouching: bool) -> void:
	if not _prediction:
		return
	var result := _prediction.reconcile(server_pos, server_vel_y, server_seq,
			server_is_crouching)
	if not result["needs_correction"]:
		return

	var error := (result["server_position"] as Vector3).distance_to(global_position)

	if error > ClientPrediction.SNAP_THRESHOLD:
		# Teleport (spawn, zone damage tp, etc)
		global_position = result["server_position"]
		velocity.y = result["server_velocity_y"]
		_visual_offset = Vector3.ZERO
		return

	# Save old predicted position for visual offset
	var old_pos := global_position

	# Snap to server state
	global_position = result["server_position"]
	velocity.y = result["server_velocity_y"]
	is_crouching = result["server_is_crouching"]

	# Replay pending inputs
	_is_replaying = true
	var replay_delta := 1.0 / 60.0
	for input in result["pending_inputs"]:
		simulate_tick(input, replay_delta)
	_is_replaying = false

	# Visual offset = old predicted pos vs new corrected+replayed pos
	_visual_offset = old_pos - global_position


func _gather_local_input() -> Dictionary:
	return {
		"direction": Input.get_vector("move_left", "move_right", "move_forward", "move_backward"),
		"jump": Input.is_action_just_pressed("jump"),
		"sprint": Input.is_action_pressed("sprint"),
		"crouch": Input.is_action_pressed("crouch"),
	}


func simulate_tick(input: Dictionary, delta: float) -> void:
	_previous_velocity_y = velocity.y
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	# Jump
	if input.get("jump", false) and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY
	# Crouch
	_handle_crouch_from_input(input.get("crouch", false), delta)
	# Movement
	_handle_movement_from_input(
		input.get("direction", Vector2.ZERO),
		input.get("sprint", false),
	)
	move_and_slide()
	if not _is_replaying:
		_check_fall_damage()


func _handle_crouch_from_input(wants_crouch: bool, delta: float) -> void:
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
	if not _is_replaying:
		var target_y := 1.8 if not is_crouching else 1.1
		camera_pivot.position.y = lerp(camera_pivot.position.y, target_y, CROUCH_LERP_SPEED * delta)


func _handle_movement_from_input(input_dir: Vector2, wants_sprint: bool) -> void:
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Sprint only when moving forward, not crouching, and have stamina
	var stamina: StaminaSystem = get_node_or_null("StaminaSystem") as StaminaSystem
	var can_sprint_input: bool = wants_sprint and not is_crouching and input_dir.y < 0
	var can_do_sprint: bool = can_sprint_input and (stamina == null or stamina.can_sprint())

	if can_do_sprint:
		current_speed = SPRINT_SPEED
		if stamina and not _is_replaying:
			stamina.set_draining(true)
	else:
		if not is_crouching:
			current_speed = WALK_SPEED
		if stamina and not _is_replaying:
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
