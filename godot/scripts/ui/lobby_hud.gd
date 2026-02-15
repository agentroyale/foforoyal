extends CanvasLayer
## Lobby HUD: shows player count, countdown, and connected player list.

var _status_label: Label
var _countdown_label: Label
var _player_list: VBoxContainer
var _container: PanelContainer


func _ready() -> void:
	layer = 5
	_build_ui()
	MatchManager.player_count_changed.connect(_on_player_count_changed)
	MatchManager.countdown_tick.connect(_on_countdown_tick)
	MatchManager.match_state_changed.connect(_on_match_state_changed)


func _build_ui() -> void:
	_container = PanelContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_container.offset_left = -180.0
	_container.offset_right = 180.0
	_container.offset_top = 20.0
	_container.offset_bottom = 300.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.8)
	style.border_color = Color(0.3, 0.3, 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_container.add_theme_stylebox_override("panel", style)
	add_child(_container)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_container.add_child(vbox)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "Aguardando jogadores... 0/2"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(_status_label)

	_countdown_label = Label.new()
	_countdown_label.name = "CountdownLabel"
	_countdown_label.text = ""
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 36)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vbox.add_child(_countdown_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var list_title := Label.new()
	list_title.text = "Jogadores:"
	list_title.add_theme_font_size_override("font_size", 14)
	list_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(list_title)

	_player_list = VBoxContainer.new()
	_player_list.name = "PlayerList"
	vbox.add_child(_player_list)


func _on_player_count_changed(alive: int, _total: int) -> void:
	_status_label.text = "Aguardando jogadores... %d/%d" % [alive, MatchManager.MIN_PLAYERS]
	_refresh_player_list()


func _on_countdown_tick(seconds_left: int) -> void:
	if seconds_left > 0:
		_countdown_label.text = "Partida comeca em: %d" % seconds_left
	else:
		_countdown_label.text = "VAMOS!"


func _on_match_state_changed(_old: int, new_state: int) -> void:
	if new_state == MatchManager.MatchState.DROPPING or new_state == MatchManager.MatchState.IN_PROGRESS:
		visible = false
	elif new_state == MatchManager.MatchState.WAITING_FOR_PLAYERS:
		visible = true


func _refresh_player_list() -> void:
	for child in _player_list.get_children():
		child.queue_free()
	for peer_id in MatchManager.alive_players:
		var entry: Dictionary = MatchManager.alive_players[peer_id]
		var label := Label.new()
		label.text = entry.get("name", "Player %d" % peer_id)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		_player_list.add_child(label)
