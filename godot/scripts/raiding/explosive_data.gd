class_name ExplosiveData
extends ItemData
## Data resource for explosive items (C4, satchel, rocket).

enum ExplosiveType { C4 = 0, SATCHEL = 1, ROCKET = 2 }

@export var explosive_type: ExplosiveType = ExplosiveType.C4
@export var base_damage: float = 275.0
@export var explosion_radius: float = 4.0
@export var fuse_time: float = 10.0
@export var dud_chance: float = 0.0
@export var is_thrown: bool = true
@export var projectile_speed: float = 0.0
