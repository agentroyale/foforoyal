shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform float zone_radius : hint_range(0.0, 1000.0) = 480.0;
uniform vec4 wall_color : source_color = vec4(0.3, 0.15, 0.8, 0.2);
uniform float scroll_speed : hint_range(0.0, 5.0) = 1.0;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.3;
uniform float emission_strength : hint_range(0.0, 5.0) = 2.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Height-based fade (dome effect)
	float height_factor = clamp(world_pos.y / 200.0, 0.0, 1.0);
	float fade_top = 1.0 - height_factor * height_factor;

	// Scrolling UV distortion
	float t = TIME * scroll_speed;
	vec2 scroll_uv = UV + vec2(sin(UV.y * 10.0 + t) * distortion_strength, t * 0.5);
	float pattern = sin(scroll_uv.x * 20.0) * sin(scroll_uv.y * 15.0 + t * 2.0);
	pattern = pattern * 0.5 + 0.5;

	// Energy pulse
	float pulse = sin(TIME * 3.0) * 0.1 + 0.9;

	float alpha = wall_color.a * fade_top * (0.7 + pattern * 0.3) * pulse;
	ALBEDO = wall_color.rgb;
	ALPHA = clamp(alpha, 0.0, 0.35);
	EMISSION = wall_color.rgb * emission_strength * fade_top * pulse;
}
