extends Node3D
## Visual representation of the shrinking zone wall.
## MeshInstance3D with CylinderMesh + shader material.

var _mesh_instance: MeshInstance3D
var _zone_controller: Node  # ZoneController


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 200.0
	cylinder.radial_segments = 64
	_mesh_instance.mesh = cylinder
	# Load shader
	var shader := load("res://shaders/zone_wall.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_mesh_instance.material_override = mat
	else:
		# Fallback: semi-transparent blue
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.3, 0.2, 0.8, 0.15)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.2, 0.9)
		mat.emission_energy_multiplier = 2.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh_instance.material_override = mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)


func setup(zone_controller: Node) -> void:
	_zone_controller = zone_controller


func _process(_delta: float) -> void:
	if not _zone_controller:
		return
	var center: Vector3 = _zone_controller.current_center
	var radius: float = _zone_controller.current_radius
	global_position = Vector3(center.x, 100.0, center.z)
	_mesh_instance.scale = Vector3(radius, 1.0, radius)
	# Update shader time
	var mat := _mesh_instance.material_override
	if mat is ShaderMaterial:
		mat.set_shader_parameter("zone_radius", radius)
