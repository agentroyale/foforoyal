class_name PlayerModel
extends Node3D
## Player 3D model with KayKit animations, upper body bone aiming, and weapon visuals.
## Loads animation libraries from separate GLB files at runtime.
## process_priority = 1 ensures bone overrides run AFTER AnimationPlayer (priority 0).

const ANIM_LIBS := {
	"general": "res://assets/kaykit/adventurers/Rig_Medium_General.glb",
	"movement": "res://assets/kaykit/adventurers/Rig_Medium_MovementBasic.glb",
	"ranged": "res://assets/kaykit/adventurers/Rig_Medium_CombatRanged.glb",
	"melee": "res://assets/kaykit/adventurers/Rig_Medium_CombatMelee.glb",
	"advanced": "res://assets/kaykit/adventurers/Rig_Medium_MovementAdvanced.glb",
	"tools": "res://assets/kaykit/adventurers/Rig_Medium_Tools.glb",
}

const SPINE_PITCH_WEIGHT := 0.4
const CHEST_PITCH_WEIGHT := 0.6

var _anim_player: AnimationPlayer
var _current_anim := ""
var _skeleton: Skeleton3D
var _spine_bone_idx: int = -1
var _chest_bone_idx: int = -1
var _weapon_visual: WeaponVisual
var _one_shot_anim := ""
var _one_shot_playing := false
var _equipped_weapon_type: int = -1  # WeaponData.WeaponType, -1 = none
var _fire_burst_timer := 0.0
var _wants_hold := false  ## true when current anim should freeze at last frame


func _ready() -> void:
	process_priority = 1
	rotation.y = PI
	_setup_animations()
	_setup_skeleton()
	if not _skeleton:
		# GLB children may not be ready yet, retry deferred
		_setup_skeleton_deferred.call_deferred()
	_play_anim("general/Idle_A")
	_connect_combat_signals.call_deferred()


func _setup_skeleton_deferred() -> void:
	if _skeleton:
		return
	_setup_skeleton()
	if not _skeleton:
		return


func _connect_combat_signals() -> void:
	var wc := get_parent().get_node_or_null("WeaponController") as WeaponController
	if wc:
		wc.weapon_fired.connect(_on_weapon_fired)
		wc.weapon_reloaded.connect(_on_weapon_reloaded)
	var hs := get_parent().get_node_or_null("HealthSystem") as HealthSystem
	if hs:
		hs.damage_taken.connect(_on_damage_taken)
		hs.died.connect(_on_died)


func _on_weapon_fired(weapon: WeaponData) -> void:
	# Fire animations are short bursts — don't block locomotion
	match weapon.weapon_type:
		WeaponData.WeaponType.MELEE:
			play_one_shot("melee/Melee_1H_Attack_Chop")
		WeaponData.WeaponType.BOW:
			play_one_shot("ranged/Ranged_Bow_Release")
		_:
			# Ranged fire: just play briefly, don't use one-shot system
			_play_fire_burst("ranged/Ranged_1H_Shoot")


func _on_weapon_reloaded(weapon: WeaponData) -> void:
	match weapon.weapon_type:
		WeaponData.WeaponType.PISTOL, WeaponData.WeaponType.SMG:
			play_one_shot("ranged/Ranged_1H_Reload")
		_:
			play_one_shot("general/Use_Item")


func _on_damage_taken(_amount: float, _type: int) -> void:
	play_one_shot("general/Hit_A")


func _on_died() -> void:
	play_one_shot("general/Death_A")


func _process(delta: float) -> void:
	if not visible or not _anim_player:
		return
	var player := get_parent() as CharacterBody3D
	if not player:
		return

	# One-shot animation check
	if _one_shot_playing:
		if not _anim_player.is_playing() or _anim_player.current_animation != _one_shot_anim:
			_one_shot_playing = false
			_one_shot_anim = ""

	# Fire burst cooldown
	if _fire_burst_timer > 0.0:
		_fire_burst_timer -= delta

	# Hold-at-end: when a hold animation finishes, freeze at last frame
	if _wants_hold and not _anim_player.is_playing() and _current_anim != "":
		var anim := _anim_player.get_animation(_current_anim)
		if anim:
			_anim_player.play(_current_anim)
			_anim_player.seek(maxf(anim.length - 0.001, 0.0))
			_anim_player.speed_scale = 0.0

	# Locomotion (skip if one-shot or fire burst is playing)
	if not _one_shot_playing and _fire_burst_timer <= 0.0:
		var vel := player.velocity
		var horizontal_speed := Vector2(vel.x, vel.z).length()
		var has_ranged := _equipped_weapon_type in [
			WeaponData.WeaponType.PISTOL, WeaponData.WeaponType.SMG,
		]
		var has_bow := _equipped_weapon_type == WeaponData.WeaponType.BOW
		var is_aiming := _is_player_aiming()
		var is_crouching: bool = player is PlayerController and player.is_crouching

		if not player.is_on_floor():
			if has_ranged:
				_play_anim("advanced/Running_HoldingRifle")
			elif has_bow:
				_play_anim("advanced/Running_HoldingBow")
			else:
				_play_anim("movement/Jump_Idle")
		elif is_crouching:
			_play_anim("advanced/Crouching")
		elif horizontal_speed > 3.0:
			if has_ranged:
				_play_anim("advanced/Running_HoldingRifle")
			elif has_bow:
				_play_anim("advanced/Running_HoldingBow")
			else:
				_play_anim("movement/Running_A")
		elif horizontal_speed > 0.5:
			if is_aiming and has_ranged:
				_play_anim_hold("ranged/Ranged_1H_Aiming")
			elif is_aiming and has_bow:
				_play_anim_hold("ranged/Ranged_Bow_Aiming_Idle")
			else:
				_play_anim("movement/Walking_A")
		elif is_aiming and has_ranged:
			_play_anim_hold("ranged/Ranged_1H_Aiming")
		elif is_aiming and has_bow:
			_play_anim_hold("ranged/Ranged_Bow_Aiming_Idle")
		else:
			_play_anim("general/Idle_A")

	# Upper body aim override (always applies, even during one-shots)
	_apply_upper_body_aim()


func _play_anim(anim_name: String) -> void:
	if _current_anim == anim_name and not _wants_hold:
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.speed_scale = 1.0
		_wants_hold = false
		_anim_player.play(anim_name)
		_current_anim = anim_name


func _play_anim_hold(anim_name: String) -> void:
	## Play animation once, then freeze at the last frame.
	## speed_scale=0 keeps AnimationPlayer processing bones each frame
	## (prevents bone override accumulation).
	if _current_anim == anim_name:
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.speed_scale = 1.0
		_wants_hold = true
		_anim_player.play(anim_name)
		_current_anim = anim_name


func play_one_shot(anim_name: String) -> void:
	if _anim_player and _anim_player.has_animation(anim_name):
		_anim_player.speed_scale = 1.0
		_wants_hold = false
		_anim_player.play(anim_name)
		_one_shot_anim = anim_name
		_one_shot_playing = true
		_current_anim = anim_name


func _play_fire_burst(anim_name: String) -> void:
	## Play fire animation fully, then let locomotion resume.
	## Uses the real animation length instead of an arbitrary constant.
	if _anim_player and _anim_player.has_animation(anim_name):
		_anim_player.speed_scale = 1.0
		_wants_hold = false
		_anim_player.play(anim_name)
		_current_anim = anim_name
		var anim := _anim_player.get_animation(anim_name)
		_fire_burst_timer = anim.length if anim else 0.2


## Animations that should loop (locomotion/idle only)
const LOOP_ANIMS: Array[String] = [
	"Running_A", "Running_B", "Walking_A", "Walking_B", "Walking_C",
	"Jump_Idle", "Idle_A", "Idle_B",
	"Running_HoldingRifle", "Running_HoldingBow", "Crouching", "Crawling", "Sneaking",
	"Melee_2H_Idle", "Melee_Unarmed_Idle",
]


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
				var dup_lib := lib.duplicate(true) as AnimationLibrary
				_ensure_loops(dup_lib)
				_anim_player.add_animation_library(lib_name, dup_lib)
				break
		inst.free()


func _ensure_loops(lib: AnimationLibrary) -> void:
	for anim_name in lib.get_animation_list():
		if anim_name in LOOP_ANIMS:
			var anim := lib.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR


func _setup_skeleton() -> void:
	_skeleton = _find_skeleton(self)
	if not _skeleton:
		return
	_spine_bone_idx = _skeleton.find_bone("spine")
	_chest_bone_idx = _skeleton.find_bone("chest")


func _apply_upper_body_aim() -> void:
	if not _skeleton or _spine_bone_idx < 0 or _chest_bone_idx < 0:
		return
	var camera_pivot := get_parent().get_node_or_null("CameraPivot") as Node3D
	if not camera_pivot:
		return
	# Only apply when animation is actively playing (AnimationPlayer at priority 0
	# already wrote bone poses this frame, so reading is safe and won't accumulate)
	if not _anim_player.is_playing():
		return
	var spine_anim := _skeleton.get_bone_pose_rotation(_spine_bone_idx)
	var chest_anim := _skeleton.get_bone_pose_rotation(_chest_bone_idx)
	var pitch := camera_pivot.rotation.x
	var spine_rot := spine_anim * Quaternion(Vector3.RIGHT, pitch * SPINE_PITCH_WEIGHT)
	var chest_rot := chest_anim * Quaternion(Vector3.RIGHT, pitch * CHEST_PITCH_WEIGHT)
	_skeleton.set_bone_pose_rotation(_spine_bone_idx, spine_rot)
	_skeleton.set_bone_pose_rotation(_chest_bone_idx, chest_rot)


func equip_weapon_visual(weapon: WeaponData) -> void:
	clear_weapon_visual()
	_equipped_weapon_type = weapon.weapon_type
	if not _skeleton:
		_setup_skeleton()
	if not _skeleton:
		return
	_weapon_visual = WeaponVisual.new()
	_weapon_visual.setup(_skeleton, weapon)


func clear_weapon_visual() -> void:
	if _weapon_visual:
		_weapon_visual.clear()
		_weapon_visual = null
	_equipped_weapon_type = -1


func _is_player_aiming() -> bool:
	var camera_pivot := get_parent().get_node_or_null("CameraPivot")
	if camera_pivot and camera_pivot is PlayerCamera:
		return camera_pivot.is_aiming
	return false


func get_muzzle_position() -> Vector3:
	if _weapon_visual:
		return _weapon_visual.get_muzzle_global_position()
	return global_position + Vector3.UP * 1.5


func get_skeleton() -> Skeleton3D:
	return _skeleton


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result:
			return result
	return null


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_anim_player(child)
		if result:
			return result
	return null
