extends Node3D
## Player 3D model with KayKit animations.
## Loads animation libraries from separate GLB files at runtime.

const ANIM_LIBS := {
	"general": "res://assets/kaykit/adventurers/Rig_Medium_General.glb",
	"movement": "res://assets/kaykit/adventurers/Rig_Medium_MovementBasic.glb",
}

var _anim_player: AnimationPlayer
var _current_anim := ""


func _ready() -> void:
	# KayKit models face +Z, Godot forward is -Z
	rotation.y = PI
	_setup_animations()
	_play_anim("general/Idle_A")


func _process(_delta: float) -> void:
	if not visible or not _anim_player:
		return
	var player := get_parent() as CharacterBody3D
	if not player:
		return

	var vel := player.velocity
	var horizontal_speed := Vector2(vel.x, vel.z).length()

	if not player.is_on_floor():
		_play_anim("movement/Jump_Idle")
	elif horizontal_speed > 3.0:
		_play_anim("movement/Running_A")
	elif horizontal_speed > 0.5:
		_play_anim("movement/Walking_A")
	else:
		_play_anim("general/Idle_A")


func _play_anim(anim_name: String) -> void:
	if _current_anim == anim_name:
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)
		_current_anim = anim_name


func _setup_animations() -> void:
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimPlayer"
	add_child(_anim_player)

	for lib_name in ANIM_LIBS:
		var path: String = ANIM_LIBS[lib_name]
		if not ResourceLoader.exists(path):
			continue
		var scene := load(path) as PackedScene
		if not scene:
			continue
		var inst := scene.instantiate()
		var src_player := _find_anim_player(inst)
		if src_player:
			for src_lib_name in src_player.get_animation_library_list():
				var lib := src_player.get_animation_library(src_lib_name)
				_anim_player.add_animation_library(lib_name, lib.duplicate(true))
				break
		inst.free()


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_anim_player(child)
		if result:
			return result
	return null
