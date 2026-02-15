class_name CrosshairUI
extends CenterContainer
## Dynamic crosshair with spread-driven gap, fire expansion, and hitmarker.
## Gap reflects actual weapon spread. Fire pulse adds visual pop on top.

const LINE_LENGTH := 8.0
const LINE_THICKNESS := 2.0
const DOT_RADIUS := 2.0
const GAP_ADS := 3.0
const FIRE_EXPAND := 12.0
const FIRE_DECAY := 60.0
const SPREAD_TO_PIXELS := 6.0
const HITMARKER_SIZE := 10.0
const HITMARKER_HEADSHOT_SIZE := 14.0
const HITMARKER_DURATION := 0.15
const HITMARKER_HEADSHOT_DURATION := 0.25
const CROSSHAIR_COLOR := Color(1, 1, 1, 0.85)
const HITMARKER_COLOR := Color(1, 1, 1, 0.9)
const HITMARKER_HEADSHOT_COLOR := Color(1, 0.2, 0.2, 0.95)

var _is_ads := false
var _fire_expand := 0.0
var _spread_gap := 0.0
var _hitmarker_timer := 0.0
var _hitmarker_is_headshot := false


func _process(delta: float) -> void:
	if _fire_expand > 0.0:
		_fire_expand = maxf(_fire_expand - FIRE_DECAY * delta, 0.0)

	if _hitmarker_timer > 0.0:
		_hitmarker_timer = maxf(_hitmarker_timer - delta, 0.0)

	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var gap := _spread_gap + _fire_expand
	if _is_ads:
		gap = maxf(gap * 0.6, GAP_ADS)

	# Center dot
	draw_circle(center, DOT_RADIUS, CROSSHAIR_COLOR)

	# Top
	draw_line(
		center + Vector2(0, -gap),
		center + Vector2(0, -gap - LINE_LENGTH),
		CROSSHAIR_COLOR, LINE_THICKNESS
	)
	# Bottom
	draw_line(
		center + Vector2(0, gap),
		center + Vector2(0, gap + LINE_LENGTH),
		CROSSHAIR_COLOR, LINE_THICKNESS
	)
	# Left
	draw_line(
		center + Vector2(-gap, 0),
		center + Vector2(-gap - LINE_LENGTH, 0),
		CROSSHAIR_COLOR, LINE_THICKNESS
	)
	# Right
	draw_line(
		center + Vector2(gap, 0),
		center + Vector2(gap + LINE_LENGTH, 0),
		CROSSHAIR_COLOR, LINE_THICKNESS
	)

	# Hitmarker X
	if _hitmarker_timer > 0.0:
		var hm_size := HITMARKER_HEADSHOT_SIZE if _hitmarker_is_headshot else HITMARKER_SIZE
		var hm_color := HITMARKER_HEADSHOT_COLOR if _hitmarker_is_headshot else HITMARKER_COLOR
		var duration := HITMARKER_HEADSHOT_DURATION if _hitmarker_is_headshot else HITMARKER_DURATION
		hm_color.a *= _hitmarker_timer / duration

		draw_line(center + Vector2(-hm_size, -hm_size), center + Vector2(hm_size, hm_size), hm_color, 2.0)
		draw_line(center + Vector2(hm_size, -hm_size), center + Vector2(-hm_size, hm_size), hm_color, 2.0)


func fire_pulse() -> void:
	_fire_expand = FIRE_EXPAND


func show_hitmarker(is_headshot: bool = false) -> void:
	_hitmarker_is_headshot = is_headshot
	_hitmarker_timer = HITMARKER_HEADSHOT_DURATION if is_headshot else HITMARKER_DURATION


func set_ads(ads: bool) -> void:
	_is_ads = ads


func set_spread(spread_degrees: float) -> void:
	_spread_gap = spread_degrees * SPREAD_TO_PIXELS
