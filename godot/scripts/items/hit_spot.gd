class_name HitSpot
extends Marker3D
## Visual indicator for the bonus hit zone on a resource node.

@onready var visual: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	if not visual:
		_create_visual()


func _create_visual() -> void:
	visual = MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	visual.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.3)
	mat.emission_energy_multiplier = 2.0
	visual.material_override = mat
	add_child(visual)
