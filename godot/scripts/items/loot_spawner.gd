class_name LootSpawner
extends RefCounted
## Static helper for generating loot positions in chunks.
## Deterministic based on seed + chunk position.

const DENSITY_NORMAL := 3  # items per chunk in wilderness
const DENSITY_POI := 12  # items per chunk near POIs
const CHUNK_SIZE := 64.0


static func generate_loot_positions(chunk_x: int, chunk_z: int, seed_val: int, is_poi: bool = false) -> Array[Dictionary]:
	## Returns Array of { "position": Vector3, "table_tier": String }
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + chunk_x * 73856093 + chunk_z * 19349663
	var count := DENSITY_POI if is_poi else DENSITY_NORMAL
	var results: Array[Dictionary] = []
	for i in range(count):
		var x := chunk_x * CHUNK_SIZE + rng.randf_range(2.0, CHUNK_SIZE - 2.0)
		var z := chunk_z * CHUNK_SIZE + rng.randf_range(2.0, CHUNK_SIZE - 2.0)
		# Tier distribution: 60% common, 30% uncommon, 10% rare
		var tier_roll := rng.randf()
		var tier: String
		if tier_roll < 0.6:
			tier = "common"
		elif tier_roll < 0.9:
			tier = "uncommon"
		else:
			tier = "rare"
		results.append({
			"position": Vector3(x, 0.0, z),
			"table_tier": tier,
		})
	return results
