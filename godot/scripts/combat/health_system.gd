class_name HealthSystem
extends Node
## Tracks HP for any entity. Attach as child node.

signal damage_taken(amount: float, damage_type: int)
signal healed(amount: float)
signal died()
signal respawned()

enum DamageType { MELEE = 0, BULLET = 1, EXPLOSIVE = 2, FALL = 3, ZONE = 4 }

@export var max_hp: float = 100.0

var current_hp: float = 100.0
var is_dead: bool = false
var _spawn_protection: float = 0.0


func _ready() -> void:
	current_hp = max_hp
	_spawn_protection = 3.0


func _process(delta: float) -> void:
	if _spawn_protection > 0.0:
		_spawn_protection -= delta


func take_damage(amount: float, damage_type: int = DamageType.MELEE) -> void:
	# In multiplayer, only the server (authority) applies damage to players
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if is_dead:
		return
	if _spawn_protection > 0.0:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	damage_taken.emit(amount, damage_type)
	if current_hp <= 0.0:
		_die()


func heal(amount: float) -> void:
	if is_dead:
		return
	current_hp = minf(current_hp + amount, max_hp)
	healed.emit(amount)


func _die() -> void:
	is_dead = true
	current_hp = 0.0
	died.emit()


func respawn(hp: float = -1.0) -> void:
	current_hp = hp if hp > 0.0 else max_hp
	is_dead = false
	_spawn_protection = 3.0
	respawned.emit()


func get_hp_percent() -> float:
	return current_hp / max_hp if max_hp > 0.0 else 0.0
