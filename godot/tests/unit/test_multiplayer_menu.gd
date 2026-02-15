extends GutTest
## Tests for MultiplayerMenu and BR victory screen.


# ─── Test 1: MultiplayerMenu instantiates ───

func test_multiplayer_menu_instantiates() -> void:
	var menu := MultiplayerMenu.new()
	add_child_autofree(menu)
	assert_not_null(menu)
	assert_true(menu is Control)


# ─── Test 2: Signals are defined ───

func test_multiplayer_menu_has_back_signal() -> void:
	var menu := MultiplayerMenu.new()
	add_child_autofree(menu)
	assert_true(menu.has_signal("back_pressed"))


# ─── Test 3: BR Victory screen instantiates ───

func test_victory_screen_instantiates() -> void:
	var screen_script := load("res://scripts/ui/br_victory_screen.gd") as GDScript
	var screen := CanvasLayer.new()
	screen.set_script(screen_script)
	add_child_autofree(screen)
	assert_not_null(screen)
	assert_true(screen.has_signal("back_to_menu"))


# ─── Test 4: Lobby HUD instantiates ───

func test_lobby_hud_instantiates() -> void:
	var hud_script := load("res://scripts/ui/lobby_hud.gd") as GDScript
	var hud := CanvasLayer.new()
	hud.set_script(hud_script)
	add_child_autofree(hud)
	assert_not_null(hud)


# ─── Test 5: GameSettings has player_name ───

func test_game_settings_player_name() -> void:
	assert_true("player_name" in GameSettings)
	assert_eq(typeof(GameSettings.player_name), TYPE_STRING)


# ─── Test 6: DeathScreen has placement label ───

func test_death_screen_has_placement() -> void:
	var ds := DeathScreenUI.new()
	add_child_autofree(ds)
	var label := ds.get_node_or_null("PlacementLabel")
	assert_not_null(label, "DeathScreen should have PlacementLabel")
