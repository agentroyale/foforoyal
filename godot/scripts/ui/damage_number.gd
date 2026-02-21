class_name DamageNumber
extends Label3D
## Floating damage number that rises and fades out. queue_free automatico.

const RISE_SPEED := 2.0
const LIFETIME := 0.8
const RANDOM_OFFSET := 0.3

var _timer := 0.0


static func create(damage: float, world_pos: Vector3, hitzone: int) -> DamageNumber:
	var dn := DamageNumber.new()
	dn.text = str(int(roundf(damage)))
	dn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dn.no_depth_test = true
	dn.fixed_size = true
	dn.pixel_size = 0.005

	match hitzone:
		HitzoneSystem.Hitzone.HEAD:
			dn.modulate = Color(1.0, 0.2, 0.2)
			dn.font_size = 64
		HitzoneSystem.Hitzone.CHEST:
			dn.modulate = Color(1.0, 1.0, 1.0)
			dn.font_size = 48
		_:
			dn.modulate = Color(0.7, 0.7, 0.7)
			dn.font_size = 48

	var offset := Vector3(
		randf_range(-RANDOM_OFFSET, RANDOM_OFFSET),
		0.0,
		randf_range(-RANDOM_OFFSET, RANDOM_OFFSET)
	)
	dn.position = world_pos + offset
	return dn


func _process(delta: float) -> void:
	_timer += delta
	position.y += RISE_SPEED * delta
	var alpha := 1.0 - (_timer / LIFETIME)
	modulate.a = maxf(alpha, 0.0)
	if _timer >= LIFETIME:
		queue_free()
