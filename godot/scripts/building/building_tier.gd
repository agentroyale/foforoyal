class_name BuildingTier
extends RefCounted
## Tier definitions for the building system.
## 5 tiers: Twig, Wood, Stone, Metal, Armored.

enum Tier {
	TWIG = 0,
	WOOD = 1,
	STONE = 2,
	METAL = 3,
	ARMORED = 4,
}

const TIER_NAMES: PackedStringArray = ["Twig", "Wood", "Stone", "Metal", "Armored"]
const TIER_HP: PackedInt32Array = [10, 250, 500, 1000, 2000]

const TIER_COLORS: Array[Color] = [
	Color(0.55, 0.45, 0.25),   # Twig
	Color(0.65, 0.50, 0.30),   # Wood
	Color(0.60, 0.60, 0.60),   # Stone
	Color(0.45, 0.45, 0.50),   # Metal
	Color(0.75, 0.75, 0.78),   # Armored
]

const SHADER_PATHS: Array[String] = [
	"res://shaders/building_twig.gdshader",
	"res://shaders/building_wood.gdshader",
	"res://shaders/building_stone.gdshader",
	"res://shaders/building_metal.gdshader",
	"res://shaders/building_armored.gdshader",
]

static var _material_cache: Dictionary = {}


static func get_tier_name(tier: Tier) -> String:
	return TIER_NAMES[tier]


static func get_max_hp(tier: Tier) -> int:
	return TIER_HP[tier]


static func get_color(tier: Tier) -> Color:
	return TIER_COLORS[tier]


static func get_material(tier: Tier) -> Material:
	if _material_cache.has(tier):
		return _material_cache[tier]

	var shader_path: String = SHADER_PATHS[tier]
	if shader_path.is_empty() or not ResourceLoader.exists(shader_path):
		# Fallback: plain color material
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TIER_COLORS[tier]
		_material_cache[tier] = mat
		return mat

	var shader := load(shader_path) as Shader
	if not shader:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TIER_COLORS[tier]
		_material_cache[tier] = mat
		return mat

	var mat := ShaderMaterial.new()
	mat.shader = shader
	_material_cache[tier] = mat
	return mat


static func get_next_tier(tier: Tier) -> Tier:
	if tier < Tier.ARMORED:
		return (tier + 1) as Tier
	return tier


static func is_max_tier(tier: Tier) -> bool:
	return tier == Tier.ARMORED
