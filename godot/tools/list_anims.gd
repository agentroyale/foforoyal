extends SceneTree

func _init() -> void:
	var files := [
		"res://assets/kaykit/adventurers/Rig_Medium_CombatRanged.glb",
		"res://assets/kaykit/adventurers/Rig_Medium_CombatMelee.glb",
		"res://assets/kaykit/adventurers/Rig_Medium_Special.glb",
		"res://assets/kaykit/adventurers/Rig_Medium_Tools.glb",
		"res://assets/kaykit/adventurers/Rig_Medium_Simulation.glb",
		"res://assets/kaykit/adventurers/Rig_Medium_MovementAdvanced.glb",
		"res://assets/kaykit/adventurers/Rig_Medium_General.glb",
		"res://assets/kaykit/adventurers/Rig_Medium_MovementBasic.glb",
	]
	for f in files:
		print("\n=== %s ===" % f.get_file())
		var scene := load(f) as PackedScene
		if not scene:
			print("  FAILED TO LOAD")
			continue
		var inst := scene.instantiate()
		_find_anims(inst)
		inst.free()
	quit()

func _find_anims(node: Node) -> void:
	if node is AnimationPlayer:
		var ap := node as AnimationPlayer
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				var anim := lib.get_animation(anim_name)
				print("  [%s] %s  (%.1fs)" % [lib_name, anim_name, anim.length])
	for child in node.get_children():
		_find_anims(child)
