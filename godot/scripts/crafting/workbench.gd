class_name Workbench
extends StaticBody3D
## Interactable workbench with crafting tier and proximity-based queue pausing.

signal player_opened(workbench: Workbench)
signal player_closed(workbench: Workbench)

@export var tier: RecipeData.WorkbenchTier = RecipeData.WorkbenchTier.WORKBENCH_T1
@export var interaction_radius: float = 3.0

var crafting_queue: CraftingQueue = null
var active_player: Node3D = null


func _ready() -> void:
	add_to_group("workbenches")
	crafting_queue = CraftingQueue.new()
	crafting_queue.available_tier = tier
	crafting_queue.name = "CraftingQueue"
	add_child(crafting_queue)


func _process(_delta: float) -> void:
	if active_player and crafting_queue:
		var dist := global_position.distance_to(active_player.global_position)
		if dist > interaction_radius:
			crafting_queue.pause()
		else:
			crafting_queue.resume()


func interact(player: Node3D) -> void:
	active_player = player
	var player_inv := player.get_node_or_null("PlayerInventory") as PlayerInventory
	if player_inv:
		crafting_queue.player_inventory = player_inv
	crafting_queue.resume()
	player_opened.emit(self)


func close(player: Node3D) -> void:
	if active_player == player:
		active_player = null
		player_closed.emit(self)
