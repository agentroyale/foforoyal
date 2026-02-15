class_name BulletTracer
extends Node3D
## Quick tracer line from origin to hit point using a thin box mesh stretched between points.

const LIFETIME := 0.1
const TRACER_COLOR := Color(1.0, 0.9, 0.5, 0.9)
const TRACER_WIDTH := 0.02

var _timer := LIFETIME
var _mesh: MeshInstance3D


## Store target coords to apply when in tree (global_position fails outside tree).
var _from: Vector3
var _to: Vector3
var _pending_transform := false


static func create(from: Vector3, to: Vector3) -> BulletTracer:
	var tracer := BulletTracer.new()
	var dist := from.distance_to(to)
	if dist < 0.1:
		return tracer

	tracer._from = from
	tracer._to = to
	tracer._pending_transform = true

	var box := BoxMesh.new()
	box.size = Vector3(TRACER_WIDTH, TRACER_WIDTH, dist)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = TRACER_COLOR
	mat.emission_enabled = true
	mat.emission = TRACER_COLOR
	mat.emission_energy_multiplier = 5.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	box.material = mat

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = box
	tracer.add_child(mesh_inst)
	tracer._mesh = mesh_inst

	return tracer


func _process(delta: float) -> void:
	if _pending_transform and is_inside_tree():
		_pending_transform = false
		var mid := (_from + _to) * 0.5
		global_position = mid
		look_at_from_position(mid, _to, Vector3.UP)

	_timer -= delta
	if _timer <= 0.0:
		queue_free()
		return
	var alpha := _timer / LIFETIME
	if _mesh and _mesh.mesh:
		var mat := _mesh.mesh.material as StandardMaterial3D
		if mat:
			mat.albedo_color.a = alpha
