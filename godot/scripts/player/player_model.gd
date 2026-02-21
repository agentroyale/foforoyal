class_name PlayerModel
extends Node3D
## Player 3D model with animations, upper body bone aiming, and weapon visuals.
## Supports KayKit, Meshy biped, Pepe (Mixamo), and Soldier (Kevin Iglesias) skeletons.
## Loads animation libraries from separate GLB/FBX files at runtime.
## process_priority = 1 ensures bone overrides run AFTER AnimationPlayer (priority 0).

const ANIM_LIBS := {
	"general": "res://assets/kaykit/adventurers/Rig_Medium_General.glb",
	"movement": "res://assets/kaykit/adventurers/Rig_Medium_MovementBasic.glb",
	"ranged": "res://assets/kaykit/adventurers/Rig_Medium_CombatRanged.glb",
	"melee": "res://assets/kaykit/adventurers/Rig_Medium_CombatMelee.glb",
	"advanced": "res://assets/kaykit/adventurers/Rig_Medium_MovementAdvanced.glb",
	"tools": "res://assets/kaykit/adventurers/Rig_Medium_Tools.glb",
}

const MESHY_ANIM_SOURCES := {
	"run": "res://assets/meshy/Meshy_AI_Animation_Running_withSkin.glb",
	"walk": "res://assets/meshy/Meshy_AI_Animation_Walking_withSkin.glb",
	"crouch": "res://assets/meshy/Meshy_AI_Animation_Cautious_Crouch_Walk_Forward_inplace_withSkin.glb",
	"crouch_bwd": "res://assets/meshy/Meshy_AI_Animation_Cautious_Crouch_Walk_Backward_inplace_withSkin.glb",
	"run_shoot": "res://assets/meshy/Meshy_AI_Animation_Run_and_Shoot_withSkin.glb",
	"walk_shoot": "res://assets/meshy/Meshy_AI_Animation_Walk_Forward_While_Shooting_withSkin.glb",
	"walk_shoot_bwd": "res://assets/meshy/Meshy_AI_Animation_Walk_Backward_While_Shooting_withSkin.glb",
	"throw": "res://assets/meshy/Meshy_AI_Animation_Crouch_Pull_and_Throw_withSkin.glb",
}

const PEPE_ANIM_SOURCES := {
	"run": "res://assets/pepe/Running.fbx",
	"walk": "res://assets/pepe/Walking.fbx",
	"gunplay": "res://assets/pepe/Gunplay.fbx",
	"dying": "res://assets/pepe/Dying.fbx",
	"strafe": "res://assets/pepe/Strafing.fbx",
}

const SOLDIER_ANIM_LIBS := {
	"locomotion": "res://assets/soldier/soldier_locomotion.glb",
	"combat": "res://assets/soldier/soldier_combat.glb",
	"poses": "res://assets/soldier/soldier_poses.glb",
}

const SPINE_PITCH_WEIGHT := 0.4
const CHEST_PITCH_WEIGHT := 0.6

# Static animation library cache — avoids re-loading 6 GLBs per player/bot spawn
static var _kaykit_anim_cache: Dictionary = {}  # lib_name -> AnimationLibrary
static var _kaykit_cache_ready: bool = false

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
var drop_mode := false  ## true during BR drop — hides weapon, forces freefall anim
var _weapon_hidden_for_drop := false  ## tracks if weapon was hidden by drop
var _rig_type := "kaykit"  # "kaykit", "meshy", "pepe", or "soldier"
var _anim_map := {}


func _ready() -> void:
	process_priority = 1
	rotation.y = PI
	_setup_skeleton()
	if not _skeleton:
		_setup_skeleton_deferred.call_deferred()
	_detect_rig_type()
	_remove_embedded_anim_player()
	_fix_skinned_mesh_culling()
	_apply_model_overrides()
	_build_anim_map()
	_setup_animations()
	print("[PlayerModel] rig_type=%s skeleton=%s meshes=%d" % [
		_rig_type, _skeleton != null, _find_all_mesh_instances(self).size()])
	var idle_anim: String = _anim_map.get("idle", "general/Idle_A")
	_play_anim(idle_anim)
	_connect_combat_signals.call_deferred()


func _remove_embedded_anim_player() -> void:
	## FBX/GLB scenes come with an embedded AnimationPlayer that conflicts with ours.
	if _rig_type == "kaykit":
		return
	var embedded := get_node_or_null("AnimationPlayer")
	if embedded and embedded is AnimationPlayer:
		embedded.queue_free()


func _fix_skinned_mesh_culling() -> void:
	## FBX skinned meshes have a tiny bind-space AABB (~0.02m) that causes
	## frustum culling to hide the model even though the skeleton deforms it
	## to full size at runtime. Fix by setting a custom AABB on all meshes.
	if _rig_type == "kaykit":
		return
	var large_aabb := AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3.0, 2.5, 3.0))
	for mesh_inst in _find_all_mesh_instances(self):
		mesh_inst.custom_aabb = large_aabb


func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_find_all_mesh_instances(child))
	return result


func _apply_model_overrides() -> void:
	## Apply per-character transform overrides from GameSettings (set via F9 ModelAdjust).
	var char_id := GameSettings.selected_character
	var override := GameSettings.get_model_override(char_id)
	if override.is_empty():
		return
	var s: float = override.get("scale", 1.0)
	scale = Vector3.ONE * s
	position = override.get("offset", Vector3.ZERO)
	rotation.x = deg_to_rad(override.get("rot_x", 0.0))
	rotation.y = PI + deg_to_rad(override.get("rot_y", 0.0))
	rotation.z = deg_to_rad(override.get("rot_z", 0.0))
	print("[PlayerModel] Applied overrides for '%s': scale=%.3f offset=%s rot_extra=(%.1f, %.1f, %.1f)" % [
		char_id, s, position, override.get("rot_x", 0.0), override.get("rot_y", 0.0), override.get("rot_z", 0.0)])


func _detect_rig_type() -> void:
	if not _skeleton:
		_rig_type = "kaykit"
		return
	# Check for Kevin Iglesias Soldier rig (B- prefix bones)
	if _skeleton.find_bone("B-hips") >= 0 or _skeleton.find_bone("B-spine") >= 0:
		_rig_type = "soldier"
		return
	# Check for Mixamo rig variants
	var char_id := GameSettings.selected_character
	if _skeleton.find_bone("mixamorig_Hips") >= 0:
		_rig_type = "pepe"  # mixamorig_ prefix = Pepe FBX
	elif _skeleton.find_bone("Hips") >= 0:
		if char_id == "pepe":
			_rig_type = "pepe"
		else:
			_rig_type = "meshy"
	else:
		_rig_type = "kaykit"


func _build_anim_map() -> void:
	match _rig_type:
		"soldier":
			_anim_map = {
				"idle": "locomotion/Idle01",
				"run": "locomotion/Run_Forward",
				"walk": "locomotion/Walk_Forward",
				"crouch": "locomotion/Walk_Forward",
				"jump": "locomotion/Run_Forward",
				"run_rifle": "locomotion/Run_Forward",
				"run_bow": "locomotion/Run_Forward",
				"aim_ranged": "combat/AssaultRifle_Aim",
				"aim_bow": "combat/Rifle_Aim",
				"fire_ranged": "combat/AssaultRifle_Shoot",
				"fire_melee": "combat/ThrowGrenade",
				"fire_bow": "combat/Rifle_Shoot",
				"reload": "combat/AssaultRifle_Reload",
				"use_item": "combat/ThrowGrenade",
				"hit": "combat/Damage01",
				"death": "combat/Death01",
			}
		"meshy":
			_anim_map = {
				"idle": "mixamo/walk",
				"run": "mixamo/run",
				"walk": "mixamo/walk",
				"crouch": "mixamo/crouch",
				"jump": "mixamo/run",
				"run_rifle": "mixamo/run_shoot",
				"run_bow": "mixamo/run_shoot",
				"aim_ranged": "mixamo/walk_shoot",
				"aim_bow": "mixamo/walk_shoot",
				"fire_ranged": "mixamo/run_shoot",
				"fire_melee": "mixamo/throw",
				"fire_bow": "mixamo/throw",
				"reload": "mixamo/throw",
				"use_item": "mixamo/throw",
				"hit": "",
				"death": "",
			}
		"pepe":
			_anim_map = {
				"idle": "mixamo/walk",
				"run": "mixamo/run",
				"walk": "mixamo/walk",
				"crouch": "mixamo/strafe",
				"jump": "mixamo/run",
				"run_rifle": "mixamo/gunplay",
				"run_bow": "mixamo/gunplay",
				"aim_ranged": "mixamo/gunplay",
				"aim_bow": "mixamo/gunplay",
				"fire_ranged": "mixamo/gunplay",
				"fire_melee": "mixamo/gunplay",
				"fire_bow": "mixamo/gunplay",
				"reload": "mixamo/strafe",
				"use_item": "mixamo/strafe",
				"hit": "",
				"death": "mixamo/dying",
			}
		_:
			_anim_map = {
				"idle": "general/Idle_A",
				"run": "movement/Running_A",
				"walk": "movement/Walking_A",
				"crouch": "advanced/Crouching",
				"jump": "movement/Jump_Idle",
				"run_rifle": "advanced/Running_HoldingRifle",
				"run_bow": "advanced/Running_HoldingBow",
				"aim_ranged": "ranged/Ranged_1H_Aiming",
				"aim_bow": "ranged/Ranged_Bow_Aiming_Idle",
				"fire_ranged": "ranged/Ranged_1H_Shoot",
				"fire_melee": "melee/Melee_1H_Attack_Chop",
				"fire_bow": "ranged/Ranged_Bow_Release",
				"reload": "ranged/Ranged_1H_Reload",
				"use_item": "general/Use_Item",
				"hit": "general/Hit_A",
				"death": "general/Death_A",
			}


func _setup_skeleton_deferred() -> void:
	if _skeleton:
		return
	_setup_skeleton()
	if not _skeleton:
		return
	# Re-detect rig type if skeleton was found late
	var was_type := _rig_type
	_detect_rig_type()
	if _rig_type != was_type:
		_build_anim_map()
		if _anim_player:
			_anim_player.queue_free()
		_setup_animations()
		var idle_anim: String = _anim_map.get("idle", "general/Idle_A")
		_play_anim(idle_anim)


func _connect_combat_signals() -> void:
	if not is_inside_tree():
		return
	var wc := get_parent().get_node_or_null("WeaponController") as WeaponController
	if wc:
		wc.weapon_fired.connect(_on_weapon_fired)
		wc.weapon_reloaded.connect(_on_weapon_reloaded)
	var hs := get_parent().get_node_or_null("HealthSystem") as HealthSystem
	if hs:
		hs.damage_taken.connect(_on_damage_taken)
		hs.died.connect(_on_died)


func _on_weapon_fired(weapon: WeaponData) -> void:
	match weapon.weapon_type:
		WeaponData.WeaponType.MELEE:
			var a: String = _anim_map.get("fire_melee", "")
			if a != "":
				play_one_shot(a)
		WeaponData.WeaponType.BOW:
			var a: String = _anim_map.get("fire_bow", "")
			if a != "":
				play_one_shot(a)
		_:
			var a: String = _anim_map.get("fire_ranged", "")
			if a != "":
				_play_fire_burst(a)


func _on_weapon_reloaded(weapon: WeaponData) -> void:
	match weapon.weapon_type:
		WeaponData.WeaponType.PISTOL, WeaponData.WeaponType.SMG, \
		WeaponData.WeaponType.AR, WeaponData.WeaponType.SHOTGUN, \
		WeaponData.WeaponType.SNIPER:
			var a: String = _anim_map.get("reload", "")
			if a != "":
				play_one_shot(a)
		_:
			var a: String = _anim_map.get("use_item", "")
			if a != "":
				play_one_shot(a)


func _on_damage_taken(_amount: float, _type: int) -> void:
	var a: String = _anim_map.get("hit", "")
	if a != "":
		play_one_shot(a)


func _on_died() -> void:
	var a: String = _anim_map.get("death", "")
	if a != "":
		play_one_shot(a)


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

	# Drop mode — force freefall anim, hide weapon
	if drop_mode:
		var jump_anim: String = _anim_map.get("jump", "movement/Jump_Idle")
		_play_anim(jump_anim)
		if _weapon_visual and not _weapon_hidden_for_drop:
			_weapon_visual.set_visible(false)
			_weapon_hidden_for_drop = true
		return

	# Locomotion (skip if one-shot or fire burst is playing)
	if not _one_shot_playing and _fire_burst_timer <= 0.0:
		# Derive animation state from local or network sources
		var is_remote := multiplayer.has_multiplayer_peer() and not player.is_multiplayer_authority()
		var horizontal_speed: float
		var on_floor: bool
		var is_aiming: bool
		var is_crouching: bool

		if is_remote and player is PlayerController:
			horizontal_speed = player.network_move_speed
			on_floor = player.remote_on_floor
			is_aiming = player.network_is_aiming
			is_crouching = player.is_crouching
			# Sync weapon type from network
			if player.network_weapon_type >= 0:
				_equipped_weapon_type = player.network_weapon_type
		else:
			var vel := player.velocity
			horizontal_speed = Vector2(vel.x, vel.z).length()
			on_floor = player.is_on_floor()
			is_aiming = _is_player_aiming()
			is_crouching = player is PlayerController and player.is_crouching

		var has_ranged := _equipped_weapon_type in [
			WeaponData.WeaponType.PISTOL, WeaponData.WeaponType.SMG,
			WeaponData.WeaponType.AR, WeaponData.WeaponType.SHOTGUN,
			WeaponData.WeaponType.SNIPER,
		]
		var has_bow := _equipped_weapon_type == WeaponData.WeaponType.BOW

		if not on_floor:
			if has_ranged:
				_play_anim(_anim_map.get("run_rifle", ""))
			elif has_bow:
				_play_anim(_anim_map.get("run_bow", ""))
			else:
				_play_anim(_anim_map.get("jump", ""))
		elif is_crouching:
			_play_anim(_anim_map.get("crouch", ""))
		elif horizontal_speed > 3.0:
			if has_ranged:
				_play_anim(_anim_map.get("run_rifle", ""))
			elif has_bow:
				_play_anim(_anim_map.get("run_bow", ""))
			else:
				_play_anim(_anim_map.get("run", ""))
		elif horizontal_speed > 0.5:
			if is_aiming and has_ranged:
				_play_anim_hold(_anim_map.get("aim_ranged", ""))
			elif is_aiming and has_bow:
				_play_anim_hold(_anim_map.get("aim_bow", ""))
			else:
				_play_anim(_anim_map.get("walk", ""))
		elif is_aiming and has_ranged:
			_play_anim_hold(_anim_map.get("aim_ranged", ""))
		elif is_aiming and has_bow:
			_play_anim_hold(_anim_map.get("aim_bow", ""))
		else:
			_play_anim(_anim_map.get("idle", ""))

	# Upper body aim override (always applies, even during one-shots)
	_apply_upper_body_aim()


func _play_anim(anim_name: String) -> void:
	if anim_name == "":
		return
	if _current_anim == anim_name and not _wants_hold:
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.speed_scale = 1.0
		_wants_hold = false
		_anim_player.play(anim_name)
		_current_anim = anim_name


func _play_anim_hold(anim_name: String) -> void:
	## Play animation once, then freeze at the last frame.
	if anim_name == "":
		return
	if _current_anim == anim_name:
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.speed_scale = 1.0
		_wants_hold = true
		_anim_player.play(anim_name)
		_current_anim = anim_name


func play_one_shot(anim_name: String) -> void:
	if anim_name == "":
		return
	if _anim_player and _anim_player.has_animation(anim_name):
		_anim_player.speed_scale = 1.0
		_wants_hold = false
		_anim_player.play(anim_name)
		_one_shot_anim = anim_name
		_one_shot_playing = true
		_current_anim = anim_name


func _play_fire_burst(anim_name: String) -> void:
	## Play fire animation fully, then let locomotion resume.
	if anim_name == "":
		return
	if _anim_player and _anim_player.has_animation(anim_name):
		_anim_player.speed_scale = 1.0
		_wants_hold = false
		_anim_player.play(anim_name)
		_current_anim = anim_name
		var anim := _anim_player.get_animation(anim_name)
		_fire_burst_timer = anim.length if anim else 0.2


## Animations that should loop (locomotion/idle only) — KayKit
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

	match _rig_type:
		"soldier":
			_setup_soldier_animations()
		"meshy":
			_setup_mixamo_animations(MESHY_ANIM_SOURCES)
		"pepe":
			_setup_mixamo_animations(PEPE_ANIM_SOURCES)
		_:
			_setup_kaykit_animations()


func _setup_kaykit_animations() -> void:
	# Build cache on first load, then duplicate from cache for subsequent players
	if not _kaykit_cache_ready:
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
					_kaykit_anim_cache[lib_name] = dup_lib
					break
			inst.free()
		_kaykit_cache_ready = true

	# Use cached libraries (duplicate so each player has independent state)
	for lib_name in _kaykit_anim_cache:
		var cached: AnimationLibrary = _kaykit_anim_cache[lib_name]
		var lib := cached.duplicate(true) as AnimationLibrary
		_anim_player.add_animation_library(lib_name, lib)


func _setup_soldier_animations() -> void:
	## Load soldier animation libraries from 3 combined GLBs (same pattern as KayKit).
	const SOLDIER_LOOP_ANIMS: Array[String] = [
		"Idle01", "MilitaryIdle01",
		"Run_Forward", "Run_Backward", "Run_Left", "Run_Right",
		"Run_ForwardLeft", "Run_ForwardRight", "Run_BackwardLeft", "Run_BackwardRight",
		"Walk_Forward", "Walk_Backward", "Walk_Left", "Walk_Right",
		"Walk_ForwardLeft", "Walk_ForwardRight", "Walk_BackwardLeft", "Walk_BackwardRight",
	]
	for lib_name in SOLDIER_ANIM_LIBS:
		var path: String = SOLDIER_ANIM_LIBS[lib_name]
		if not ResourceLoader.exists(path):
			push_warning("PlayerModel: soldier anim not found: %s" % path)
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
				# Set loop mode on locomotion anims
				for anim_name in dup_lib.get_animation_list():
					if anim_name in SOLDIER_LOOP_ANIMS:
						var anim := dup_lib.get_animation(anim_name)
						if anim:
							anim.loop_mode = Animation.LOOP_LINEAR
				_anim_player.add_animation_library(lib_name, dup_lib)
				break
		inst.free()


func _setup_mixamo_animations(sources: Dictionary) -> void:
	var mixamo_lib := AnimationLibrary.new()
	for anim_key in sources:
		var path: String = sources[anim_key]
		if not ResourceLoader.exists(path):
			push_warning("PlayerModel: anim not found: %s" % path)
			continue
		var scene := load(path) as PackedScene
		if not scene:
			continue
		var inst := scene.instantiate()
		var src_player := _find_anim_player(inst)
		if src_player:
			for lib_name in src_player.get_animation_library_list():
				var lib := src_player.get_animation_library(lib_name)
				var anim_list := lib.get_animation_list()
				if anim_list.size() > 0:
					var anim := lib.get_animation(anim_list[0]).duplicate()
					mixamo_lib.add_animation(anim_key, anim)
				break
		inst.free()

	# Set loops on locomotion anims
	for anim_name in mixamo_lib.get_animation_list():
		# Loop everything except one-shot actions
		if anim_name not in ["throw", "shoot"]:
			var anim := mixamo_lib.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR

	_anim_player.add_animation_library("mixamo", mixamo_lib)


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
	if _skeleton.find_bone("B-hips") >= 0 or _skeleton.find_bone("B-spine") >= 0:
		# Kevin Iglesias Soldier skeleton (B- prefix)
		_spine_bone_idx = _skeleton.find_bone("B-spine")
		_chest_bone_idx = _skeleton.find_bone("B-chest")
	elif _skeleton.find_bone("mixamorig_Hips") >= 0:
		# Pepe/Mixamo FBX skeleton (mixamorig_ prefix)
		_spine_bone_idx = _skeleton.find_bone("mixamorig_Spine")
		_chest_bone_idx = _skeleton.find_bone("mixamorig_Spine1")
	elif _skeleton.find_bone("Hips") >= 0:
		# Meshy/Mixamo skeleton (no prefix)
		_spine_bone_idx = _skeleton.find_bone("Spine")
		_chest_bone_idx = _skeleton.find_bone("Spine01")
	else:
		# KayKit skeleton
		_spine_bone_idx = _skeleton.find_bone("spine")
		_chest_bone_idx = _skeleton.find_bone("chest")


func _apply_upper_body_aim() -> void:
	if not _skeleton or _spine_bone_idx < 0 or _chest_bone_idx < 0:
		return
	var camera_pivot := get_parent().get_node_or_null("CameraPivot") as Node3D
	if not camera_pivot:
		return
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


func enter_drop_mode() -> void:
	drop_mode = true
	if _weapon_visual:
		_weapon_visual.set_visible(false)
		_weapon_hidden_for_drop = true


func exit_drop_mode() -> void:
	drop_mode = false
	if _weapon_visual and _weapon_hidden_for_drop:
		_weapon_visual.set_visible(true)
		_weapon_hidden_for_drop = false


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
