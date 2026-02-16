extends Node
## Mobile performance manager.
## Applies quality presets (Low/Medium/High) on mobile: viewport scale, shadows, LOD, draw distance.

enum Quality { LOW = 0, MEDIUM = 1, HIGH = 2 }

## Viewport 3D scale per quality
const SCALE_3D := [0.5, 0.667, 0.833]
## LOD threshold per quality (higher = more aggressive LOD)
const LOD_THRESHOLD := [4.0, 3.0, 2.0]
## Camera far plane per quality
const CAMERA_FAR := [200.0, 300.0, 400.0]
## Shadow quality: -1=disabled, 0=SOFT_LOW, 1=SOFT_MEDIUM
const SHADOW_QUALITY := [-1, 0, 1]

var current_quality: int = Quality.MEDIUM


func _ready() -> void:
	var mi: Node = get_node_or_null("/root/MobileInput")
	if not mi or not mi.is_mobile:
		return
	# Apply saved quality setting
	var gs: Node = get_node_or_null("/root/GameSettings")
	if gs:
		current_quality = clampi(gs.mobile_quality, 0, 2)
		gs.settings_changed.connect(_on_settings_changed)
	apply_quality(current_quality)


func _on_settings_changed() -> void:
	var gs: Node = get_node_or_null("/root/GameSettings")
	if gs:
		var q := clampi(gs.mobile_quality, 0, 2)
		if q != current_quality:
			apply_quality(q)


func apply_quality(quality: int) -> void:
	current_quality = quality

	# 3D rendering scale
	get_viewport().scaling_3d_scale = SCALE_3D[quality]

	# LOD
	get_viewport().mesh_lod_threshold = LOD_THRESHOLD[quality]

	# Shadows
	var shadow_q: int = SHADOW_QUALITY[quality]
	if shadow_q < 0:
		RenderingServer.directional_shadow_atlas_set_size(0, false)
		get_viewport().positional_shadow_atlas_size = 0
	else:
		RenderingServer.directional_shadow_atlas_set_size(1024 if shadow_q == 0 else 2048, false)
		get_viewport().positional_shadow_atlas_size = 1024 if shadow_q == 0 else 2048

	# Camera far plane — applied to active camera each frame
	_apply_camera_far()


func _process(_delta: float) -> void:
	var mi: Node = get_node_or_null("/root/MobileInput")
	if not mi or not mi.is_mobile:
		return
	_apply_camera_far()


func _apply_camera_far() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.far = CAMERA_FAR[current_quality]


func is_shell_eject_enabled() -> bool:
	## Call this from VFX scripts to check if shell eject particles should spawn.
	return current_quality >= Quality.HIGH
