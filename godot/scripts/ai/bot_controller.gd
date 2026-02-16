class_name BotController
extends CharacterBody3D
## AI bot that reuses PlayerModel, WeaponController, and HealthSystem.
## Patrols, detects players via raycast, chases and attacks.

enum State { PATROL, CHASE, ATTACK, DEAD }

const WALK_SPEED := 3.5
const RUN_SPEED := 6.0
const GRAVITY := 12.0
const DETECTION_RANGE := 80.0
const HEAR_RANGE := 20.0
const ATTACK_RANGE := 50.0
const ATTACK_RANGE_MIN := 5.0
const AIM_INACCURACY_DEG := 5.0
const PATROL_CHANGE_TIME_MIN := 2.0
const PATROL_CHANGE_TIME_MAX := 4.0
const CORPSE_LINGER_TIME := 5.0
const FIRE_INTERVAL := 0.7

const CHARACTER_GLBS := [
	"res://assets/kaykit/adventurers/Barbarian.glb",
	"res://assets/kaykit/adventurers/Knight.glb",
	"res://assets/kaykit/adventurers/Mage.glb",
	"res://assets/kaykit/adventurers/Ranger.glb",
	"res://assets/kaykit/adventurers/Rogue.glb",
	"res://assets/kaykit/adventurers/Rogue_Hooded.glb",
]

const WEAPON_PATHS := [
	"res://resources/weapons/assault_rifle.tres",
	"res://resources/weapons/mp5.tres",
	"res://resources/weapons/pistol.tres",
	"res://resources/weapons/thompson.tres",
	"res://resources/weapons/pump_shotgun.tres",
	"res://resources/weapons/revolver.tres",
]

var state: State = State.PATROL
var _patrol_dir := Vector3.ZERO
var _patrol_timer := 0.0
var _fire_timer := 0.0
var _target: CharacterBody3D = null
var _corpse_timer := 0.0
var _rng := RandomNumberGenerator.new()

@onready var _aim_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _health: HealthSystem = $HealthSystem
@onready var _weapon_ctrl: WeaponController = $WeaponController
@onready var _inventory: PlayerInventory = $PlayerInventory
@onready var _model: Node3D = $PlayerModel
@onready var _raycast: RayCast3D = $DetectionRay


func _ready() -> void:
	_rng.randomize()
	add_to_group("bots")
	add_to_group("players")
	_health.died.connect(_on_died)
	_pick_patrol_direction()


func setup(glb_path: String, weapon_path: String) -> void:
	# Replace character model
	var old_model := get_node_or_null("PlayerModel")
	if old_model:
		var scene := load(glb_path) as PackedScene
		if scene:
			remove_child(old_model)
			old_model.queue_free()
			var new_model := scene.instantiate()
			new_model.name = "PlayerModel"
			new_model.set_script(load("res://scripts/player/player_model.gd"))
			add_child(new_model)
			move_child(new_model, 1)
			_model = new_model
	# Equip weapon after one frame so PlayerModel skeleton is ready
	_equip_weapon.call_deferred(weapon_path)


func _equip_weapon(path: String) -> void:
	var w := load(path) as WeaponData
	if not w:
		return
	_inventory.hotbar.add_item(w, 1)
	_weapon_ctrl.equip_weapon(w)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_corpse_timer -= delta
		if _corpse_timer <= 0.0:
			queue_free()
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	_fire_timer = maxf(_fire_timer - delta, 0.0)

	match state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)

	move_and_slide()


func _process_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_pick_patrol_direction()

	velocity.x = _patrol_dir.x * WALK_SPEED
	velocity.z = _patrol_dir.z * WALK_SPEED

	if _patrol_dir.length_squared() > 0.01:
		_face_direction(_patrol_dir, 0.12)

	var target := _find_target()
	if target:
		_target = target
		state = State.CHASE


func _process_chase(_delta: float) -> void:
	if not _is_target_valid():
		# Lost target, try to find new one immediately
		_target = _find_target()
		if not _target:
			state = State.PATROL
			return

	var to_target := _target.global_position - global_position
	var dist := to_target.length()
	var dir_xz := Vector3(to_target.x, 0.0, to_target.z).normalized()

	if dist <= ATTACK_RANGE and _has_line_of_sight(_target):
		state = State.ATTACK
		return

	velocity.x = dir_xz.x * RUN_SPEED
	velocity.z = dir_xz.z * RUN_SPEED
	_face_direction(dir_xz, 0.35)


func _process_attack(_delta: float) -> void:
	if not _is_target_valid():
		state = State.PATROL
		_target = null
		return

	var to_target := _target.global_position - global_position
	var dist := to_target.length()

	if dist > ATTACK_RANGE * 1.2 or not _has_line_of_sight(_target):
		state = State.CHASE
		return

	# Stop moving (or back up if too close)
	if dist < ATTACK_RANGE_MIN:
		var away := -Vector3(to_target.x, 0.0, to_target.z).normalized()
		velocity.x = away.x * WALK_SPEED
		velocity.z = away.z * WALK_SPEED
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# Aim at target torso
	_aim_at_target(_target)

	# Fire
	if _fire_timer <= 0.0:
		_weapon_ctrl.try_fire()
		_fire_timer = FIRE_INTERVAL


func _aim_at_target(target: CharacterBody3D) -> void:
	var target_pos := target.global_position + Vector3.UP * 1.4
	# Add inaccuracy
	var inaccuracy_rad := deg_to_rad(AIM_INACCURACY_DEG)
	target_pos.x += _rng.randf_range(-inaccuracy_rad, inaccuracy_rad) * 2.0
	target_pos.y += _rng.randf_range(-inaccuracy_rad, inaccuracy_rad) * 2.0
	target_pos.z += _rng.randf_range(-inaccuracy_rad, inaccuracy_rad) * 2.0

	# Face target horizontally (snap fast when attacking)
	var dir_xz := Vector3(target_pos.x - global_position.x, 0.0, target_pos.z - global_position.z)
	if dir_xz.length_squared() > 0.01:
		_face_direction(dir_xz.normalized(), 0.5)

	# Pitch the aim pivot to look at target
	var aim_origin := _aim_pivot.global_position
	var diff := target_pos - aim_origin
	if diff.length_squared() > 0.01:
		_aim_pivot.look_at(target_pos, Vector3.UP)
		# Camera inherits aim pivot transform
		_camera.global_transform = _aim_pivot.global_transform


func _find_target() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("players")
	var best: CharacterBody3D = null
	var best_dist := DETECTION_RANGE

	for node in players:
		if node == self:
			continue
		if node.is_in_group("bots"):
			continue
		var body := node as CharacterBody3D
		if not body:
			continue
		var hs := body.get_node_or_null("HealthSystem") as HealthSystem
		if hs and hs.is_dead:
			continue
		var dist := global_position.distance_to(body.global_position)
		if dist >= best_dist:
			continue
		# Close range = always detect ("hearing"), far = need LOS
		if dist < HEAR_RANGE or _has_line_of_sight(body):
			best_dist = dist
			best = body

	return best


func _has_line_of_sight(target: CharacterBody3D) -> bool:
	var from := global_position + Vector3.UP * 1.4
	var to := target.global_position + Vector3.UP * 1.0
	var space := get_world_3d().direct_space_state
	if not space:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid(), target.get_rid()]
	query.collision_mask = 0xFFFFFFFF  # All layers
	var result := space.intersect_ray(query)
	return result.is_empty()


func _pick_patrol_direction() -> void:
	var angle := _rng.randf() * TAU
	_patrol_dir = Vector3(cos(angle), 0.0, sin(angle))
	_patrol_timer = _rng.randf_range(PATROL_CHANGE_TIME_MIN, PATROL_CHANGE_TIME_MAX)


func _face_direction(dir: Vector3, speed: float = 0.15) -> void:
	if dir.length_squared() < 0.001:
		return
	# Body's -Z must face dir (model faces -Z after animation resets rotation)
	var target_y := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_y, speed)


func _is_target_valid() -> bool:
	if not is_instance_valid(_target):
		return false
	var hs := _target.get_node_or_null("HealthSystem") as HealthSystem
	if hs and hs.is_dead:
		return false
	var dist := global_position.distance_to(_target.global_position)
	return dist < DETECTION_RANGE * 1.5


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	_corpse_timer = CORPSE_LINGER_TIME
	set_collision_layer(0)
	set_collision_mask(0)
