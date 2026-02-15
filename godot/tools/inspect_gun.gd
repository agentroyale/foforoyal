extends SceneTree

func _init() -> void:
	var scene := load("res://assets/weapons/AssaultRifle_1.fbx") as PackedScene
	if not scene:
		print("FAILED to load")
		quit()
		return
	var inst := scene.instantiate()
	for child in inst.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var aabb := mi.get_aabb()
			print("Mesh AABB (local): pos=%s size=%s" % [aabb.position, aabb.size])
			print("Mesh AABB end: %s" % (aabb.position + aabb.size))
			# Apply MeshInstance transform to get parent-space AABB
			var t := mi.transform
			var corners := [
				aabb.position,
				aabb.position + Vector3(aabb.size.x, 0, 0),
				aabb.position + Vector3(0, aabb.size.y, 0),
				aabb.position + Vector3(0, 0, aabb.size.z),
				aabb.end,
			]
			print("\nCorners in parent space (after MeshInstance transform):")
			for c in corners:
				print("  %s -> %s" % [c, t * c])
			# The barrel tip is the +X max corner
			var barrel_tip_local := aabb.position + Vector3(aabb.size.x, aabb.size.y * 0.5, aabb.size.z * 0.5)
			var barrel_tip_parent := t * barrel_tip_local
			print("\nBarrel tip (mesh local): %s" % barrel_tip_local)
			print("Barrel tip (parent space): %s" % barrel_tip_parent)
			print("\nFor muzzle_offset in pivot space, use: %s" % barrel_tip_parent)
	inst.free()
	quit()
