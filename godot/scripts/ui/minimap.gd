class_name MinimapUI
extends Control
## Simple top-down minimap using custom _draw().
## Shows player position (center), direction arrow, and nearby building pieces.

const MAP_SIZE := 180.0
const MAP_RADIUS := 85.0  # Slightly less than half for border
const WORLD_RANGE := 80.0  # Meters of world shown in each direction from player
const BORDER_WIDTH := 3.0
const BORDER_COLOR := Color(0.2, 0.2, 0.25, 0.9)
const BG_COLOR := Color(0.08, 0.1, 0.08, 0.6)
const PLAYER_COLOR := Color(0.2, 0.9, 0.3, 1.0)
const PLAYER_SIZE := 6.0
const BUILDING_COLOR := Color(0.7, 0.6, 0.4, 0.8)
const BUILDING_SIZE := 3.0
const RESOURCE_COLOR := Color(0.5, 0.7, 0.9, 0.5)
const NORTH_COLOR := Color(0.9, 0.3, 0.3, 0.7)

var _player: CharacterBody3D = null
var _visible := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	size = Vector2(MAP_SIZE, MAP_SIZE)
	_find_player.call_deferred()


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if not players.is_empty():
		_player = players[0] as CharacterBody3D


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			_visible = not _visible
			visible = _visible


func _process(_delta: float) -> void:
	if not _player and is_inside_tree():
		_find_player()
	if _visible:
		queue_redraw()


func _draw() -> void:
	if not _player:
		return

	var center := size * 0.5
	var player_pos := _player.global_position
	var player_rot := _player.global_rotation.y

	# Background circle
	draw_circle(center, MAP_RADIUS + BORDER_WIDTH, BORDER_COLOR)
	draw_circle(center, MAP_RADIUS, BG_COLOR)

	# Set up clipping by drawing everything then we overlay the border
	# (Godot _draw doesn't have clip, so we draw carefully within radius)

	# North indicator
	var north_offset := _world_to_minimap(
		Vector3(player_pos.x, 0, player_pos.z - WORLD_RANGE * 0.9),
		player_pos, player_rot, center
	)
	if north_offset.distance_to(center) < MAP_RADIUS - 5:
		var font := ThemeDB.fallback_font
		draw_string(font, north_offset + Vector2(-4, 4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, NORTH_COLOR)

	# Draw building pieces
	if is_inside_tree():
		var buildings := get_tree().get_nodes_in_group("building_pieces")
		for building in buildings:
			if not building is Node3D:
				continue
			var bpos := (building as Node3D).global_position
			var dist := Vector2(bpos.x, bpos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			if dist > WORLD_RANGE:
				continue
			var screen_pos := _world_to_minimap(bpos, player_pos, player_rot, center)
			if screen_pos.distance_to(center) < MAP_RADIUS - 2:
				draw_rect(
					Rect2(screen_pos.x - BUILDING_SIZE, screen_pos.y - BUILDING_SIZE,
						   BUILDING_SIZE * 2, BUILDING_SIZE * 2),
					BUILDING_COLOR
				)

	# Player arrow (always at center, rotated)
	_draw_player_arrow(center, player_rot)

	# Border ring (re-draw on top to mask any overflow)
	draw_arc(center, MAP_RADIUS, 0, TAU, 48, BORDER_COLOR, BORDER_WIDTH)

	# Cardinal ticks
	for i in 4:
		var angle := float(i) * PI * 0.5 - player_rot
		var inner_p := center + Vector2(sin(angle), -cos(angle)) * (MAP_RADIUS - 6)
		var outer_p := center + Vector2(sin(angle), -cos(angle)) * MAP_RADIUS
		var tick_color := NORTH_COLOR if i == 0 else BORDER_COLOR
		draw_line(inner_p, outer_p, tick_color, 2.0)


func _draw_player_arrow(center: Vector2, _rotation_y: float) -> void:
	# Arrow pointing up (player always faces up on minimap, world rotates around)
	var forward := Vector2(0, -1)
	var left := Vector2(-1, 0)

	var tip := center + forward * PLAYER_SIZE * 1.5
	var back_left := center - forward * PLAYER_SIZE + left * PLAYER_SIZE * 0.8
	var back_right := center - forward * PLAYER_SIZE - left * PLAYER_SIZE * 0.8

	var points := PackedVector2Array([tip, back_left, back_right])
	var colors := PackedColorArray([PLAYER_COLOR, PLAYER_COLOR, PLAYER_COLOR])
	draw_polygon(points, colors)

	# Outline
	draw_line(tip, back_left, PLAYER_COLOR, 1.5)
	draw_line(back_left, back_right, PLAYER_COLOR, 1.5)
	draw_line(back_right, tip, PLAYER_COLOR, 1.5)


func _world_to_minimap(world_pos: Vector3, player_pos: Vector3, player_rot: float, center: Vector2) -> Vector2:
	## Convert world position to minimap position (player-centered, rotated so player faces up).
	var dx := world_pos.x - player_pos.x
	var dz := world_pos.z - player_pos.z

	# Rotate so player's forward direction points up on the minimap
	var sin_r := sin(-player_rot)
	var cos_r := cos(-player_rot)
	var rx := dx * cos_r - dz * sin_r
	var rz := dx * sin_r + dz * cos_r

	# Scale to minimap
	var scale_factor := MAP_RADIUS / WORLD_RANGE
	return center + Vector2(rx, rz) * scale_factor
