extends CanvasLayer
## BR victory/elimination screen.
## Shows placement, kill count, match duration.

signal back_to_menu()

var _title_label: Label
var _stats_label: Label
var _back_button: Button
var _active: bool = false


func _ready() -> void:
	layer = 12
	visible = false
	_build_ui()
	MatchManager.match_winner.connect(_on_match_winner)
	MatchManager.player_eliminated.connect(_on_player_eliminated)


func _build_ui() -> void:
	# Background overlay
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_title_label = Label.new()
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title_label.offset_left = -300.0
	_title_label.offset_right = 300.0
	_title_label.offset_top = -80.0
	_title_label.offset_bottom = -20.0
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	add_child(_title_label)

	_stats_label = Label.new()
	_stats_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_stats_label.offset_left = -200.0
	_stats_label.offset_right = 200.0
	_stats_label.offset_top = 0.0
	_stats_label.offset_bottom = 60.0
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	add_child(_stats_label)

	_back_button = Button.new()
	_back_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_back_button.offset_left = -80.0
	_back_button.offset_right = 80.0
	_back_button.offset_top = 80.0
	_back_button.offset_bottom = 120.0
	_back_button.text = "Voltar ao Menu"
	_back_button.add_theme_font_size_override("font_size", 18)
	_back_button.pressed.connect(_on_back_pressed)
	add_child(_back_button)


func _on_match_winner(winner_id: int) -> void:
	var local_id := NetworkManager.get_local_peer_id()
	if winner_id == local_id:
		show_victory(winner_id)
	# Eliminated players already see their screen


func _on_player_eliminated(peer_id: int, _killer_id: int, placement: int) -> void:
	var local_id := NetworkManager.get_local_peer_id()
	if peer_id == local_id:
		show_elimination(placement)


func show_victory(peer_id: int) -> void:
	_active = true
	visible = true
	_title_label.text = "VITORIA ROYALE!"
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	var kills := MatchManager.get_kill_count(peer_id)
	var duration := MatchManager.get_match_duration()
	var mins := int(duration) / 60
	var secs := int(duration) % 60
	_stats_label.text = "Kills: %d | Duracao: %d:%02d" % [kills, mins, secs]
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func show_elimination(placement: int) -> void:
	_active = true
	visible = true
	_title_label.text = "Eliminado — %do lugar" % placement
	_title_label.add_theme_color_override("font_color", Color(0.85, 0.2, 0.15))
	var local_id := NetworkManager.get_local_peer_id()
	var kills := MatchManager.get_kill_count(local_id)
	var duration := MatchManager.get_match_duration()
	var mins := int(duration) / 60
	var secs := int(duration) % 60
	_stats_label.text = "Kills: %d | Duracao: %d:%02d" % [kills, mins, secs]
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_back_pressed() -> void:
	_active = false
	visible = false
	MatchManager.reset()
	NetworkManager.disconnect_from_server()
	back_to_menu.emit()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
