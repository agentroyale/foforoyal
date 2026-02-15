class_name HealthBarUI
extends Control
## Gorgeous health bar with gradient fill, shimmer sweep, outer glow, damage trail,
## segment notches, and low-HP pulse.

const LERP_SPEED := 6.0
const TRAIL_DELAY := 0.4
const TRAIL_LERP_SPEED := 2.5
const PULSE_THRESHOLD := 0.25
const PULSE_SPEED := 3.0
const PULSE_MIN_ALPHA := 0.6

# Visual tuning
const BAR_HEIGHT := 22.0
const CORNER_RADIUS := 4.0
const BORDER_WIDTH := 1.5
const LEFT_PADDING := 28.0
const GRADIENT_STEPS := 10
const SHIMMER_SPEED := 0.35
const SHIMMER_WIDTH := 0.12
const GLOW_EXPAND := 3.0

# ─── Colors ───
const BAR_DARK := Color(0.5, 0.03, 0.03)
const BAR_BRIGHT := Color(0.92, 0.12, 0.08)
const BAR_HIGHLIGHT := Color(1.0, 0.4, 0.3, 0.35)
const BAR_GLOW := Color(0.85, 0.06, 0.03, 0.2)
const BAR_LOW_DARK := Color(0.65, 0.06, 0.03)
const BAR_LOW_BRIGHT := Color(1.0, 0.18, 0.06)
const TRAIL_COLOR := Color(0.95, 0.7, 0.15, 0.5)
const BG_COLOR := Color(0.04, 0.04, 0.06, 0.92)
const BORDER_COLOR := Color(0.4, 0.38, 0.42, 0.8)
const BORDER_COLOR_LOW := Color(0.7, 0.15, 0.1, 0.9)
const TEXT_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const LABEL_COLOR := Color(0.85, 0.25, 0.2, 0.9)
const SHADOW_COLOR := Color(0, 0, 0, 0.3)
const SHIMMER_COLOR := Color(1, 1, 1, 0.12)
const NOTCH_COLOR := Color(0, 0, 0, 0.2)

var _display_hp: float = 1.0
var _trail_hp: float = 1.0
var _target_hp: float = 1.0
var _trail_timer: float = 0.0
var _pulse_time: float = 0.0
var _shimmer_phase: float = 0.0

var _max_hp: float = 100.0
var _current_hp: float = 100.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220, 32)


func _process(delta: float) -> void:
	_display_hp = lerpf(_display_hp, _target_hp, LERP_SPEED * delta)

	if _trail_timer > 0.0:
		_trail_timer -= delta
	else:
		_trail_hp = lerpf(_trail_hp, _target_hp, TRAIL_LERP_SPEED * delta)

	if _target_hp <= PULSE_THRESHOLD and _target_hp > 0.0:
		_pulse_time += delta * PULSE_SPEED
	else:
		_pulse_time = 0.0

	_shimmer_phase = fmod(_shimmer_phase + delta * SHIMMER_SPEED, 1.0)
	queue_redraw()


func set_health(current: float, max_hp: float) -> void:
	_max_hp = maxf(max_hp, 1.0)
	_current_hp = current
	var new_target := clampf(current / _max_hp, 0.0, 1.0)
	if new_target < _target_hp:
		_trail_timer = TRAIL_DELAY
	_target_hp = new_target


func _draw() -> void:
	var bar_rect := Rect2(LEFT_PADDING, (size.y - BAR_HEIGHT) * 0.5, size.x - LEFT_PADDING - 4, BAR_HEIGHT)

	# 1) Drop shadow
	draw_rect(Rect2(bar_rect.position + Vector2(2, 2), bar_rect.size), SHADOW_COLOR)

	# 2) Background
	draw_rect(bar_rect, BG_COLOR)

	# 3) Outer glow behind fill
	if _display_hp > 0.01:
		var glow_rect := Rect2(
			bar_rect.position - Vector2(GLOW_EXPAND, GLOW_EXPAND),
			Vector2(bar_rect.size.x * _display_hp + GLOW_EXPAND * 2, bar_rect.size.y + GLOW_EXPAND * 2)
		)
		var glow_col := BAR_GLOW
		if _target_hp <= PULSE_THRESHOLD:
			var pulse := (sin(_pulse_time * TAU) + 1.0) * 0.5
			glow_col.a = lerpf(0.08, 0.35, pulse)
		draw_rect(glow_rect, glow_col)

	# 4) Damage trail (yellow behind red)
	if _trail_hp > _display_hp + 0.005:
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * _trail_hp, bar_rect.size.y)), TRAIL_COLOR)

	# 5) Gradient fill (dark at bottom, bright at top)
	var fill_width := bar_rect.size.x * _display_hp
	if fill_width > 1.0:
		var is_low := _target_hp <= PULSE_THRESHOLD
		var dark := BAR_LOW_DARK if is_low else BAR_DARK
		var bright := BAR_LOW_BRIGHT if is_low else BAR_BRIGHT

		var pulse_alpha := 1.0
		if is_low and _target_hp > 0.0:
			pulse_alpha = lerpf(PULSE_MIN_ALPHA, 1.0, (sin(_pulse_time * TAU) + 1.0) * 0.5)

		var strip_h := bar_rect.size.y / float(GRADIENT_STEPS)
		for i in range(GRADIENT_STEPS):
			var t := 1.0 - float(i) / float(GRADIENT_STEPS - 1)
			var col := dark.lerp(bright, t)
			col.a = pulse_alpha
			draw_rect(Rect2(bar_rect.position.x, bar_rect.position.y + strip_h * i, fill_width, strip_h + 1.0), col)

		# 6) Inner highlight (top 25% of bar, subtle shine)
		draw_rect(Rect2(bar_rect.position.x + 1, bar_rect.position.y + 1, fill_width - 2, bar_rect.size.y * 0.25), BAR_HIGHLIGHT)

		# 7) Shimmer sweep
		var shimmer_center := _shimmer_phase * (1.0 + SHIMMER_WIDTH * 2) - SHIMMER_WIDTH
		var s_left := maxf(shimmer_center - SHIMMER_WIDTH * 0.5, 0.0)
		var s_right := minf(shimmer_center + SHIMMER_WIDTH * 0.5, _display_hp)
		if s_right > s_left:
			draw_rect(Rect2(
				bar_rect.position.x + bar_rect.size.x * s_left, bar_rect.position.y,
				bar_rect.size.x * (s_right - s_left), bar_rect.size.y
			), SHIMMER_COLOR)

	# 8) Segment notches (25%, 50%, 75%)
	for frac: float in [0.25, 0.5, 0.75]:
		var nx: float = bar_rect.position.x + bar_rect.size.x * frac
		draw_line(Vector2(nx, bar_rect.position.y), Vector2(nx, bar_rect.position.y + bar_rect.size.y), NOTCH_COLOR, 1.0)

	# 9) Border (red-tinted when low HP)
	var border_col := BORDER_COLOR_LOW if _target_hp <= PULSE_THRESHOLD else BORDER_COLOR
	draw_rect(bar_rect, border_col, false, BORDER_WIDTH)

	# 10) HP label
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(2, size.y * 0.5 + 5), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, LABEL_COLOR)

	# 11) HP text with shadow
	var hp_text := "%d/%d" % [maxi(ceili(_current_hp), 0), ceili(_max_hp)]
	var text_sz := font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
	var text_pos := Vector2(
		bar_rect.position.x + (bar_rect.size.x - text_sz.x) * 0.5,
		bar_rect.position.y + bar_rect.size.y * 0.5 + 5.0
	)
	draw_string(font, text_pos + Vector2(1, 1), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.7))
	draw_string(font, text_pos, hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT_COLOR)
