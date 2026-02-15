shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform float grid_size : hint_range(0.5, 10.0) = 3.0;
uniform float fade_radius : hint_range(5.0, 50.0) = 20.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grid_uv = world_pos.xz / grid_size;

	// Thin crisp lines
	vec2 deriv = fwidth(grid_uv);
	vec2 grid_aa = abs(fract(grid_uv - 0.5) - 0.5) / deriv;
	float line = 1.0 - min(min(grid_aa.x, grid_aa.y), 1.0);

	// Fade with distance from mesh center
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(world_pos.xz - center.xz);
	float fade = 1.0 - smoothstep(fade_radius * 0.4, fade_radius, dist);

	// Soft cyan glow
	ALBEDO = vec3(0.4, 0.85, 1.0);
	ALPHA = line * fade * 0.5;
}
