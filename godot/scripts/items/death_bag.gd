class_name DeathBag
extends StaticBody3D
## Container that spawns where a player dies, holding their inventory items.

var items: Array[Dictionary] = []  # [{ "item": ItemData, "count": int }]
var _mesh: MeshInstance3D

const DESPAWN_TIME := 600.0
var _despawn_timer: float = 0.0


func _ready() -> void:
	# Collision
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.4, 0.6)
	col.shape = box
	col.position = Vector3(0, 0.2, 0)
	add_child(col)
	# Visual: simple box mesh
	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.6, 0.4, 0.6)
	_mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.3, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.4, 0.1)
	mat.emission_energy_multiplier = 0.5
	_mesh.material_override = mat
	_mesh.position = Vector3(0, 0.2, 0)
	add_child(_mesh)
	# Pickup area
	var area := Area3D.new()
	area.name = "InteractArea"
	var area_col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	area_col.shape = sphere
	area.add_child(area_col)
	add_child(area)


func _process(delta: float) -> void:
	_despawn_timer += delta
	if _despawn_timer >= DESPAWN_TIME:
		queue_free()


func set_items_from_inventory(inv: PlayerInventory) -> void:
	items.clear()
	# Hotbar
	for i in range(inv.HOTBAR_SIZE):
		var slot := inv.hotbar.get_slot(i)
		if not slot.is_empty():
			items.append({ "item": slot["item"], "count": slot["count"] })
	# Main inventory
	for i in range(inv.MAIN_SIZE):
		var slot := inv.main_inventory.get_slot(i)
		if not slot.is_empty():
			items.append({ "item": slot["item"], "count": slot["count"] })


func interact(player: Node) -> bool:
	## Transfer all items to player inventory, leaving overflow.
	if items.is_empty():
		return false
	var inv := player.get_node_or_null("PlayerInventory") as PlayerInventory
	if not inv:
		return false
	var remaining_items: Array[Dictionary] = []
	for entry in items:
		var overflow := inv.add_item_to_inventory(entry["item"], entry["count"])
		if overflow > 0:
			remaining_items.append({ "item": entry["item"], "count": overflow })
	items = remaining_items
	if items.is_empty():
		queue_free()
	return true


func get_item_count() -> int:
	var total := 0
	for entry in items:
		total += entry["count"]
	return total
