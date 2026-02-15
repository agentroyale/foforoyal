extends CanvasLayer
## HUD: crosshair, FPS counter, hotbar, weapon info, interaction prompt, build mode info,
## health bar, death screen, minimap.

@onready var fps_label: Label = $FPSLabel
@onready var interaction_label: Label = $InteractionLabel
@onready var build_selector: BuildSelectorUI = $BuildSelector
@onready var hotbar_container: HBoxContainer = $HotbarContainer
@onready var stability_label: Label = $StabilityLabel
@onready var crosshair: CrosshairUI = $CrosshairUI
@onready var health_bar: HealthBarUI = $HealthBar
@onready var stamina_bar: StaminaBarUI = $StaminaBar
@onready var minimap: MinimapUI = $Minimap

# Weapon HUD
@onready var weapon_panel: PanelContainer = $WeaponPanel
@onready var weapon_icon: TextureRect = $WeaponPanel/HBox/WeaponIcon
@onready var weapon_name_label: Label = $WeaponPanel/HBox/InfoVBox/WeaponName
@onready var ammo_label: Label = $WeaponPanel/HBox/InfoVBox/AmmoLabel

var _weapon_panel_style: StyleBoxFlat

var _slot_panels: Array[PanelContainer] = []
var _slot_icons: Array[TextureRect] = []
var _player_inv: PlayerInventory = null
var _weapon_ctrl: WeaponController = null
var _camera: PlayerCamera = null
var _health_system: HealthSystem = null
var _stamina_system: StaminaSystem = null
var _death_screen: DeathScreenUI = null
var _player: CharacterBody3D = null
var _active_slot: int = 0

var _style_normal: StyleBoxFlat
var _style_active: StyleBoxFlat
var _style_empty: StyleBoxFlat

var _last_damage_type: int = -1
var _zone_warning_label: Label
var _zone_timer_label: Label
var _pickup_label: Label
var _pickup_fade_timer: float = 0.0


func _ready() -> void:
	_create_slot_styles()
	_create_weapon_panel_style()
	_create_zone_ui()
	_create_pickup_label()
	_connect_build_signals.call_deferred()
	_connect_hotbar.call_deferred()
	_setup_death_screen.call_deferred()


func _create_weapon_panel_style() -> void:
	_weapon_panel_style = StyleBoxFlat.new()
	_weapon_panel_style.bg_color = Color(0.06, 0.06, 0.08, 0.7)
	_weapon_panel_style.border_color = Color(0.25, 0.25, 0.3, 0.6)
	_weapon_panel_style.set_border_width_all(1)
	_weapon_panel_style.set_corner_radius_all(6)
	_weapon_panel_style.set_content_margin_all(8)
	if weapon_panel:
		weapon_panel.add_theme_stylebox_override("panel", _weapon_panel_style)
		weapon_panel.visible = false


func _create_zone_ui() -> void:
	# Zone warning (center screen)
	_zone_warning_label = Label.new()
	_zone_warning_label.name = "ZoneWarning"
	_zone_warning_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_zone_warning_label.offset_left = -200.0
	_zone_warning_label.offset_right = 200.0
	_zone_warning_label.offset_top = 60.0
	_zone_warning_label.offset_bottom = 90.0
	_zone_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_warning_label.add_theme_font_size_override("font_size", 20)
	_zone_warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	_zone_warning_label.visible = false
	add_child(_zone_warning_label)

	# Zone timer (top center)
	_zone_timer_label = Label.new()
	_zone_timer_label.name = "ZoneTimer"
	_zone_timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_zone_timer_label.offset_left = -100.0
	_zone_timer_label.offset_right = 100.0
	_zone_timer_label.offset_top = 10.0
	_zone_timer_label.offset_bottom = 40.0
	_zone_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_timer_label.add_theme_font_size_override("font_size", 18)
	_zone_timer_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	_zone_timer_label.visible = false
	add_child(_zone_timer_label)


func _create_pickup_label() -> void:
	_pickup_label = Label.new()
	_pickup_label.name = "PickupLabel"
	_pickup_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_pickup_label.offset_left = -200.0
	_pickup_label.offset_right = 200.0
	_pickup_label.offset_top = -60.0
	_pickup_label.offset_bottom = -30.0
	_pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pickup_label.add_theme_font_size_override("font_size", 16)
	_pickup_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_pickup_label.visible = false
	add_child(_pickup_label)


func _create_slot_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.1, 0.1, 0.15, 0.75)
	_style_normal.border_color = Color(0.3, 0.3, 0.35, 0.8)
	_style_normal.set_border_width_all(2)
	_style_normal.set_corner_radius_all(4)

	_style_active = StyleBoxFlat.new()
	_style_active.bg_color = Color(0.15, 0.15, 0.1, 0.85)
	_style_active.border_color = Color(1.0, 0.85, 0.2, 0.9)
	_style_active.set_border_width_all(2)
	_style_active.set_corner_radius_all(4)

	_style_empty = StyleBoxFlat.new()
	_style_empty.bg_color = Color(0.08, 0.08, 0.1, 0.5)
	_style_empty.border_color = Color(0.2, 0.2, 0.25, 0.6)
	_style_empty.set_border_width_all(1)
	_style_empty.set_corner_radius_all(4)


func _connect_hotbar() -> void:
	for i in range(6):
		var panel := hotbar_container.get_node("Slot%d" % (i + 1)) as PanelContainer
		_slot_panels.append(panel)
		_slot_icons.append(panel.get_node("VBox/Icon") as TextureRect)

	# Find player inventory
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		# Fallback: find by node name
		var player := get_parent().get_node_or_null("Player")
		if player:
			_player = player as CharacterBody3D
			_player_inv = player.get_node_or_null("PlayerInventory") as PlayerInventory
			_weapon_ctrl = player.get_node_or_null("WeaponController") as WeaponController
			_camera = player.get_node_or_null("CameraPivot") as PlayerCamera
			_health_system = player.get_node_or_null("HealthSystem") as HealthSystem
			_stamina_system = player.get_node_or_null("StaminaSystem") as StaminaSystem
	else:
		_player = players[0] as CharacterBody3D
		_player_inv = players[0].get_node_or_null("PlayerInventory") as PlayerInventory
		_weapon_ctrl = players[0].get_node_or_null("WeaponController") as WeaponController
		_camera = players[0].get_node_or_null("CameraPivot") as PlayerCamera
		_health_system = players[0].get_node_or_null("HealthSystem") as HealthSystem
		_stamina_system = players[0].get_node_or_null("StaminaSystem") as StaminaSystem

	if _player_inv:
		_player_inv.active_slot_changed.connect(_on_active_slot_changed)
		_player_inv.hotbar.inventory_changed.connect(_refresh_hotbar)
		_refresh_hotbar()

	if _weapon_ctrl:
		_weapon_ctrl.ammo_changed.connect(_on_ammo_changed)
		_weapon_ctrl.weapon_fired.connect(_on_weapon_fired)
		_weapon_ctrl.hit_confirmed.connect(_on_hit_confirmed)
		_weapon_ctrl.spread_changed.connect(_on_spread_changed)

	# Connect health system
	if _health_system:
		_health_system.damage_taken.connect(_on_damage_taken)
		_health_system.healed.connect(_on_healed)
		_health_system.died.connect(_on_player_died)
		_health_system.respawned.connect(_on_player_respawned)
		# Set initial health
		if health_bar:
			health_bar.set_health(_health_system.current_hp, _health_system.max_hp)


func _setup_death_screen() -> void:
	# Create death screen dynamically (not in HUD tscn to keep it on a higher CanvasLayer)
	var scene := load("res://scenes/combat/death_screen.tscn") as PackedScene
	if scene:
		_death_screen = scene.instantiate() as DeathScreenUI
		# Add as sibling of HUD in the scene tree (not child of CanvasLayer)
		get_parent().add_child.call_deferred(_death_screen)
		# Connect respawn after it's in the tree
		_death_screen.respawn_requested.connect(_on_respawn_requested)


func _connect_build_signals() -> void:
	var players := get_tree().get_nodes_in_group("players")
	var player: Node = null
	if not players.is_empty():
		player = players[0]
	else:
		player = get_parent().get_node_or_null("Player")
	if not player:
		return
	var placer := player.get_node_or_null("BuildingPlacer") as BuildingPlacer
	if placer:
		placer.build_mode_changed.connect(_on_build_mode_changed)
		if build_selector:
			build_selector.setup(placer)


const STABILITY_RAY_DISTANCE := 10.0

func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_update_stability_display()

	# Update crosshair ADS state
	if crosshair and _camera:
		crosshair.set_ads(_camera.is_aiming)

	# Update health bar
	if health_bar and _health_system:
		health_bar.set_health(_health_system.current_hp, _health_system.max_hp)

	# Update stamina bar
	if stamina_bar and _stamina_system:
		stamina_bar.set_stamina(_stamina_system.current_stamina, _stamina_system.max_stamina)
		stamina_bar.set_draining(_stamina_system.is_draining)

	# Update zone UI
	_update_zone_ui()

	# Pickup label fade
	if _pickup_label and _pickup_label.visible:
		_pickup_fade_timer -= _delta
		if _pickup_fade_timer <= 0.0:
			_pickup_label.visible = false


func _on_damage_taken(_amount: float, damage_type: int) -> void:
	_last_damage_type = damage_type


func _on_healed(_amount: float) -> void:
	pass  # Health bar updates in _process


func _on_player_died() -> void:
	if _death_screen:
		_death_screen.show_death(_last_damage_type)


func _on_player_respawned() -> void:
	if _death_screen:
		_death_screen.hide_death()


func _on_respawn_requested() -> void:
	if _health_system:
		_health_system.respawn()
	# Reset player position to spawn
	if _player:
		var center := float(ChunkManager.MAP_SIZE) / 2.0
		var spawn_x := center + 16.0
		var spawn_z := center + 16.0
		var wg = get_node_or_null("/root/WorldGenerator")
		var height := 50.0
		if wg and wg.has_method("get_height_at"):
			height = wg.get_height_at(spawn_x, spawn_z) + 2.0
		_player.global_position = Vector3(spawn_x, height, spawn_z)
		_player.velocity = Vector3.ZERO


func _on_weapon_fired(_weapon: WeaponData) -> void:
	if crosshair:
		crosshair.fire_pulse()


func _on_spread_changed(spread_degrees: float) -> void:
	if crosshair:
		crosshair.set_spread(spread_degrees)


func _on_hit_confirmed(hitzone: int, _is_kill: bool) -> void:
	if crosshair:
		crosshair.show_hitmarker(hitzone == HitzoneSystem.Hitzone.HEAD)


func _update_zone_ui() -> void:
	if not MatchManager.is_br_mode():
		if _zone_warning_label:
			_zone_warning_label.visible = false
		if _zone_timer_label:
			_zone_timer_label.visible = false
		return
	var zc := get_tree().current_scene.get_node_or_null("ZoneController") if is_inside_tree() else null
	if not zc:
		return
	# Zone timer
	if _zone_timer_label:
		var time_left := zc.get_time_until_shrink() if zc.has_method("get_time_until_shrink") else 0.0
		if time_left > 0.0:
			_zone_timer_label.text = "Zona: %ds" % ceili(time_left)
			_zone_timer_label.visible = true
		else:
			_zone_timer_label.visible = false
	# Zone warning
	if _zone_warning_label and _player:
		var outside := ZoneSystem.is_outside_zone(_player.global_position, zc.current_center, zc.current_radius)
		_zone_warning_label.text = "FORA DA ZONA!"
		_zone_warning_label.visible = outside


func show_pickup_notification(item_name: String) -> void:
	if _pickup_label:
		_pickup_label.text = "%s coletado" % item_name
		_pickup_label.visible = true
		_pickup_fade_timer = 2.0


func show_interaction_prompt(text: String) -> void:
	interaction_label.text = text


func hide_interaction_prompt() -> void:
	interaction_label.text = ""


func _on_build_mode_changed(active: bool) -> void:
	if active:
		if hotbar_container:
			hotbar_container.visible = false
		if weapon_panel:
			weapon_panel.visible = false
		if build_selector:
			build_selector.visible = true
			build_selector.queue_redraw()
	else:
		if hotbar_container:
			hotbar_container.visible = true
		if build_selector:
			build_selector.visible = false
		_update_weapon_display()


func _refresh_hotbar() -> void:
	if not _player_inv:
		return
	for i in range(6):
		var slot := _player_inv.hotbar.get_slot(i)
		var is_empty := slot.is_empty()
		_slot_icons[i].texture = null if is_empty else (slot["item"] as ItemData).icon
		var style: StyleBoxFlat
		if is_empty:
			style = _style_empty
		elif i == _active_slot:
			style = _style_active
		else:
			style = _style_normal
		_slot_panels[i].add_theme_stylebox_override("panel", style)
	_update_weapon_display()


func _on_active_slot_changed(slot: int) -> void:
	_active_slot = slot
	_refresh_hotbar()


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	_update_weapon_display()


func _update_weapon_display() -> void:
	if not _player_inv or not weapon_panel:
		if weapon_panel:
			weapon_panel.visible = false
		return

	var item := _player_inv.get_active_item()
	if not item:
		weapon_panel.visible = false
		return

	weapon_panel.visible = true
	weapon_icon.texture = item.icon
	weapon_name_label.text = item.item_name
	weapon_name_label.add_theme_font_size_override("font_size", 13)
	weapon_name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))

	if item is WeaponData:
		var w := item as WeaponData
		if w.magazine_size > 0 and _weapon_ctrl:
			ammo_label.text = "%d / %d" % [_weapon_ctrl._current_ammo, w.magazine_size]
			ammo_label.add_theme_font_size_override("font_size", 22)
			ammo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
		else:
			ammo_label.text = ""
	else:
		ammo_label.text = ""


func _update_stability_display() -> void:
	if not stability_label:
		return
	var camera := get_viewport().get_camera_3d()
	if not camera:
		stability_label.visible = false
		return

	var space_state := camera.get_world_3d().direct_space_state
	var ray_origin := camera.global_position
	var ray_end := ray_origin + (-camera.global_basis.z) * STABILITY_RAY_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := space_state.intersect_ray(query)

	if result and result.collider is BuildingPiece:
		var piece := result.collider as BuildingPiece
		stability_label.text = "Stability: %d%%" % int(piece.stability * 100.0)
		stability_label.visible = true
	else:
		stability_label.visible = false
