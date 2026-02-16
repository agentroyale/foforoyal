class_name CityGenerator
extends RefCounted
## Generates a procedural city layout: grid of roads, buildings, cars, and props.
## All static methods — deterministic from seed.

# Grid constants (meters)
const CITY_SCALE := 5.0         # KayKit models are ~2 units, scale up to ~10m
const TILE_SIZE := 10.0         # 2 units * CITY_SCALE = 10m per road tile
const BLOCK_TILES := 2          # 2x2 tiles = 20x20m per city block (tight grid)
const ROAD_TILES := 1           # 1 tile = 10m road between blocks
const PERIOD := 30.0            # 20m block + 10m road
const GRID_HALF := 14           # 29x29 grid → ~870m of city, denser

# Density zones (distance from map center)
const DENSE_RADIUS := 300.0
const MEDIUM_RADIUS := 400.0

# Asset paths
const CITY_ASSET_PATH := "res://assets/kaykit/city/"

const BUILDING_NAMES: Array[String] = [
	"building_A", "building_B", "building_C", "building_D",
	"building_E", "building_F", "building_G", "building_H",
]

const CAR_NAMES: Array[String] = [
	"car_sedan", "car_hatchback", "car_stationwagon", "car_taxi", "car_police",
]

const PROP_NAMES: Array[String] = [
	"bench", "streetlight", "trafficlight_A", "firehydrant",
	"dumpster", "trash_A", "trash_B", "box_A", "box_B",
]

# Road tile types
enum RoadType { STRAIGHT, JUNCTION, TSPLIT, CORNER }


static func generate_layout(seed_val: int, map_size: int) -> Dictionary:
	## Generates the full city layout. Returns a dict with "roads", "buildings", "cars", "props".
	## Each entry is an Array of Dictionaries with "scene", "position", "rotation_y".
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 7777

	var center := float(map_size) / 2.0
	var roads: Array[Dictionary] = []
	var buildings: Array[Dictionary] = []
	var cars: Array[Dictionary] = []
	var props: Array[Dictionary] = []

	# Grid layout (along one axis):
	#   I---S---S---S---S---I---S---S---S---S---I
	#   |       Block       |       Block       |
	# I = intersection, S = straight road tile
	# Distance between intersections = PERIOD = BLOCK_TILES * TILE_SIZE + ROAD_TILES * TILE_SIZE
	# Straights between two intersections = BLOCK_TILES (fills the block gap)
	#
	# Intersections indexed 0..NUM_INTERSECTIONS-1 on each axis.
	# Blocks sit between consecutive intersections.

	var num_intersections := GRID_HALF * 2 + 1  # 17
	var num_blocks := num_intersections - 1  # 16
	var grid_origin_x := center - float(num_blocks) / 2.0 * PERIOD
	var grid_origin_z := grid_origin_x
	var tiles_between := int(PERIOD / TILE_SIZE) - 1  # 4 straight tiles between intersections

	# --- Roads ---
	for iz in num_intersections:
		for ix in num_intersections:
			var ipos_x := grid_origin_x + ix * PERIOD
			var ipos_z := grid_origin_z + iz * PERIOD
			if ipos_x < 0.0 or ipos_x > map_size or ipos_z < 0.0 or ipos_z > map_size:
				continue

			var is_x_edge := (ix == 0 or ix == num_intersections - 1)
			var is_z_edge := (iz == 0 or iz == num_intersections - 1)

			# All intersections use road_junction (4-way) — simplest, always works
			roads.append({
				"scene": "road_junction",
				"position": Vector3(ipos_x, 0.0, ipos_z),
				"rotation_y": 0.0,
			})

			# Straight tiles toward next intersection along X
			# KayKit road_straight runs along Z by default, so rotate PI/2 for X-axis
			if ix < num_intersections - 1:
				for t in range(1, tiles_between + 1):
					var sx := ipos_x + t * TILE_SIZE
					if sx > 0.0 and sx < map_size:
						roads.append({
							"scene": "road_straight",
							"position": Vector3(sx, 0.0, ipos_z),
							"rotation_y": PI * 0.5,
						})

			# Straight tiles toward next intersection along Z
			# Default orientation — no rotation needed
			if iz < num_intersections - 1:
				for t in range(1, tiles_between + 1):
					var sz := ipos_z + t * TILE_SIZE
					if sz > 0.0 and sz < map_size:
						roads.append({
							"scene": "road_straight",
							"position": Vector3(ipos_x, 0.0, sz),
							"rotation_y": 0.0,
						})

	# --- Buildings, cars, props per block ---
	# Block (bx, bz) sits between intersection (bx, bz) and (bx+1, bz+1).
	# Block origin = intersection pos + TILE_SIZE (skip the road tile).
	var block_size := BLOCK_TILES * TILE_SIZE  # 40m

	for bz in num_blocks:
		for bx in num_blocks:
			var block_origin_x := grid_origin_x + bx * PERIOD + TILE_SIZE
			var block_origin_z := grid_origin_z + bz * PERIOD + TILE_SIZE
			if block_origin_x < 0.0 or block_origin_x + block_size > map_size:
				continue
			if block_origin_z < 0.0 or block_origin_z + block_size > map_size:
				continue

			var block_center_x := block_origin_x + block_size * 0.5
			var block_center_z := block_origin_z + block_size * 0.5
			var dist := Vector2(block_center_x - center, block_center_z - center).length()

			# Buildings — placed in quadrant slots to avoid overlap
			# Slots: 4 quadrants of the 20x20m block (10x10m each)
			var building_count := _get_building_count(dist, rng)
			var slots: Array[Vector2] = [
				Vector2(0.25, 0.25), Vector2(0.75, 0.25),
				Vector2(0.25, 0.75), Vector2(0.75, 0.75),
			]
			# Fisher-Yates shuffle with deterministic rng
			for si in range(slots.size() - 1, 0, -1):
				var sj := rng.randi_range(0, si)
				var tmp := slots[si]
				slots[si] = slots[sj]
				slots[sj] = tmp
			for i in mini(building_count, slots.size()):
				var bname := BUILDING_NAMES[rng.randi() % BUILDING_NAMES.size()]
				var slot: Vector2 = slots[i]
				var px := block_origin_x + slot.x * block_size
				var pz := block_origin_z + slot.y * block_size
				var rot := float(rng.randi_range(0, 3)) * PI * 0.5
				buildings.append({
					"scene": bname,
					"position": Vector3(px, 0.0, pz),
					"rotation_y": rot,
				})

			# Cars parked along roadside (just outside block edges)
			if dist < MEDIUM_RADIUS:
				var car_count := rng.randi_range(2, 4) if dist < DENSE_RADIUS else rng.randi_range(1, 2)
				for i in car_count:
					var cname := CAR_NAMES[rng.randi() % CAR_NAMES.size()]
					var edge := rng.randi_range(0, 3)
					var cx: float
					var cz: float
					var crot: float
					match edge:
						0:  # North
							cx = block_origin_x + rng.randf_range(5.0, block_size - 5.0)
							cz = block_origin_z - 3.0
							crot = 0.0
						1:  # South
							cx = block_origin_x + rng.randf_range(5.0, block_size - 5.0)
							cz = block_origin_z + block_size + 3.0
							crot = PI
						2:  # West
							cx = block_origin_x - 3.0
							cz = block_origin_z + rng.randf_range(5.0, block_size - 5.0)
							crot = PI * 0.5
						_:  # East
							cx = block_origin_x + block_size + 3.0
							cz = block_origin_z + rng.randf_range(5.0, block_size - 5.0)
							crot = PI * 1.5
					if cx > 0.0 and cx < map_size and cz > 0.0 and cz < map_size:
						cars.append({
							"scene": cname,
							"position": Vector3(cx, 0.0, cz),
							"rotation_y": crot,
						})

			# Props on sidewalks
			if dist < MEDIUM_RADIUS:
				var prop_count := rng.randi_range(4, 8) if dist < DENSE_RADIUS else rng.randi_range(2, 4)
				for i in prop_count:
					var pname := PROP_NAMES[rng.randi() % PROP_NAMES.size()]
					var side := rng.randi_range(0, 3)
					var px: float
					var pz: float
					match side:
						0:
							px = block_origin_x + rng.randf_range(0.0, block_size)
							pz = block_origin_z - 2.0
						1:
							px = block_origin_x + rng.randf_range(0.0, block_size)
							pz = block_origin_z + block_size + 2.0
						2:
							px = block_origin_x - 2.0
							pz = block_origin_z + rng.randf_range(0.0, block_size)
						_:
							px = block_origin_x + block_size + 2.0
							pz = block_origin_z + rng.randf_range(0.0, block_size)
					if px > 0.0 and px < map_size and pz > 0.0 and pz < map_size:
						props.append({
							"scene": pname,
							"position": Vector3(px, 0.0, pz),
							"rotation_y": rng.randf_range(0.0, TAU),
						})

	return {
		"roads": roads,
		"buildings": buildings,
		"cars": cars,
		"props": props,
	}


static func get_elements_in_chunk(layout: Dictionary, cx: int, cz: int) -> Dictionary:
	## Filters layout elements that fall within chunk (cx, cz). Chunk is 256x256m.
	var chunk_size := 256.0
	var min_x := cx * chunk_size
	var max_x := min_x + chunk_size
	var min_z := cz * chunk_size
	var max_z := min_z + chunk_size

	var result := {
		"roads": [] as Array[Dictionary],
		"buildings": [] as Array[Dictionary],
		"cars": [] as Array[Dictionary],
		"props": [] as Array[Dictionary],
	}

	for key in ["roads", "buildings", "cars", "props"]:
		var arr: Array = layout[key]
		for elem in arr:
			var pos: Vector3 = elem["position"]
			if pos.x >= min_x and pos.x < max_x and pos.z >= min_z and pos.z < max_z:
				result[key].append(elem)

	return result


static func get_scene_path(scene_name: String) -> String:
	return CITY_ASSET_PATH + scene_name + ".gltf"


static func _get_building_count(dist: float, rng: RandomNumberGenerator) -> int:
	if dist < DENSE_RADIUS:
		return rng.randi_range(2, 3)
	elif dist < MEDIUM_RADIUS:
		return rng.randi_range(1, 2)
	else:
		return 1 if rng.randf() < 0.5 else 0
