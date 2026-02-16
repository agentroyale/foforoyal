extends Node
## Battle Royale match state machine.
## Autoload singleton — manages game flow from lobby to victory.
## In singleplayer (SURVIVAL mode), all BR logic is no-op.

signal match_state_changed(old_state: int, new_state: int)
signal player_eliminated(peer_id: int, killer_id: int, placement: int)
signal match_winner(peer_id: int)
signal player_count_changed(alive: int, total: int)
signal countdown_tick(seconds_left: int)

enum GameMode { SURVIVAL = 0, BATTLE_ROYALE = 1 }

enum MatchState {
	NONE = 0,
	WAITING_FOR_PLAYERS = 1,
	COUNTDOWN = 2,
	DROPPING = 3,
	IN_PROGRESS = 4,
	GAME_OVER = 5,
}

const MIN_PLAYERS := 1
const COUNTDOWN_SECONDS := 5
const MAP_SIZE := 1024.0

var game_mode: GameMode = GameMode.SURVIVAL
var match_state: MatchState = MatchState.NONE
var alive_players: Dictionary = {}  # peer_id -> { "name": String }
var eliminated_players: Array[Dictionary] = []  # [{ "peer_id", "killer_id", "placement" }]
var kill_counts: Dictionary = {}  # peer_id -> int
var match_start_time: int = 0
var _countdown_timer: float = 0.0
var _countdown_remaining: int = 0
var _match_seed: int = 0


func _ready() -> void:
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	# CLI shortcut: --br flag forces Battle Royale mode for testing
	var all_args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in all_args:
		if arg == "--br":
			game_mode = GameMode.BATTLE_ROYALE
			break


func _process(delta: float) -> void:
	if not is_br_mode():
		return
	if match_state == MatchState.COUNTDOWN:
		_countdown_timer -= delta
		var secs := ceili(_countdown_timer)
		if secs != _countdown_remaining:
			_countdown_remaining = secs
			countdown_tick.emit(secs)
			if multiplayer.is_server():
				_sync_countdown.rpc(secs)
		if _countdown_timer <= 0.0:
			_transition_to(MatchState.DROPPING)


func is_br_mode() -> bool:
	return game_mode == GameMode.BATTLE_ROYALE


func start_lobby(mode: GameMode = GameMode.BATTLE_ROYALE) -> void:
	game_mode = mode
	if not is_br_mode():
		return
	_match_seed = randi()
	alive_players.clear()
	eliminated_players.clear()
	kill_counts.clear()
	_transition_to(MatchState.WAITING_FOR_PLAYERS)


func register_player(peer_id: int, player_name: String = "") -> void:
	if not is_br_mode():
		return
	if match_state != MatchState.WAITING_FOR_PLAYERS and match_state != MatchState.COUNTDOWN:
		return
	var display_name: String = player_name if player_name != "" else ("Player %d" % peer_id)
	alive_players[peer_id] = { "name": display_name }
	kill_counts[peer_id] = 0
	player_count_changed.emit(alive_players.size(), alive_players.size())
	# Auto-start countdown when enough players
	if multiplayer.is_server() and alive_players.size() >= MIN_PLAYERS and match_state == MatchState.WAITING_FOR_PLAYERS:
		start_countdown()


func start_countdown() -> void:
	if match_state != MatchState.WAITING_FOR_PLAYERS:
		return
	if alive_players.size() < MIN_PLAYERS:
		return
	_countdown_timer = float(COUNTDOWN_SECONDS)
	_countdown_remaining = COUNTDOWN_SECONDS
	_transition_to(MatchState.COUNTDOWN)


func eliminate_player(peer_id: int, killer_id: int = -1) -> void:
	if not is_br_mode():
		return
	if match_state != MatchState.IN_PROGRESS and match_state != MatchState.DROPPING:
		return
	if not alive_players.has(peer_id):
		return
	alive_players.erase(peer_id)
	var placement := alive_players.size() + 1
	eliminated_players.append({
		"peer_id": peer_id,
		"killer_id": killer_id,
		"placement": placement,
	})
	if killer_id > 0 and kill_counts.has(killer_id):
		kill_counts[killer_id] += 1
	player_eliminated.emit(peer_id, killer_id, placement)
	player_count_changed.emit(alive_players.size(), alive_players.size() + eliminated_players.size())
	if multiplayer.is_server():
		_sync_elimination.rpc(peer_id, killer_id, placement)
	_check_winner()


func get_placement(peer_id: int) -> int:
	for entry in eliminated_players:
		if entry["peer_id"] == peer_id:
			return entry["placement"]
	if alive_players.has(peer_id) and match_state == MatchState.GAME_OVER:
		return 1
	return -1


func get_kill_count(peer_id: int) -> int:
	return kill_counts.get(peer_id, 0)


func get_match_duration() -> float:
	if match_start_time <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - match_start_time) / 1000.0


func get_alive_count() -> int:
	return alive_players.size()


func get_total_players() -> int:
	return alive_players.size() + eliminated_players.size()


func get_match_seed() -> int:
	return _match_seed


func notify_all_landed() -> void:
	## Called by DropController when all players have landed.
	if match_state == MatchState.DROPPING:
		_transition_to(MatchState.IN_PROGRESS)


func notify_drop_complete() -> void:
	## Alias for notify_all_landed.
	notify_all_landed()


func _transition_to(new_state: MatchState) -> void:
	if new_state == match_state:
		return
	var old := match_state
	match_state = new_state
	if new_state == MatchState.IN_PROGRESS:
		match_start_time = Time.get_ticks_msec()
	match_state_changed.emit(old, new_state)
	if multiplayer.is_server():
		_sync_state.rpc(old, new_state)


func _check_winner() -> void:
	if match_state != MatchState.IN_PROGRESS and match_state != MatchState.DROPPING:
		return
	if alive_players.size() <= 1:
		if alive_players.size() == 1:
			var winner_id: int = alive_players.keys()[0]
			match_winner.emit(winner_id)
			if multiplayer.is_server():
				_sync_winner.rpc(winner_id)
		_transition_to(MatchState.GAME_OVER)


func _on_player_disconnected(peer_id: int) -> void:
	if not is_br_mode():
		return
	if alive_players.has(peer_id):
		eliminate_player(peer_id, -1)


func reset() -> void:
	game_mode = GameMode.SURVIVAL
	match_state = MatchState.NONE
	alive_players.clear()
	eliminated_players.clear()
	kill_counts.clear()
	match_start_time = 0
	_countdown_timer = 0.0
	_countdown_remaining = 0


# === RPCs ===

@rpc("authority", "reliable")
func _sync_state(old_state: int, new_state: int) -> void:
	match_state = new_state as MatchState
	match_state_changed.emit(old_state, new_state)

@rpc("authority", "reliable")
func _sync_elimination(peer_id: int, killer_id: int, placement: int) -> void:
	alive_players.erase(peer_id)
	eliminated_players.append({
		"peer_id": peer_id,
		"killer_id": killer_id,
		"placement": placement,
	})
	player_eliminated.emit(peer_id, killer_id, placement)
	player_count_changed.emit(alive_players.size(), alive_players.size() + eliminated_players.size())

@rpc("authority", "reliable")
func _sync_countdown(secs: int) -> void:
	_countdown_remaining = secs
	countdown_tick.emit(secs)

@rpc("authority", "reliable")
func _sync_winner(peer_id: int) -> void:
	match_winner.emit(peer_id)
