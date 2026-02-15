class_name BulletTracer
extends Node3D
## Hitscan tracer line: bright core + wider glow, fades quickly.
## Stretched between muzzle and hit point.

const LIFETIME := 0.08
const CORE_WIDTH := 0.012
const GLOW_WIDTH := 0.05
const CORE_COLOR := Color(1.0, 0.97, 0.85, 1.0)
const GLOW_COLOR := Color(1.0, 0.75, 0.3, 0.35)

var _timer := LIFETIME
var _core_mesh: MeshInstance3D
var _glow_mesh: MeshInstance3D

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

	# ── Core (thin, bright white-yellow) ──
	var core_box := BoxMesh.new()
	core_box.size = Vector3(CORE_WIDTH, CORE_WIDTH, dist)

	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = CORE_COLOR
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.95, 0.75)
	core_mat.emission_energy_multiplier = 12.0
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.no_depth_test = true
	core_box.material = core_mat

	tracer._core_mesh = MeshInstance3D.new()
	tracer._core_mesh.mesh = core_box
	tracer._core_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracer.add_child(tracer._core_mesh)

	# ── Glow (wider, softer, semi-transparent orange) ──
	var glow_box := BoxMesh.new()
	glow_box.size = Vector3(GLOW_WIDTH, GLOW_WIDTH, dist)

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = GLOW_COLOR
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.65, 0.2)
	glow_mat.emission_energy_multiplier = 4.0
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.no_depth_test = true
	glow_box.material = glow_mat

	tracer._glow_mesh = MeshInstance3D.new()
	tracer._glow_mesh.mesh = glow_box
	tracer._glow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracer.add_child(tracer._glow_mesh)

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
	# Core fades
	if _core_mesh and _core_mesh.mesh:
		var mat := _core_mesh.mesh.material as StandardMaterial3D
		if mat:
			mat.albedo_color.a = alpha
	# Glow fades faster
	if _glow_mesh and _glow_mesh.mesh:
		var mat := _glow_mesh.mesh.material as StandardMaterial3D
		if mat:
			mat.albedo_color.a = GLOW_COLOR.a * alpha * alpha
