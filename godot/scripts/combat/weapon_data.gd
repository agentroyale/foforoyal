class_name WeaponData
extends ItemData
## Data resource for combat weapons.

enum WeaponType { MELEE = 0, BOW = 1, PISTOL = 2, SMG = 3, SHOTGUN = 4, SNIPER = 5, AR = 6 }
enum AmmoType { NONE = 0, ARROW = 1, PISTOL_AMMO = 2, RIFLE_AMMO = 3, SHOTGUN_AMMO = 4 }

@export var weapon_type: WeaponType = WeaponType.MELEE
@export var base_damage: float = 10.0
@export var fire_rate: float = 0.5
@export var reload_time: float = 0.0
@export var magazine_size: int = 0
@export var max_range: float = 0.0
@export var falloff_start: float = 0.0
@export var ammo_type: AmmoType = AmmoType.NONE
@export var recoil_pattern: RecoilPattern
@export var projectile_speed: float = 0.0
@export var projectile_gravity: float = 0.0
@export_group("Weapon Model")
@export var weapon_mesh_scene: PackedScene
@export var model_position_offset: Vector3 = Vector3.ZERO
@export var model_rotation_offset: Vector3 = Vector3.ZERO  ## degrees
@export var model_scale: float = 0.4
@export var muzzle_offset: Vector3 = Vector3(0, 0.04, -0.33)
@export_group("Spread/Bloom")
@export var base_spread: float = 0.5
@export var min_spread: float = 0.1
@export var bloom_per_shot: float = 0.8
@export var max_bloom: float = 5.0
@export var bloom_decay_rate: float = 8.0
