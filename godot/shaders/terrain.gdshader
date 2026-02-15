shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

// Terrain shader with biome color from vertex colors and slope-based rock blending.
// Compatible with GL Compatibility renderer.

uniform vec4 rock_color : source_color = vec4(0.5, 0.48, 0.45, 1.0);
uniform float slope_threshold = 0.7;
uniform float noise_scale = 0.02;
uniform float noise_strength = 0.1;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Biome color from vertex color (set during mesh generation)
	vec3 biome_color = COLOR.rgb;

	// Slope detection: steeper terrain gets rock color
	float slope = 1.0 - abs(dot(normalize(world_normal), vec3(0.0, 1.0, 0.0)));
	float rock_blend = smoothstep(slope_threshold - 0.1, slope_threshold + 0.1, slope);

	// Simple procedural detail from world position
	float detail = fract(sin(dot(world_pos.xz * noise_scale, vec2(12.9898, 78.233))) * 43758.5453);
	detail = detail * noise_strength - noise_strength * 0.5;

	ALBEDO = mix(biome_color + detail, rock_color.rgb, rock_blend);
	ROUGHNESS = mix(0.9, 0.7, rock_blend);
}
