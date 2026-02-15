extends GutTest
## Tests for MatchManager: state machine, player tracking, winner detection.


# ─── Helpers ───

var _mm: Node

func before_each() -> void:
	_mm = load("res://scripts/gamemode/match_manager.gd").new()
	add_child_autofree(_mm)


# ─── Test 1: Starts in NONE state ───

func test_initial_state_is_none() -> void:
	assert_eq(_mm.match_state, _mm.MatchState.NONE)
	assert_eq(_mm.game_mode, _mm.GameMode.SURVIVAL)


# ─── Test 2: is_br_mode false in survival ───

func test_is_br_mode_false_in_survival() -> void:
	assert_false(_mm.is_br_mode())


# ─── Test 3: start_lobby sets BR mode ───

func test_start_lobby_sets_br_mode() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	assert_true(_mm.is_br_mode())
	assert_eq(_mm.match_state, _mm.MatchState.WAITING_FOR_PLAYERS)


# ─── Test 4: Register player adds to alive ───

func test_register_player() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	_mm.register_player(1, "Alice")
	assert_eq(_mm.alive_players.size(), 1)
	assert_eq(_mm.alive_players[1]["name"], "Alice")


# ─── Test 5: Register player default name ───

func test_register_player_default_name() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	_mm.register_player(42)
	assert_eq(_mm.alive_players[42]["name"], "Player 42")


# ─── Test 6: Countdown requires min players ───

func test_countdown_requires_min_players() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	# No players registered yet — countdown should fail
	_mm.start_countdown()
	assert_eq(_mm.match_state, _mm.MatchState.WAITING_FOR_PLAYERS)


# ─── Test 7: Countdown starts with enough players ───

func test_countdown_starts_with_min_players() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	_mm.register_player(1, "P1")
	# MIN_PLAYERS=1, so countdown auto-started on register
	assert_eq(_mm.match_state, _mm.MatchState.COUNTDOWN)


# ─── Test 8: Eliminate player removes from alive ───

func test_eliminate_player() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	_mm.register_player(1, "P1")
	_mm.register_player(2, "P2")
	_mm.register_player(3, "P3")
	_mm.match_state = _mm.MatchState.IN_PROGRESS
	_mm.eliminate_player(3, 1)
	assert_false(_mm.alive_players.has(3))
	assert_eq(_mm.eliminated_players.size(), 1)
	assert_eq(_mm.eliminated_players[0]["placement"], 3)


# ─── Test 9: Kill count increments ───

func test_kill_count() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	_mm.register_player(1, "P1")
	_mm.register_player(2, "P2")
	_mm.register_player(3, "P3")
	_mm.match_state = _mm.MatchState.IN_PROGRESS
	_mm.eliminate_player(3, 1)
	assert_eq(_mm.get_kill_count(1), 1)


# ─── Test 10: Last player alive wins ───

func test_last_alive_wins() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	_mm.register_player(1, "P1")
	_mm.register_player(2, "P2")
	_mm.register_player(3, "P3")
	_mm.match_state = _mm.MatchState.IN_PROGRESS
	var winner_id := [-1]
	_mm.match_winner.connect(func(id): winner_id[0] = id)
	_mm.eliminate_player(3, 1)
	_mm.eliminate_player(2, 1)
	assert_eq(_mm.match_state, _mm.MatchState.GAME_OVER)
	assert_eq(winner_id[0], 1)


# ─── Test 11: Placement correct order ───

func test_placement_order() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	_mm.register_player(1, "P1")
	_mm.register_player(2, "P2")
	_mm.register_player(3, "P3")
	_mm.match_state = _mm.MatchState.IN_PROGRESS
	_mm.eliminate_player(3, 2)  # 3rd place
	_mm.eliminate_player(2, 1)  # 2nd place
	assert_eq(_mm.get_placement(3), 3)
	assert_eq(_mm.get_placement(2), 2)
	assert_eq(_mm.get_placement(1), 1)  # Winner


# ─── Test 12: Cannot eliminate in wrong state ───

func test_eliminate_blocked_in_wrong_state() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	_mm.register_player(1, "P1")
	_mm.register_player(2, "P2")
	# Still in WAITING_FOR_PLAYERS
	_mm.eliminate_player(2, 1)
	assert_true(_mm.alive_players.has(2), "Player should not be eliminated during WAITING")


# ─── Test 13: Reset clears everything ───

func test_reset() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	_mm.register_player(1, "P1")
	_mm.reset()
	assert_eq(_mm.match_state, _mm.MatchState.NONE)
	assert_eq(_mm.game_mode, _mm.GameMode.SURVIVAL)
	assert_eq(_mm.alive_players.size(), 0)


# ─── Test 14: Singleplayer operations are no-op ───

func test_singleplayer_noop() -> void:
	# Default is SURVIVAL mode
	_mm.register_player(1, "P1")
	assert_eq(_mm.alive_players.size(), 0, "Register should no-op in survival")
	_mm.eliminate_player(1, -1)
	assert_eq(_mm.eliminated_players.size(), 0, "Eliminate should no-op in survival")


# ─── Test 15: notify_all_landed transitions to IN_PROGRESS ───

func test_notify_all_landed() -> void:
	_mm.start_lobby(_mm.GameMode.BATTLE_ROYALE)
	_mm.register_player(1, "P1")
	_mm.register_player(2, "P2")
	_mm.match_state = _mm.MatchState.DROPPING
	_mm.notify_all_landed()
	assert_eq(_mm.match_state, _mm.MatchState.IN_PROGRESS)
