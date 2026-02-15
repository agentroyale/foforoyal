class_name Inventory
extends RefCounted
## Pure data inventory: array of slots with stacking, splitting, merging.
## No Node dependency — designed for easy unit testing.

signal slot_changed(slot_index: int)
signal inventory_changed()

## Each slot: { "item": ItemData, "count": int } or empty {}
var slots: Array[Dictionary] = []
var slot_count: int = 0


func _init(size: int = 6) -> void:
	slot_count = size
	slots.resize(size)
	for i in range(size):
		slots[i] = {}


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= slot_count:
		return {}
	return slots[index]


func is_slot_empty(index: int) -> bool:
	return slots[index].is_empty()


func add_item(item: ItemData, count: int = 1) -> int:
	## Adds items. Returns overflow count (items that didn't fit).
	var remaining := count

	# First: merge into existing stacks of the same item
	for i in range(slot_count):
		if remaining <= 0:
			break
		if not slots[i].is_empty() and slots[i]["item"] == item:
			var space: int = item.max_stack_size - slots[i]["count"]
			if space > 0:
				var to_add := mini(remaining, space)
				slots[i]["count"] += to_add
				remaining -= to_add
				slot_changed.emit(i)

	# Second: fill empty slots
	for i in range(slot_count):
		if remaining <= 0:
			break
		if slots[i].is_empty():
			var to_add := mini(remaining, item.max_stack_size)
			slots[i] = { "item": item, "count": to_add }
			remaining -= to_add
			slot_changed.emit(i)

	if remaining < count:
		inventory_changed.emit()
	return remaining


func remove_item(item: ItemData, count: int = 1) -> int:
	## Removes items (from end first). Returns amount actually removed.
	var to_remove := count
	var removed := 0

	for i in range(slot_count - 1, -1, -1):
		if to_remove <= 0:
			break
		if not slots[i].is_empty() and slots[i]["item"] == item:
			var available: int = slots[i]["count"]
			var taking := mini(to_remove, available)
			slots[i]["count"] -= taking
			to_remove -= taking
			removed += taking
			if slots[i]["count"] <= 0:
				slots[i] = {}
			slot_changed.emit(i)

	if removed > 0:
		inventory_changed.emit()
	return removed


func move_slot(from_index: int, to_index: int) -> bool:
	## Move/swap items between slots. Returns true on success.
	if from_index == to_index:
		return false
	if from_index < 0 or from_index >= slot_count:
		return false
	if to_index < 0 or to_index >= slot_count:
		return false
	if slots[from_index].is_empty():
		return false

	if slots[to_index].is_empty():
		slots[to_index] = slots[from_index]
		slots[from_index] = {}
	else:
		var temp := slots[to_index]
		slots[to_index] = slots[from_index]
		slots[from_index] = temp

	slot_changed.emit(from_index)
	slot_changed.emit(to_index)
	inventory_changed.emit()
	return true


func split_stack(slot_index: int, split_count: int = -1) -> int:
	## Splits a stack. Returns index of new stack, or -1 if failed.
	if slot_index < 0 or slot_index >= slot_count:
		return -1
	if slots[slot_index].is_empty():
		return -1

	var current_count: int = slots[slot_index]["count"]
	if current_count <= 1:
		return -1

	var amount: int = split_count if split_count > 0 else current_count / 2
	amount = mini(amount, current_count - 1)

	# Find empty slot
	var target_slot := -1
	for i in range(slot_count):
		if slots[i].is_empty():
			target_slot = i
			break

	if target_slot == -1:
		return -1

	slots[slot_index]["count"] -= amount
	slots[target_slot] = { "item": slots[slot_index]["item"], "count": amount }

	slot_changed.emit(slot_index)
	slot_changed.emit(target_slot)
	inventory_changed.emit()
	return target_slot


func merge_stacks(from_index: int, to_index: int) -> bool:
	## Merge from_index into to_index. Returns true if any items merged.
	if from_index == to_index:
		return false
	if slots[from_index].is_empty() or slots[to_index].is_empty():
		return false
	if slots[from_index]["item"] != slots[to_index]["item"]:
		return false

	var item: ItemData = slots[to_index]["item"]
	var space: int = item.max_stack_size - slots[to_index]["count"]
	if space <= 0:
		return false

	var to_move := mini(slots[from_index]["count"], space)
	slots[to_index]["count"] += to_move
	slots[from_index]["count"] -= to_move

	if slots[from_index]["count"] <= 0:
		slots[from_index] = {}

	slot_changed.emit(from_index)
	slot_changed.emit(to_index)
	inventory_changed.emit()
	return true


func get_item_count(item: ItemData) -> int:
	var total := 0
	for i in range(slot_count):
		if not slots[i].is_empty() and slots[i]["item"] == item:
			total += slots[i]["count"]
	return total


func has_item(item: ItemData, count: int = 1) -> bool:
	return get_item_count(item) >= count
