extends Control
## Character selection screen with 3D preview, turntable, and thumbnails.

signal back_pressed()
signal character_confirmed(id: String)

const CHARACTERS := [
	{"id": "barbarian", "name": "Barbaro", "glb": "res://assets/kaykit/adventurers/Barbarian.glb", "desc": "Guerreiro forte e resistente", "color": Color(0.8, 0.2, 0.2)},
	{"id": "knight", "name": "Cavaleiro", "glb": "res://assets/kaykit/adventurers/Knight.glb", "desc": "Protetor com armadura pesada", "color": Color(0.2, 0.4, 0.8)},
	{"id": "mage", "name": "Mago", "glb": "res://assets/kaykit/adventurers/Mage.glb", "desc": "Mestre das artes arcanas", "color": Color(0.6, 0.2, 0.8)},
	{"id": "ranger", "name": "Arqueiro", "glb": "res://assets/kaykit/adventurers/Ranger.glb", "desc": "Especialista em combate a distancia", "color": Color(0.2, 0.7, 0.3)},
	{"id": "rogue", "name": "Ladino", "glb": "res://assets/kaykit/adventurers/Rogue.glb", "desc": "Agil e furtivo", "color": Color(0.8, 0.6, 0.2)},
	{"id": "rogue_hooded", "name": "Encapuzado", "glb": "res://assets/kaykit/adventurers/Rogue_Hooded.glb", "desc": "Misterioso e letal", "color": Color(0.4, 0.4, 0.5)},
]

const IDLE_ANIM_LIB := "res://assets/kaykit/adventurers/Rig_Medium_General.glb"
const TURNTABLE_SPEED := 0.3

var _current_index := 0
var _model_anchor: Node3D
var _current_model: Node3D
var _anim_player: AnimationPlayer
var _name_label: Label
var _desc_label: Label
var _viewport: SubViewport
var _thumb_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()
	_select_initial()


func _process(delta: float) -> void:
	if _model_anchor:
		_model_anchor.rotation.y += TURNTABLE_SPEED * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		back_pressed.emit()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.4)
	add_child(overlay)

	# Main panel
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -310.0
	panel.offset_right = 310.0
	panel.offset_top = -350.0
	panel.offset_bottom = 350.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	style.border_color = Color(0.35, 0.3, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "ESCOLHA SEU PERSONAGEM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vbox.add_child(title)

	# Preview row: arrows + viewport
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 8)
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(preview_row)

	var left_btn := Button.new()
	left_btn.text = "<"
	left_btn.custom_minimum_size = Vector2(40, 40)
	left_btn.add_theme_font_size_override("font_size", 24)
	left_btn.pressed.connect(_on_prev)
	preview_row.add_child(left_btn)

	# SubViewport for 3D preview
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(280, 380)
	preview_row.add_child(vpc)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(280, 380)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(_viewport)

	# 3D scene inside viewport
	var camera := Camera3D.new()
	camera.fov = 35.0
	camera.position = Vector3(0.0, 1.0, 3.0)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.8, 0.0))

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-30, 30, 0)
	key_light.light_color = Color(1.0, 0.95, 0.85)
	key_light.light_energy = 1.2
	_viewport.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-1.5, 1.5, 1.0)
	fill_light.light_color = Color(0.7, 0.8, 1.0)
	fill_light.light_energy = 0.6
	fill_light.omni_range = 8.0
	_viewport.add_child(fill_light)

	_model_anchor = Node3D.new()
	_viewport.add_child(_model_anchor)

	var right_btn := Button.new()
	right_btn.text = ">"
	right_btn.custom_minimum_size = Vector2(40, 40)
	right_btn.add_theme_font_size_override("font_size", 24)
	right_btn.pressed.connect(_on_next)
	preview_row.add_child(right_btn)

	# Character name
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	vbox.add_child(_name_label)

	# Description
	_desc_label = Label.new()
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.add_theme_font_size_override("font_size", 14)
	_desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	vbox.add_child(_desc_label)

	# Thumbnail row
	var thumb_row := HBoxContainer.new()
	thumb_row.add_theme_constant_override("separation", 6)
	thumb_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(thumb_row)

	for i in CHARACTERS.size():
		var btn := Button.new()
		btn.text = CHARACTERS[i].name
		btn.custom_minimum_size = Vector2(85, 36)
		btn.add_theme_font_size_override("font_size", 12)
		var idx := i
		btn.pressed.connect(func() -> void: _load_character(idx))
		thumb_row.add_child(btn)
		_thumb_buttons.append(btn)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	vbox.add_child(spacer)

	# Action buttons
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 16)
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(action_row)

	var back_btn := Button.new()
	back_btn.text = "Voltar"
	back_btn.custom_minimum_size = Vector2(120, 44)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	action_row.add_child(back_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirmar"
	confirm_btn.custom_minimum_size = Vector2(160, 44)
	confirm_btn.add_theme_font_size_override("font_size", 18)
	_style_confirm_button(confirm_btn)
	confirm_btn.pressed.connect(_on_confirm)
	action_row.add_child(confirm_btn)


func _style_confirm_button(btn: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal": sb.bg_color = Color(0.15, 0.5, 0.2)
			"hover": sb.bg_color = Color(0.2, 0.6, 0.25)
			"pressed": sb.bg_color = Color(0.1, 0.4, 0.15)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(8)
		btn.add_theme_stylebox_override(state, sb)


func _select_initial() -> void:
	var saved := GameSettings.selected_character
	for i in CHARACTERS.size():
		if CHARACTERS[i].id == saved:
			_current_index = i
			break
	_load_character(_current_index)


func _load_character(index: int) -> void:
	_current_index = index

	# Remove old model
	if _current_model:
		_current_model.queue_free()
		_current_model = null
	_anim_player = null

	var char_data: Dictionary = CHARACTERS[index]

	# Instantiate GLB
	var scene := load(char_data.glb) as PackedScene
	if scene:
		_current_model = scene.instantiate()
		_current_model.rotation.y = PI
		_model_anchor.add_child(_current_model)
		_setup_preview_anim()

	# Update labels
	_name_label.text = char_data.name
	_desc_label.text = char_data.desc
	_update_thumb_selection()

	# Scale-in transition
	_model_anchor.scale = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(_model_anchor, "scale", Vector3.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _setup_preview_anim() -> void:
	if not _current_model:
		return
	_anim_player = AnimationPlayer.new()
	_current_model.add_child(_anim_player)

	var anim_scene := load(IDLE_ANIM_LIB) as PackedScene
	if not anim_scene:
		return
	var inst := anim_scene.instantiate()
	var src: AnimationPlayer = _find_anim_player(inst)
	if src:
		for lib_name in src.get_animation_library_list():
			var lib := src.get_animation_library(lib_name)
			var dup := lib.duplicate(true) as AnimationLibrary
			var idle := dup.get_animation("Idle_A")
			if idle:
				idle.loop_mode = Animation.LOOP_LINEAR
			_anim_player.add_animation_library("general", dup)
			break
	inst.free()

	if _anim_player.has_animation("general/Idle_A"):
		_anim_player.play("general/Idle_A")


func _update_thumb_selection() -> void:
	for i in _thumb_buttons.size():
		var btn := _thumb_buttons[i]
		if i == _current_index:
			var sel := StyleBoxFlat.new()
			sel.bg_color = CHARACTERS[i].color
			sel.set_corner_radius_all(4)
			sel.set_content_margin_all(4)
			btn.add_theme_stylebox_override("normal", sel)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_color_override("font_color")


func _on_prev() -> void:
	_load_character((_current_index - 1 + CHARACTERS.size()) % CHARACTERS.size())


func _on_next() -> void:
	_load_character((_current_index + 1) % CHARACTERS.size())


func _on_confirm() -> void:
	var char_id: String = CHARACTERS[_current_index].id
	GameSettings.selected_character = char_id
	GameSettings.save_settings()
	character_confirmed.emit(char_id)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_anim_player(child)
		if result:
			return result
	return null
