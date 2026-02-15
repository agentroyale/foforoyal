class_name PlayerInventory
extends Node
## Player inventory: hotbar (6 slots) + main inventory (24 slots).

signal active_slot_changed(slot_index: int)
signal item_added(item: ItemData, count: int)

const HOTBAR_SIZE := 6
const MAIN_SIZE := 24

var hotbar: Inventory
var main_inventory: Inventory
var active_hotbar_slot: int = 0


func _ready() -> void:
	hotbar = Inventory.new(HOTBAR_SIZE)
	main_inventory = Inventory.new(MAIN_SIZE)


func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().is_multiplayer_authority():
		return
	for i in range(HOTBAR_SIZE):
		var action := "hotbar_%d" % (i + 1)
		if event.is_action_pressed(action):
			set_active_slot(i)
			return


func set_active_slot(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE:
		return
	active_hotbar_slot = index
	active_slot_changed.emit(index)


func get_active_item() -> ItemData:
	var slot := hotbar.get_slot(active_hotbar_slot)
	if slot.is_empty():
		return null
	return slot["item"]


func get_active_tool() -> ToolData:
	var item := get_active_item()
	if item is ToolData:
		return item as ToolData
	return null


func add_item_to_inventory(item: ItemData, count: int = 1) -> int:
	## Tries hotbar first, then main. Returns overflow.
	var remaining := hotbar.add_item(item, count)
	if remaining > 0:
		remaining = main_inventory.add_item(item, remaining)
	if remaining < count:
		item_added.emit(item, count - remaining)
	return remaining


func has_item(item: ItemData, count: int = 1) -> bool:
	var total := hotbar.get_item_count(item) + main_inventory.get_item_count(item)
	return total >= count


func remove_item(item: ItemData, count: int = 1) -> int:
	## Removes from main first, then hotbar. Returns amount removed.
	var removed := main_inventory.remove_item(item, count)
	if removed < count:
		removed += hotbar.remove_item(item, count - removed)
	return removed
