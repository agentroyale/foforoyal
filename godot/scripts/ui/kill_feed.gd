class_name KillFeedUI
extends VBoxContainer
## Displays recent kill events. Shows "Killer killed Victim (Weapon)" entries
## that fade out after a few seconds.

const MAX_ENTRIES := 5
const FADE_TIME := 4.0
const FADE_DURATION := 1.0


func _ready() -> void:
	# Position top-right
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -320
	offset_right = -10
	offset_top = 10
	offset_bottom = 200
	alignment = ALIGNMENT_BEGIN

	# Connect to CombatNetcode kill events
	var cn := get_node_or_null("/root/CombatNetcode")
	if cn:
		cn.kill_event.connect(_on_kill_event)


func add_kill(killer: String, victim: String, weapon: String) -> void:
	var label := Label.new()
	label.text = "%s  killed  %s  [%s]" % [killer, victim, weapon]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.modulate.a = 1.0

	add_child(label)
	move_child(label, 0)

	# Remove excess
	while get_child_count() > MAX_ENTRIES:
		get_child(get_child_count() - 1).queue_free()

	# Fade out after delay
	var tween := create_tween()
	tween.tween_interval(FADE_TIME)
	tween.tween_property(label, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(label.queue_free)


func _on_kill_event(killer: String, victim: String, weapon: String) -> void:
	add_kill(killer, victim, weapon)
