class_name ImpactEffect
extends Node3D
## Impact VFX at bullet hit point: sparks + dust puff + brief light.
## Sparks fly along the surface normal. Self-destructs.

const TOTAL_LIFETIME := 0.6
const SPARK_COUNT := 10
const SPARK_LIFETIME := 0.2
const DUST_COUNT := 6
const DUST_LIFETIME := 0.35
const LIGHT_ENERGY := 2.0
const LIGHT_RANGE := 2.0

var _timer := TOTAL_LIFETIME
var _light: OmniLight3D
var _pos: Vector3
var _normal: Vector3
var _pending := false


static func create(pos: Vector3, normal: Vector3) -> ImpactEffect:
	var effect := ImpactEffect.new()
	effect._pos = pos + normal * 0.02  # Offset slightly off surface
	effect._normal = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	effect._pending = true

	# ── Spark particles (bright, fast, bounce off surface) ──
	var sparks := GPUParticles3D.new()
	sparks.amount = SPARK_COUNT
	sparks.lifetime = SPARK_LIFETIME
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.randomness = 0.3
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var spark_pmat := ParticleProcessMaterial.new()
	spark_pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spark_pmat.emission_sphere_radius = 0.01
	spark_pmat.direction = Vector3(0, 1, 0)  # Will be oriented by node transform
	spark_pmat.spread = 55.0
	spark_pmat.initial_velocity_min = 3.0
	spark_pmat.initial_velocity_max = 10.0
	spark_pmat.gravity = Vector3(0, -12.0, 0)
	spark_pmat.damping_min = 2.0
	spark_pmat.damping_max = 4.0
	spark_pmat.scale_min = 0.4
	spark_pmat.scale_max = 1.0

	# Color: bright yellow -> orange -> gone
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.95, 0.7, 1.0),
		Color(1.0, 0.7, 0.25, 0.9),
		Color(0.8, 0.35, 0.05, 0.5),
		Color(0.2, 0.05, 0.0, 0.0),
	])
	var gradient := GradientTexture1D.new()
	gradient.gradient = g
	spark_pmat.color_ramp = gradient

	sparks.process_material = spark_pmat

	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.005
	spark_mesh.height = 0.015
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.8, 0.4)
	spark_mat.emission_energy_multiplier = 8.0
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.vertex_color_use_as_albedo = true
	spark_mesh.material = spark_mat
	sparks.draw_pass_1 = spark_mesh

	effect.add_child(sparks)

	# ── Dust puff (slow, grey, larger) ──
	var dust := GPUParticles3D.new()
	dust.amount = DUST_COUNT
	dust.lifetime = DUST_LIFETIME
	dust.one_shot = true
	dust.explosiveness = 0.8
	dust.randomness = 0.5
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var dust_pmat := ParticleProcessMaterial.new()
	dust_pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	dust_pmat.emission_sphere_radius = 0.03
	dust_pmat.direction = Vector3(0, 1, 0)
	dust_pmat.spread = 70.0
	dust_pmat.initial_velocity_min = 0.5
	dust_pmat.initial_velocity_max = 2.0
	dust_pmat.gravity = Vector3(0, -1.0, 0)
	dust_pmat.damping_min = 5.0
	dust_pmat.damping_max = 8.0
	dust_pmat.scale_min = 1.0
	dust_pmat.scale_max = 3.0

	# Color: grey -> fade
	var dg := Gradient.new()
	dg.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	dg.colors = PackedColorArray([
		Color(0.6, 0.55, 0.5, 0.4),
		Color(0.5, 0.45, 0.4, 0.25),
		Color(0.4, 0.35, 0.3, 0.0),
	])
	var dust_gradient := GradientTexture1D.new()
	dust_gradient.gradient = dg
	dust_pmat.color_ramp = dust_gradient

	dust.process_material = dust_pmat

	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.02
	dust_mesh.height = 0.04
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.vertex_color_use_as_albedo = true
	dust_mesh.material = dust_mat
	dust.draw_pass_1 = dust_mesh

	effect.add_child(dust)

	# ── Brief point light ──
	effect._light = OmniLight3D.new()
	effect._light.light_color = Color(1.0, 0.8, 0.4)
	effect._light.light_energy = LIGHT_ENERGY
	effect._light.omni_range = LIGHT_RANGE
	effect._light.omni_attenuation = 2.0
	effect._light.shadow_enabled = false
	effect.add_child(effect._light)

	return effect


func _process(delta: float) -> void:
	if _pending and is_inside_tree():
		_pending = false
		global_position = _pos
		# Orient so +Y points along the surface normal (sparks/dust emit upward)
		if _normal != Vector3.UP and _normal != Vector3.DOWN:
			look_at_from_position(_pos, _pos + _normal, Vector3.UP)
			rotate_object_local(Vector3.RIGHT, -PI / 2.0)
		elif _normal == Vector3.DOWN:
			rotation.x = PI

	_timer -= delta

	# Light fades quickly
	if _light:
		var t := clampf(_timer / 0.06, 0.0, 1.0)
		_light.light_energy = LIGHT_ENERGY * t

	if _timer <= 0.0:
		queue_free()
