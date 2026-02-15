class_name StaminaSystem
extends Node
## Stamina system: drains on sprint, regens after delay.

signal stamina_changed(current: float, max_stamina: float)
signal stamina_depleted()
signal stamina_recovered()

@export var max_stamina: float = 100.0

const DRAIN_RATE := 15.0
const REGEN_RATE := 20.0
const REGEN_DELAY := 1.0
const MIN_TO_SPRINT := 10.0

var current_stamina: float = 100.0
var is_draining := false
var _regen_cooldown: float = 0.0
var _was_depleted := false


func _ready() -> void:
	current_stamina = max_stamina


func _process(delta: float) -> void:
	if is_draining:
		current_stamina = maxf(current_stamina - DRAIN_RATE * delta, 0.0)
		_regen_cooldown = REGEN_DELAY
		if current_stamina <= 0.0 and not _was_depleted:
			_was_depleted = true
			stamina_depleted.emit()
	else:
		if _regen_cooldown > 0.0:
			_regen_cooldown -= delta
		elif current_stamina < max_stamina:
			current_stamina = minf(current_stamina + REGEN_RATE * delta, max_stamina)
			if _was_depleted and current_stamina >= MIN_TO_SPRINT:
				_was_depleted = false
				stamina_recovered.emit()
	stamina_changed.emit(current_stamina, max_stamina)


func can_sprint() -> bool:
	if _was_depleted:
		return current_stamina >= MIN_TO_SPRINT
	return current_stamina > 0.0


func set_draining(draining: bool) -> void:
	is_draining = draining


func get_stamina_percent() -> float:
	return current_stamina / max_stamina if max_stamina > 0.0 else 0.0
