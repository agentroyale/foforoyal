class_name ArmorData
extends ItemData
## Data resource for armor pieces.

enum ArmorSlot { HEAD = 0, CHEST = 1, LEGS = 2 }

@export var armor_slot: ArmorSlot = ArmorSlot.CHEST
@export var protection_melee: float = 0.0
@export var protection_bullet: float = 0.0
@export var protection_explosive: float = 0.0
@export var max_durability: int = 100


func get_protection(damage_type: int) -> float:
	## Pass HealthSystem.DamageType int value.
	match damage_type:
		0:  # MELEE
			return protection_melee
		1:  # BULLET
			return protection_bullet
		2:  # EXPLOSIVE
			return protection_explosive
		_:  # FALL and others
			return 0.0
