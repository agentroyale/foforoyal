extends SceneTree

func _init() -> void:
	var scene := load("res://assets/kaykit/adventurers/Barbarian.glb") as PackedScene
	if not scene:
		print("FAILED to load Barbarian.glb")
		quit()
		return
	var inst := scene.instantiate()
	_print_tree(inst, 0)
	inst.free()
	quit()

func _print_tree(node: Node, depth: int) -> void:
	var indent := ""
	for i in range(depth):
		indent += "  "
	print("%s%s [%s]" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, depth + 1)
