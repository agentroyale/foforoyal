class_name WeaponVisual
extends RefCounted
## Attaches a weapon mesh (3D model or primitive fallback) to a skeleton's handslot.r bone
## with a MuzzlePoint marker for projectile/hitscan origin.

const HAND_BONE := "handslot.r"

var _bone_attachment: BoneAttachment3D
var _muzzle_marker: Marker3D
var _pivot: Node3D  ## weapon model pivot (for adjust mode)


func setup(skeleton: Skeleton3D, weapon: WeaponData) -> void:
	clear()
	if not skeleton:
		push_warning("WeaponVisual: no skeleton")
		return

	var bone_idx := skeleton.find_bone(HAND_BONE)
	if bone_idx < 0:
		push_warning("WeaponVisual: bone '%s' not found" % HAND_BONE)
		return

	_bone_attachment = BoneAttachment3D.new()
	_bone_attachment.bone_name = HAND_BONE
	skeleton.add_child(_bone_attachment)

	if weapon.weapon_mesh_scene:
		_setup_from_scene(weapon)
	else:
		_setup_primitive(weapon)

	# Muzzle point — child of pivot so it follows the weapon model
	_muzzle_marker = Marker3D.new()
	_muzzle_marker.name = "MuzzlePoint"
	_muzzle_marker.position = weapon.muzzle_offset
	if _pivot:
		_pivot.add_child(_muzzle_marker)
	else:
		_bone_attachment.add_child(_muzzle_marker)


func _setup_from_scene(weapon: WeaponData) -> void:
	var inst := weapon.weapon_mesh_scene.instantiate() as Node3D
	if not inst:
		_setup_primitive(weapon)
		return
	_pivot = Node3D.new()
	_pivot.name = "WeaponPivot"
	_pivot.scale = Vector3.ONE * weapon.model_scale
	_pivot.position = weapon.model_position_offset
	_pivot.rotation_degrees = weapon.model_rotation_offset
	_pivot.add_child(inst)
	_bone_attachment.add_child(_pivot)


func _setup_primitive(weapon: WeaponData) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2)
	mat.metallic = 0.8
	mat.roughness = 0.3

	_pivot = Node3D.new()
	_pivot.name = "WeaponPivot"
	_pivot.position = weapon.model_position_offset
	_pivot.rotation_degrees = weapon.model_rotation_offset

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "WeaponMesh"

	match weapon.weapon_type:
		WeaponData.WeaponType.BOW:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.02
			cyl.bottom_radius = 0.02
			cyl.height = 0.8
			cyl.material = mat
			mesh_instance.mesh = cyl
			_pivot.add_child(mesh_instance)
		WeaponData.WeaponType.MELEE:
			var box := BoxMesh.new()
			box.size = Vector3(0.06, 0.06, 0.6)
			box.material = mat
			mesh_instance.mesh = box
			mesh_instance.position = Vector3(0, 0, -0.3)
			_pivot.add_child(mesh_instance)
		_:  # PISTOL, SMG — primitive gun shape
			var grip_mat := mat.duplicate() as StandardMaterial3D
			grip_mat.albedo_color = Color(0.15, 0.12, 0.1)
			var grip := BoxMesh.new()
			grip.size = Vector3(0.05, 0.12, 0.06)
			grip.material = grip_mat
			mesh_instance.mesh = grip
			mesh_instance.position = Vector3(0, -0.04, 0)
			_pivot.add_child(mesh_instance)

			var body_mesh := MeshInstance3D.new()
			body_mesh.name = "GunBody"
			var body := BoxMesh.new()
			body.size = Vector3(0.05, 0.06, 0.22)
			body.material = mat
			body_mesh.mesh = body
			body_mesh.position = Vector3(0, 0.04, -0.1)
			_pivot.add_child(body_mesh)

			var barrel_mesh := MeshInstance3D.new()
			barrel_mesh.name = "GunBarrel"
			var barrel := CylinderMesh.new()
			barrel.top_radius = 0.012
			barrel.bottom_radius = 0.012
			barrel.height = 0.12
			barrel.material = mat
			barrel_mesh.mesh = barrel
			barrel_mesh.rotation.x = PI / 2.0
			barrel_mesh.position = Vector3(0, 0.04, -0.27)
			_pivot.add_child(barrel_mesh)

	_bone_attachment.add_child(_pivot)


func clear() -> void:
	if _bone_attachment and is_instance_valid(_bone_attachment):
		_bone_attachment.queue_free()
	_bone_attachment = null
	_muzzle_marker = null
	_pivot = null


func get_muzzle_global_position() -> Vector3:
	if _muzzle_marker and is_instance_valid(_muzzle_marker):
		return _muzzle_marker.global_position
	return Vector3.ZERO


func get_pivot() -> Node3D:
	return _pivot
