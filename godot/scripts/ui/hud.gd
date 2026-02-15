extends CanvasLayer
## HUD: crosshair, FPS counter, interaction prompt.

@onready var fps_label: Label = $FPSLabel
@onready var interaction_label: Label = $InteractionLabel


func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func show_interaction_prompt(text: String) -> void:
	interaction_label.text = text


func hide_interaction_prompt() -> void:
	interaction_label.text = ""
