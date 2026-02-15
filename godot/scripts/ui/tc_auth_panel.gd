extends PanelContainer
## TC authorization panel UI.
## Shows list of authorized players, add/remove/clear buttons.

signal closed()

var _current_tc: ToolCupboard = null

@onready var title_label: Label = $VBox/TitleLabel
@onready var player_list: ItemList = $VBox/PlayerList
@onready var auth_button: Button = $VBox/ButtonRow/AuthButton
@onready var deauth_button: Button = $VBox/ButtonRow/DeauthButton
@onready var clear_button: Button = $VBox/ButtonRow/ClearButton
@onready var close_button: Button = $VBox/CloseButton


func _ready() -> void:
	auth_button.pressed.connect(_on_auth_pressed)
	deauth_button.pressed.connect(_on_deauth_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	close_button.pressed.connect(_on_close_pressed)
	hide()


func open(tc: ToolCupboard) -> void:
	_current_tc = tc
	_refresh_list()
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	_current_tc = null
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()


func _refresh_list() -> void:
	player_list.clear()
	if not _current_tc:
		return
	for player_id in _current_tc.authorized_players:
		player_list.add_item("Player %d" % player_id)


func _on_auth_pressed() -> void:
	if not _current_tc:
		return
	# In singleplayer/testing, authorize the local player (id 1)
	# In multiplayer, this would show a player selector
	_current_tc.authorize_player(1)
	_refresh_list()


func _on_deauth_pressed() -> void:
	if not _current_tc:
		return
	var selected := player_list.get_selected_items()
	if selected.is_empty():
		return
	var idx := selected[0]
	if idx < _current_tc.authorized_players.size():
		var player_id := _current_tc.authorized_players[idx]
		_current_tc.deauthorize_player(player_id)
		_refresh_list()


func _on_clear_pressed() -> void:
	if not _current_tc:
		return
	_current_tc.clear_authorization()
	_refresh_list()


func _on_close_pressed() -> void:
	close()
