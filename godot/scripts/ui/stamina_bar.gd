class_name StaminaBarUI
extends Control
## Gorgeous stamina bar with gold gradient, shimmer, glow, and depleted pulse.

const LERP_SPEED := 8.0
const REGEN_GLOW_SPEED := 4.0
const PULSE_SPEED := 4.0
const PULSE_MIN_ALPHA := 0.5

# Visual tuning
const BAR_HEIGHT := 14.0
const BORDER_WIDTH := 1.0
const LEFT_PADDING := 28.0
const GRADIENT_STEPS := 8
const SHIMMER_SPEED := 0.5
const SHIMMER_WIDTH := 0.1
const GLOW_EXPAND := 2.0

# ─── Colors ───
const BAR_DARK := Color(0.55, 0.4, 0.02)
const BAR_BRIGHT := Color(0.95, 0.82, 0.15)
const BAR_HIGHLIGHT := Color(1.0, 0.95, 0.5, 0.3)
const BAR_GLOW := Color(0.85, 0.7, 0.05, 0.15)
const BAR_DEPLETED_DARK := Color(0.4, 0.25, 0.02)
const BAR_DEPLETED_BRIGHT := Color(0.7, 0.5, 0.05)
const BG_COLOR := Color(0.04, 0.04, 0.06, 0.88)
const BORDER_COLOR := Color(0.4, 0.38, 0.3, 0.7)
const BORDER_COLOR_LOW := Color(0.6, 0.45, 0.1, 0.85)
const TEXT_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const LABEL_COLOR := Color(0.85, 0.75, 0.2, 0.85)
const SHADOW_COLOR := Color(0, 0, 0, 0.25)
const SHIMMER_COLOR := Color(1, 1, 1, 0.1)
const NOTCH_COLOR := Color(0, 0, 0, 0.15)

const DEPLETED_THRESHOLD := 0.1

var _display_val: float = 1.0
var _target_val: float = 1.0
var _pulse_time: float = 0.0
var _shimmer_phase: float = 0.0
var _is_draining := false

var _max_stamina: float = 100.0
var _current_stamina: float = 100.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220, 22)


func _process(delta: float) -> void:
	_display_val = lerpf(_display_val, _target_val, LERP_SPEED * delta)

	if _target_val <= DEPLETED_THRESHOLD and _target_val >= 0.0:
		_pulse_time += delta * PULSE_SPEED
	else:
		_pulse_time = 0.0

	_shimmer_phase = fmod(_shimmer_phase + delta * SHIMMER_SPEED, 1.0)
	queue_redraw()


func set_stamina(current: float, max_stamina: float) -> void:
	_max_stamina = maxf(max_stamina, 1.0)
	_current_stamina = current
	_target_val = clampf(current / _max_stamina, 0.0, 1.0)


func set_draining(draining: bool) -> void:
	_is_draining = draining


func _draw() -> void:
	var bar_rect := Rect2(LEFT_PADDING, (size.y - BAR_HEIGHT) * 0.5, size.x - LEFT_PADDING - 4, BAR_HEIGHT)

	# 1) Drop shadow
	draw_rect(Rect2(bar_rect.position + Vector2(2, 2), bar_rect.size), SHADOW_COLOR)

	# 2) Background
	draw_rect(bar_rect, BG_COLOR)

	# 3) Outer glow
	if _display_val > 0.01:
		var glow_rect := Rect2(
			bar_rect.position - Vector2(GLOW_EXPAND, GLOW_EXPAND),
			Vector2(bar_rect.size.x * _display_val + GLOW_EXPAND * 2, bar_rect.size.y + GLOW_EXPAND * 2)
		)
		var glow_col := BAR_GLOW
		if _is_draining:
			glow_col.a = 0.25
		draw_rect(glow_rect, glow_col)

	# 4) Gradient fill
	var fill_width := bar_rect.size.x * _display_val
	if fill_width > 1.0:
		var is_depleted := _target_val <= DEPLETED_THRESHOLD
		var dark := BAR_DEPLETED_DARK if is_depleted else BAR_DARK
		var bright := BAR_DEPLETED_BRIGHT if is_depleted else BAR_BRIGHT

		var pulse_alpha := 1.0
		if is_depleted:
			pulse_alpha = lerpf(PULSE_MIN_ALPHA, 1.0, (sin(_pulse_time * TAU) + 1.0) * 0.5)

		var strip_h := bar_rect.size.y / float(GRADIENT_STEPS)
		for i in range(GRADIENT_STEPS):
			var t := 1.0 - float(i) / float(GRADIENT_STEPS - 1)
			var col := dark.lerp(bright, t)
			col.a = pulse_alpha
			draw_rect(Rect2(bar_rect.position.x, bar_rect.position.y + strip_h * i, fill_width, strip_h + 1.0), col)

		# 5) Inner highlight
		draw_rect(Rect2(bar_rect.position.x + 1, bar_rect.position.y + 1, fill_width - 2, bar_rect.size.y * 0.25), BAR_HIGHLIGHT)

		# 6) Shimmer sweep
		var shimmer_center := _shimmer_phase * (1.0 + SHIMMER_WIDTH * 2) - SHIMMER_WIDTH
		var s_left := maxf(shimmer_center - SHIMMER_WIDTH * 0.5, 0.0)
		var s_right := minf(shimmer_center + SHIMMER_WIDTH * 0.5, _display_val)
		if s_right > s_left:
			draw_rect(Rect2(
				bar_rect.position.x + bar_rect.size.x * s_left, bar_rect.position.y,
				bar_rect.size.x * (s_right - s_left), bar_rect.size.y
			), SHIMMER_COLOR)

	# 7) Segment notches (25%, 50%, 75%)
	for frac: float in [0.25, 0.5, 0.75]:
		var nx: float = bar_rect.position.x + bar_rect.size.x * frac
		draw_line(Vector2(nx, bar_rect.position.y), Vector2(nx, bar_rect.position.y + bar_rect.size.y), NOTCH_COLOR, 1.0)

	# 8) Border
	var border_col := BORDER_COLOR_LOW if _target_val <= DEPLETED_THRESHOLD else BORDER_COLOR
	draw_rect(bar_rect, border_col, false, BORDER_WIDTH)

	# 9) ST label
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(4, size.y * 0.5 + 4), "ST", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LABEL_COLOR)

	# 10) Percentage text with shadow
	var pct := maxi(ceili(_current_stamina), 0)
	var pct_text := "%d%%" % pct
	var text_sz := font.get_string_size(pct_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	var text_pos := Vector2(
		bar_rect.position.x + (bar_rect.size.x - text_sz.x) * 0.5,
		bar_rect.position.y + bar_rect.size.y * 0.5 + 4.0
	)
	draw_string(font, text_pos + Vector2(1, 1), pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.6))
	draw_string(font, text_pos, pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT_COLOR)
