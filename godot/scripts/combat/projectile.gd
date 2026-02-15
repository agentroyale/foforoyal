class_name Projectile
extends Area3D
## Physical projectile for arrows/thrown objects.

var direction: Vector3 = Vector3.FORWARD
var speed: float = 40.0
var gravity: float = 9.8
var damage: float = 10.0
var damage_type: int = HealthSystem.DamageType.BULLET
var max_lifetime: float = 5.0
var shooter: Node3D = null
var _lifetime: float = 0.0
var _velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	_velocity = direction.normalized() * speed
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_velocity.y -= gravity * delta
	position += _velocity * delta
	_lifetime += delta

	if _velocity.length() > 0.1:
		look_at(position + _velocity)

	if _lifetime >= max_lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == shooter:
		return
	var hs := body.get_node_or_null("HealthSystem") as HealthSystem
	if hs:
		var hitzone := HitzoneSystem.detect_hitzone(
			global_position, body.global_position, 1.8
		)
		var mult := HitzoneSystem.get_multiplier(hitzone)
		var final_damage := DamageCalculator.calculate_damage(damage, mult)
		hs.take_damage(final_damage, damage_type)
	queue_free()
