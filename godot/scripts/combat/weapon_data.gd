class_name WeaponData
extends ItemData
## Data resource for combat weapons.

enum WeaponType { MELEE = 0, BOW = 1, PISTOL = 2, SMG = 3 }
enum AmmoType { NONE = 0, ARROW = 1, PISTOL_AMMO = 2, RIFLE_AMMO = 3 }

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
