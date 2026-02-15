class_name MultiplayerMenu
extends Control
## Host/Join multiplayer menu. Allows name input, mode selection, hosting, and connecting.

signal back_pressed()

const GAME_WORLD_PATH := "res://scenes/world/game_world.tscn"

var _name_input: LineEdit
var _mode_select: OptionButton
var _host_button: Button
var _ip_input: LineEdit
var _port_input: LineEdit
var _join_button: Button
var _back_button: Button
var _status_label: Label


func _ready() -> void:
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -250.0
	panel.offset_bottom = 250.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	style.border_color = Color(0.3, 0.3, 0.35, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Multijogador"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(title)

	# Player name
	var name_label := Label.new()
	name_label.text = "Nome do Fofolete:"
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.name = "NameInput"
	_name_input.text = GameSettings.player_name if GameSettings.player_name != "" else "Fofolete"
	_name_input.placeholder_text = "Fofolete"
	vbox.add_child(_name_input)

	# Game mode
	var mode_label := Label.new()
	mode_label.text = "Modo de Jogo:"
	mode_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(mode_label)

	_mode_select = OptionButton.new()
	_mode_select.name = "ModeSelect"
	_mode_select.add_item("Sobrevivencia", 0)
	_mode_select.add_item("Batalha Royale", 1)
	_mode_select.selected = 1
	vbox.add_child(_mode_select)

	# Host button
	_host_button = Button.new()
	_host_button.name = "HostButton"
	_host_button.text = "Criar Partida"
	_host_button.custom_minimum_size.y = 40
	vbox.add_child(_host_button)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Join section
	var join_label := Label.new()
	join_label.text = "Entrar em Partida:"
	join_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(join_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	_ip_input = LineEdit.new()
	_ip_input.name = "IPInput"
	_ip_input.text = "127.0.0.1"
	_ip_input.placeholder_text = "IP"
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_ip_input)

	_port_input = LineEdit.new()
	_port_input.name = "PortInput"
	_port_input.text = str(NetworkManager.DEFAULT_PORT)
	_port_input.placeholder_text = "Porta"
	_port_input.custom_minimum_size.x = 80
	hbox.add_child(_port_input)

	_join_button = Button.new()
	_join_button.name = "JoinButton"
	_join_button.text = "Entrar"
	_join_button.custom_minimum_size.y = 40
	vbox.add_child(_join_button)

	# Status
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	vbox.add_child(_status_label)

	# Back button
	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = "Voltar"
	_back_button.custom_minimum_size.y = 36
	vbox.add_child(_back_button)


func _connect_signals() -> void:
	_host_button.pressed.connect(_on_host)
	_join_button.pressed.connect(_on_join)
	_back_button.pressed.connect(_on_back)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)


func _on_host() -> void:
	_save_player_name()
	var mode: MatchManager.GameMode = _mode_select.selected as MatchManager.GameMode
	var err := NetworkManager.host_server()
	if err != OK:
		_status_label.text = "Erro ao criar servidor: %s" % error_string(err)
		return
	_status_label.text = "Servidor criado! Aguardando jogadores..."
	MatchManager.start_lobby(mode)
	MatchManager.register_player(1, _name_input.text)
	get_tree().change_scene_to_file(GAME_WORLD_PATH)


func _on_join() -> void:
	_save_player_name()
	var ip := _ip_input.text.strip_edges()
	var port := int(_port_input.text.strip_edges())
	if ip == "":
		_status_label.text = "Insira um IP valido"
		return
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT
	_status_label.text = "Conectando a %s:%d..." % [ip, port]
	var err := NetworkManager.join_server(ip, port)
	if err != OK:
		_status_label.text = "Erro de conexao: %s" % error_string(err)


func _on_connection_succeeded() -> void:
	_status_label.text = "Conectado!"
	get_tree().change_scene_to_file(GAME_WORLD_PATH)


func _on_connection_failed() -> void:
	_status_label.text = "Falha na conexao!"


func _on_back() -> void:
	back_pressed.emit()


func _save_player_name() -> void:
	GameSettings.player_name = _name_input.text.strip_edges()
	if GameSettings.player_name == "":
		GameSettings.player_name = "Fofolete"
	GameSettings.save_settings()
