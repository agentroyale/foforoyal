class_name ShellEject
extends Node3D
## Ejected brass shell casing with simple arc trajectory and spin.
## Spawned to the right of the weapon on each shot. Self-destructs.

const LIFETIME := 1.8
const GRAVITY := 9.8
const CASING_LENGTH := 0.018
const CASING_RADIUS := 0.004

var _timer := LIFETIME
var _velocity: Vector3
var _spin: Vector3
var _mesh: MeshInstance3D
var _pos: Vector3
var _pending := false


static func create(muzzle_pos: Vector3, right: Vector3, up: Vector3) -> ShellEject:
	var shell := ShellEject.new()

	# Eject to the right, slightly up and back
	var eject_dir := (right * 1.0 + up * 0.6 + right.cross(up).normalized() * -0.2).normalized()
	var speed := randf_range(2.0, 3.5)
	shell._velocity = eject_dir * speed
	shell._spin = Vector3(randf_range(-15.0, 15.0), randf_range(-10.0, 10.0), randf_range(-15.0, 15.0))
	shell._pos = muzzle_pos + right * 0.08
	shell._pending = true

	# Brass casing mesh (small cylinder)
	var cyl := CylinderMesh.new()
	cyl.top_radius = CASING_RADIUS
	cyl.bottom_radius = CASING_RADIUS * 1.2
	cyl.height = CASING_LENGTH

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.7, 0.25, 1.0)
	mat.metallic = 0.9
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.5, 0.15)
	mat.emission_energy_multiplier = 1.5
	cyl.material = mat

	shell._mesh = MeshInstance3D.new()
	shell._mesh.mesh = cyl
	shell._mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.add_child(shell._mesh)

	return shell


func _process(delta: float) -> void:
	if _pending and is_inside_tree():
		_pending = false
		global_position = _pos

	# Physics
	_velocity.y -= GRAVITY * delta
	global_position += _velocity * delta

	# Spin
	rotation += _spin * delta

	# Fade out near end of life
	_timer -= delta
	if _timer < 0.3 and _mesh and _mesh.mesh:
		var mat := _mesh.mesh.material as StandardMaterial3D
		if mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = _timer / 0.3

	if _timer <= 0.0:
		queue_free()
