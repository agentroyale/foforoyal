class_name GroundItem
extends RigidBody3D
## Physical item on the ground that players can pick up.
## Uses RigidBody3D for physics, Area3D for pickup detection.

signal picked_up(by_peer_id: int)

@export var item_data: ItemData
@export var item_count: int = 1

const PICKUP_RADIUS := 2.0
const DESPAWN_TIME := 300.0
const BOB_SPEED := 2.0
const BOB_AMPLITUDE := 0.1
const ROTATE_SPEED := 1.0

var _pickup_area: Area3D
var _sprite: Sprite3D
var _despawn_timer: float = 0.0
var _bob_time: float = 0.0
var _settled: bool = false
var _initial_y: float = 0.0


func _ready() -> void:
	# Collision setup
	contact_monitor = true
	max_contacts_reported = 1
	gravity_scale = 1.0
	# Pickup area
	_pickup_area = Area3D.new()
	_pickup_area.name = "PickupArea"
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	col.shape = sphere
	_pickup_area.add_child(col)
	add_child(_pickup_area)
	# Visual: Sprite3D billboard
	_sprite = Sprite3D.new()
	_sprite.name = "ItemSprite"
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = 0.01
	_sprite.position = Vector3(0, 0.3, 0)
	if item_data and item_data.icon:
		_sprite.texture = item_data.icon
	add_child(_sprite)
	# Glow ring (simple mesh)
	var glow := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.4
	glow.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.9, 0.3, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.3)
	mat.emission_energy_multiplier = 1.5
	glow.material_override = mat
	glow.position = Vector3(0, 0.05, 0)
	add_child(glow)


func _process(delta: float) -> void:
	_despawn_timer += delta
	if _despawn_timer >= DESPAWN_TIME:
		queue_free()
		return
	# Bobbing + rotation once settled
	if _settled:
		_bob_time += delta
		_sprite.position.y = 0.3 + sin(_bob_time * BOB_SPEED) * BOB_AMPLITUDE
		_sprite.rotation.y += ROTATE_SPEED * delta


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _settled and state.get_contact_count() > 0 and linear_velocity.length() < 0.1:
		_settled = true
		freeze = true
		_initial_y = global_position.y


func interact(player: Node) -> bool:
	## Try to pick up this item. Returns true if successful.
	if not item_data:
		return false
	var inv := player.get_node_or_null("PlayerInventory") as PlayerInventory
	if not inv:
		return false
	var remaining := inv.add_item_to_inventory(item_data, item_count)
	if remaining < item_count:
		var taken := item_count - remaining
		item_count = remaining
		var peer_id := player.get_multiplayer_authority() if multiplayer.has_multiplayer_peer() else 1
		picked_up.emit(peer_id)
		if item_count <= 0:
			queue_free()
		return true
	return false


static func create(item: ItemData, count: int = 1, pos: Vector3 = Vector3.ZERO) -> GroundItem:
	var scene := load("res://scenes/items/ground_item.tscn") as PackedScene
	if scene:
		var inst: GroundItem = scene.instantiate()
		inst.item_data = item
		inst.item_count = count
		inst.global_position = pos
		return inst
	# Fallback: create manually
	var gi := GroundItem.new()
	gi.item_data = item
	gi.item_count = count
	gi.global_position = pos
	return gi
