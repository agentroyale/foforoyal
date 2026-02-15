class_name LootTable
extends Resource
## Weighted random loot table for ground item spawns.

@export var entries: Array[Dictionary] = []
## Each entry: { "item": ItemData, "weight": float, "min_count": int, "max_count": int }


static func roll(table: LootTable, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	## Returns Array of { "item": ItemData, "count": int }.
	if not table or table.entries.is_empty():
		return []
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var total_weight := 0.0
	for entry in table.entries:
		total_weight += entry.get("weight", 1.0)
	if total_weight <= 0.0:
		return []
	var roll_val := rng.randf_range(0.0, total_weight)
	var cumulative := 0.0
	for entry in table.entries:
		cumulative += entry.get("weight", 1.0)
		if roll_val <= cumulative:
			var min_c: int = entry.get("min_count", 1)
			var max_c: int = entry.get("max_count", 1)
			var count := rng.randi_range(min_c, max_c)
			return [{ "item": entry["item"], "count": count }]
	# Fallback: last entry
	var last: Dictionary = table.entries.back()
	return [{ "item": last["item"], "count": last.get("min_count", 1) }]
