class_name TargetDummy
extends CharacterBody3D
## Stationary target dummy that takes damage and respawns after death.

const RESPAWN_TIME := 3.0

var _respawn_timer: float = 0.0
var _mesh: MeshInstance3D
var _health_system: HealthSystem


func _ready() -> void:
	_health_system = $HealthSystem as HealthSystem
	_mesh = $MeshInstance3D
	_health_system.died.connect(_on_died)
	_health_system.respawned.connect(_on_respawned)


func _process(delta: float) -> void:
	if _health_system.is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_health_system.respawn()


func _on_died() -> void:
	_respawn_timer = RESPAWN_TIME
	if _mesh:
		_mesh.visible = false


func _on_respawned() -> void:
	if _mesh:
		_mesh.visible = true
