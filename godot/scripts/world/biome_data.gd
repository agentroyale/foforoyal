class_name BiomeData
extends Resource
## Defines biome properties: resource densities, colors, climate ranges.

enum BiomeType {
	GRASSLAND = 0,
	FOREST = 1,
	DESERT = 2,
	ARCTIC = 3,
}

@export var biome_type: BiomeType = BiomeType.GRASSLAND
@export var biome_name: String = ""
@export var ground_color: Color = Color.WHITE
@export var tree_density: float = 0.0
@export var rock_density: float = 0.0
@export var metal_ore_density: float = 0.0
@export var sulfur_ore_density: float = 0.0
@export var temperature_range: Vector2 = Vector2(0, 1)
@export var moisture_range: Vector2 = Vector2(0, 1)


static func get_biome_from_climate(temperature: float, moisture: float) -> BiomeType:
	## temperature and moisture are normalized 0-1.
	## Arctic: cold (temp < 0.25)
	## Desert: hot + dry (temp > 0.6, moisture < 0.35)
	## Forest: wet (moisture > 0.55)
	## Grassland: everything else
	if temperature < 0.25:
		return BiomeType.ARCTIC
	if temperature > 0.6 and moisture < 0.35:
		return BiomeType.DESERT
	if moisture > 0.55:
		return BiomeType.FOREST
	return BiomeType.GRASSLAND


static func get_density_for_type(biome: BiomeType, node_type: int) -> float:
	## Returns spawn density for a ResourceNode.NodeType in a given biome.
	## node_type: 0=TREE, 1=ROCK, 2=METAL_ORE, 3=SULFUR_ORE
	match biome:
		BiomeType.GRASSLAND:
			return [0.3, 0.2, 0.05, 0.03][node_type]
		BiomeType.FOREST:
			return [0.6, 0.15, 0.08, 0.02][node_type]
		BiomeType.DESERT:
			return [0.05, 0.35, 0.1, 0.08][node_type]
		BiomeType.ARCTIC:
			return [0.1, 0.25, 0.12, 0.05][node_type]
	return 0.0
