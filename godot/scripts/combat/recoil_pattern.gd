class_name RecoilPattern
extends Resource
## Per-shot camera displacement pattern for weapons.

@export var offsets: Array[Vector2] = []  ## x=yaw, y=pitch in degrees
@export var recovery_speed: float = 5.0  ## Degrees/second camera recovers


func get_offset(shot_index: int) -> Vector2:
	if offsets.is_empty():
		return Vector2.ZERO
	return offsets[shot_index % offsets.size()]
