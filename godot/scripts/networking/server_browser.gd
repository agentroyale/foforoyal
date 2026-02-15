extends Control
## UI for hosting or joining a multiplayer server.

@onready var ip_input: LineEdit = $VBox/IPInput
@onready var port_input: LineEdit = $VBox/PortInput
@onready var host_button: Button = $VBox/HBox/HostButton
@onready var join_button: Button = $VBox/HBox/JoinButton
@onready var disconnect_button: Button = $VBox/DisconnectButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var player_count_label: Label = $VBox/PlayerCountLabel


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)

	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.player_connected.connect(_on_player_changed)
	NetworkManager.player_disconnected.connect(_on_player_changed)

	disconnect_button.visible = false
	_update_player_count()


func _on_host_pressed() -> void:
	var port := port_input.text.to_int() if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	var err := NetworkManager.host_server(port)
	if err != OK:
		status_label.text = "Failed to host: %s" % error_string(err)
		return
	status_label.text = "Hosting on port %d..." % port


func _on_join_pressed() -> void:
	var address := ip_input.text if ip_input.text.length() > 0 else "127.0.0.1"
	var port := port_input.text.to_int() if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	var err := NetworkManager.join_server(address, port)
	if err != OK:
		status_label.text = "Failed to connect: %s" % error_string(err)
		return
	status_label.text = "Connecting to %s:%d..." % [address, port]


func _on_disconnect_pressed() -> void:
	NetworkManager.disconnect_from_server()
	status_label.text = "Disconnected"
	disconnect_button.visible = false
	host_button.disabled = false
	join_button.disabled = false
	_update_player_count()


func _on_server_started() -> void:
	status_label.text = "Server running"
	disconnect_button.visible = true
	host_button.disabled = true
	join_button.disabled = true
	_update_player_count()


func _on_connection_succeeded() -> void:
	status_label.text = "Connected as peer %d" % NetworkManager.get_local_peer_id()
	disconnect_button.visible = true
	host_button.disabled = true
	join_button.disabled = true
	_update_player_count()


func _on_connection_failed() -> void:
	status_label.text = "Connection failed"


func _on_player_changed(_id: int) -> void:
	_update_player_count()


func _update_player_count() -> void:
	player_count_label.text = "Players: %d" % NetworkManager.get_peer_count()
