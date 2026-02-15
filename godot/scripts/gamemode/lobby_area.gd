extends Node3D
## Floating lobby platform for BR pre-game.
## 30x30m platform at 200m height with grid spawn points.

const PLATFORM_SIZE := 30.0
const PLATFORM_HEIGHT := 200.0
const MAX_SPAWN_POINTS := 64

var _spawn_points: Array[Vector3] = []


func _ready() -> void:
	_build_platform()
	_generate_spawn_points()


func get_spawn_position(index: int) -> Vector3:
	if _spawn_points.is_empty():
		_generate_spawn_points()
	return _spawn_points[index % _spawn_points.size()]


func get_spawn_count() -> int:
	return _spawn_points.size()


func _build_platform() -> void:
	# Static body for collision
	var body := StaticBody3D.new()
	body.name = "PlatformBody"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PLATFORM_SIZE, 1.0, PLATFORM_SIZE)
	col.shape = box
	body.add_child(col)
	# Visual
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(PLATFORM_SIZE, 1.0, PLATFORM_SIZE)
	mesh_inst.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.35)
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	body.position = Vector3(0.0, -0.5, 0.0)
	add_child(body)


func _generate_spawn_points() -> void:
	_spawn_points.clear()
	var grid_size := ceili(sqrt(float(MAX_SPAWN_POINTS)))
	var spacing := PLATFORM_SIZE / float(grid_size + 1)
	var offset := -PLATFORM_SIZE / 2.0 + spacing
	for z in range(grid_size):
		for x in range(grid_size):
			if _spawn_points.size() >= MAX_SPAWN_POINTS:
				break
			var pos := Vector3(
				offset + x * spacing,
				1.0,
				offset + z * spacing
			)
			_spawn_points.append(global_position + pos)
