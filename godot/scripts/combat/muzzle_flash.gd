class_name MuzzleFlash
extends Node3D
## Muzzle flash VFX: bright flash + spark particles + point light.
## Spawned at muzzle position each shot. Self-destructs after particles finish.

const TOTAL_LIFETIME := 0.4
const FLASH_DURATION := 0.04
const LIGHT_FADE_TIME := 0.08
const SPARK_COUNT := 14
const SPARK_LIFETIME := 0.18
const FLASH_SIZE := 0.25
const LIGHT_ENERGY := 5.0
const LIGHT_RANGE := 4.5

var _timer := TOTAL_LIFETIME
var _flash_mesh: MeshInstance3D
var _light: OmniLight3D
var _pos: Vector3
var _dir: Vector3
var _pending := false


static func create(pos: Vector3, dir: Vector3) -> MuzzleFlash:
	var flash := MuzzleFlash.new()
	flash._pos = pos
	flash._dir = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
	flash._pending = true

	# ── Flash billboard (bright burst) ──
	var quad := QuadMesh.new()
	quad.size = Vector2(FLASH_SIZE, FLASH_SIZE)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_mat.albedo_color = Color(1.0, 0.95, 0.8, 0.95)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.9, 0.6)
	flash_mat.emission_energy_multiplier = 15.0
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.no_depth_test = true
	quad.material = flash_mat

	flash._flash_mesh = MeshInstance3D.new()
	flash._flash_mesh.mesh = quad
	flash._flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.add_child(flash._flash_mesh)

	# Second flash rotated 45 deg for star shape
	var flash_mesh2 := MeshInstance3D.new()
	var quad2 := QuadMesh.new()
	quad2.size = Vector2(FLASH_SIZE * 0.7, FLASH_SIZE * 0.7)
	quad2.material = flash_mat
	flash_mesh2.mesh = quad2
	flash_mesh2.rotation.z = PI / 4.0
	flash_mesh2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash._flash_mesh.add_child(flash_mesh2)

	# ── Spark particles ──
	var particles := GPUParticles3D.new()
	particles.amount = SPARK_COUNT
	particles.lifetime = SPARK_LIFETIME
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.randomness = 0.2
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.015
	pmat.direction = Vector3(0, 0, -1)  # Forward (oriented by node transform)
	pmat.spread = 25.0
	pmat.initial_velocity_min = 6.0
	pmat.initial_velocity_max = 14.0
	pmat.gravity = Vector3(0, -7.0, 0)
	pmat.damping_min = 3.0
	pmat.damping_max = 6.0
	pmat.scale_min = 0.5
	pmat.scale_max = 1.2
	pmat.angle_min = 0.0
	pmat.angle_max = 360.0

	# Color ramp: white-hot -> orange -> fade
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.97, 0.85, 1.0),
		Color(1.0, 0.75, 0.3, 0.95),
		Color(1.0, 0.45, 0.1, 0.7),
		Color(0.3, 0.1, 0.0, 0.0),
	])
	var gradient := GradientTexture1D.new()
	gradient.gradient = g
	pmat.color_ramp = gradient

	particles.process_material = pmat

	# Spark mesh (small elongated sphere for streak look)
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.006
	spark_mesh.height = 0.02
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.85, 0.5)
	spark_mat.emission_energy_multiplier = 10.0
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.vertex_color_use_as_albedo = true
	spark_mesh.material = spark_mat
	particles.draw_pass_1 = spark_mesh

	flash.add_child(particles)

	# ── Point light (brief illumination) ──
	flash._light = OmniLight3D.new()
	flash._light.light_color = Color(1.0, 0.85, 0.5)
	flash._light.light_energy = LIGHT_ENERGY
	flash._light.omni_range = LIGHT_RANGE
	flash._light.omni_attenuation = 2.0
	flash._light.shadow_enabled = false
	flash.add_child(flash._light)

	return flash


func _process(delta: float) -> void:
	if _pending and is_inside_tree():
		_pending = false
		global_position = _pos
		# Orient so particles emit in fire direction (-Z is forward)
		look_at_from_position(_pos, _pos + _dir, Vector3.UP)

	_timer -= delta

	# Flash disappears after FLASH_DURATION
	if _flash_mesh and _flash_mesh.visible and _timer < TOTAL_LIFETIME - FLASH_DURATION:
		_flash_mesh.visible = false

	# Light fades out quickly
	if _light:
		var light_t := clampf(_timer / LIGHT_FADE_TIME, 0.0, 1.0)
		_light.light_energy = LIGHT_ENERGY * light_t * light_t

	if _timer <= 0.0:
		queue_free()
