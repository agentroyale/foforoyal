class_name DeathScreenUI
extends CanvasLayer
## Death screen with vignette, animated "YOU DIED" text, and respawn button.

signal respawn_requested()

const FADE_DURATION := 1.2
const TEXT_DELAY := 0.4
const TEXT_FADE_DURATION := 0.8
const BUTTON_DELAY := 1.5

const VIGNETTE_COLOR := Color(0.05, 0.0, 0.0, 0.75)
const TEXT_COLOR := Color(0.85, 0.12, 0.1, 1.0)
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const CAUSE_COLOR := Color(0.8, 0.8, 0.8, 0.7)
const BUTTON_BG := Color(0.15, 0.12, 0.12, 0.9)
const BUTTON_BG_HOVER := Color(0.25, 0.15, 0.15, 0.95)
const BUTTON_BORDER := Color(0.6, 0.2, 0.2, 0.8)

var _vignette: Control
var _title_label: Label
var _cause_label: Label
var _respawn_button: Button
var _placement_label: Label
var _active := false
var _damage_source: String = ""

# Map DamageType int to display string
const DAMAGE_NAMES := {
	0: "melee attack",
	1: "gunfire",
	2: "explosion",
	3: "falling",
	4: "the zone",
}


func _ready() -> void:
	layer = 10
	visible = false
	_build_ui()


func _build_ui() -> void:
	# Vignette overlay using custom drawing
	_vignette = Control.new()
	_vignette.name = "Vignette"
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.draw.connect(_draw_vignette)
	add_child(_vignette)

	# "YOU DIED" title
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title_label.offset_left = -200.0
	_title_label.offset_right = 200.0
	_title_label.offset_top = -60.0
	_title_label.offset_bottom = 0.0
	_title_label.text = "YOU DIED"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", TEXT_COLOR)
	_title_label.add_theme_color_override("font_shadow_color", TEXT_SHADOW_COLOR)
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_title_label.modulate.a = 0.0
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	# Cause of death label
	_cause_label = Label.new()
	_cause_label.name = "CauseLabel"
	_cause_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cause_label.offset_left = -200.0
	_cause_label.offset_right = 200.0
	_cause_label.offset_top = 5.0
	_cause_label.offset_bottom = 30.0
	_cause_label.text = ""
	_cause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cause_label.add_theme_font_size_override("font_size", 16)
	_cause_label.add_theme_color_override("font_color", CAUSE_COLOR)
	_cause_label.modulate.a = 0.0
	_cause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cause_label)

	# Respawn button
	_respawn_button = Button.new()
	_respawn_button.name = "RespawnButton"
	_respawn_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_respawn_button.offset_left = -70.0
	_respawn_button.offset_right = 70.0
	_respawn_button.offset_top = 50.0
	_respawn_button.offset_bottom = 90.0
	_respawn_button.text = "Respawn"

	# Style the button
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = BUTTON_BG
	btn_normal.border_color = BUTTON_BORDER
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(6)
	btn_normal.set_content_margin_all(8)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = BUTTON_BG_HOVER
	btn_hover.border_color = Color(0.8, 0.3, 0.3, 0.9)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(6)
	btn_hover.set_content_margin_all(8)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.3, 0.1, 0.1, 0.95)
	btn_pressed.border_color = Color(0.9, 0.3, 0.3, 1.0)
	btn_pressed.set_border_width_all(2)
	btn_pressed.set_corner_radius_all(6)
	btn_pressed.set_content_margin_all(8)

	_respawn_button.add_theme_stylebox_override("normal", btn_normal)
	_respawn_button.add_theme_stylebox_override("hover", btn_hover)
	_respawn_button.add_theme_stylebox_override("pressed", btn_pressed)
	_respawn_button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.85, 1.0))
	_respawn_button.add_theme_font_size_override("font_size", 18)

	_respawn_button.modulate.a = 0.0
	_respawn_button.pressed.connect(_on_respawn_pressed)
	add_child(_respawn_button)

	# Placement label for BR
	_placement_label = Label.new()
	_placement_label.name = "PlacementLabel"
	_placement_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_placement_label.offset_left = -200.0
	_placement_label.offset_right = 200.0
	_placement_label.offset_top = 95.0
	_placement_label.offset_bottom = 125.0
	_placement_label.text = ""
	_placement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placement_label.add_theme_font_size_override("font_size", 22)
	_placement_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_placement_label.modulate.a = 0.0
	_placement_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_placement_label)


func show_death(damage_type: int = -1) -> void:
	if _active:
		return
	_active = true
	visible = true

	# Set cause text
	if damage_type >= 0 and DAMAGE_NAMES.has(damage_type):
		_cause_label.text = "Killed by %s" % DAMAGE_NAMES[damage_type]
	else:
		_cause_label.text = ""

	# Release mouse for clicking respawn
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Reset alpha
	_vignette.modulate.a = 0.0
	_title_label.modulate.a = 0.0
	_cause_label.modulate.a = 0.0
	_respawn_button.modulate.a = 0.0

	# BR mode: hide respawn, show placement
	var is_br := MatchManager.is_br_mode()
	if is_br:
		_respawn_button.visible = false
		var local_id := NetworkManager.get_local_peer_id()
		var placement := MatchManager.get_placement(local_id)
		if placement > 0:
			_placement_label.text = "%do lugar" % placement
		else:
			_placement_label.text = ""
	else:
		_respawn_button.visible = true
		_placement_label.text = ""

	# Animate fade in sequence
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Vignette fade
	tween.tween_property(_vignette, "modulate:a", 1.0, FADE_DURATION)

	# Title fade with delay
	tween.tween_property(_title_label, "modulate:a", 1.0, TEXT_FADE_DURATION).set_delay(TEXT_DELAY)

	# Cause label
	tween.parallel().tween_property(_cause_label, "modulate:a", 1.0, TEXT_FADE_DURATION).set_delay(TEXT_DELAY + 0.3)

	# Placement label in BR
	if is_br and _placement_label.text != "":
		tween.parallel().tween_property(_placement_label, "modulate:a", 1.0, 0.5).set_delay(BUTTON_DELAY)

	# Respawn button (only in survival)
	if not is_br:
		tween.parallel().tween_property(_respawn_button, "modulate:a", 1.0, 0.5).set_delay(BUTTON_DELAY)


func hide_death() -> void:
	if not _active:
		return
	_active = false

	var tween := create_tween()
	tween.tween_property(_vignette, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_title_label, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_cause_label, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_respawn_button, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): visible = false)


func _on_respawn_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	respawn_requested.emit()
	hide_death()


func _draw_vignette() -> void:
	# Draw radial vignette: darker edges fading to transparent center
	var vp_size := _vignette.size
	var center := vp_size * 0.5
	var max_radius := center.length()

	# Multiple concentric rings from outside in
	var ring_count := 20
	for i in range(ring_count, 0, -1):
		var t := float(i) / float(ring_count)
		var radius := max_radius * t
		# Alpha increases towards the edge (quadratic falloff)
		var alpha := t * t * VIGNETTE_COLOR.a
		var color := Color(VIGNETTE_COLOR.r, VIGNETTE_COLOR.g, VIGNETTE_COLOR.b, alpha)
		# Draw filled circle
		_vignette.draw_circle(center, radius, color)

	# Extra dark border at the very edges
	var edge_color := Color(0.0, 0.0, 0.0, 0.5)
	# Top
	_vignette.draw_rect(Rect2(0, 0, vp_size.x, vp_size.y * 0.08), edge_color)
	# Bottom
	_vignette.draw_rect(Rect2(0, vp_size.y * 0.92, vp_size.x, vp_size.y * 0.08), edge_color)
	# Left
	_vignette.draw_rect(Rect2(0, 0, vp_size.x * 0.08, vp_size.y), edge_color)
	# Right
	_vignette.draw_rect(Rect2(vp_size.x * 0.92, 0, vp_size.x * 0.08, vp_size.y), edge_color)
