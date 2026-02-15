shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Animated water surface with waves. GL Compatibility compatible.

uniform vec4 water_color : source_color = vec4(0.1, 0.3, 0.5, 0.8);
uniform float wave_speed = 0.5;
uniform float wave_amplitude = 0.3;
uniform float wave_frequency = 0.05;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave1 = sin(world_pos.x * wave_frequency + TIME * wave_speed) * wave_amplitude;
	float wave2 = sin(world_pos.z * wave_frequency * 1.3 + TIME * wave_speed * 0.7) * wave_amplitude * 0.5;
	VERTEX.y += wave1 + wave2;
	// Recalculate normal for wave distortion
	float dx = cos(world_pos.x * wave_frequency + TIME * wave_speed) * wave_amplitude * wave_frequency;
	float dz = cos(world_pos.z * wave_frequency * 1.3 + TIME * wave_speed * 0.7) * wave_amplitude * 0.5 * wave_frequency * 1.3;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	ALBEDO = water_color.rgb;
	ALPHA = water_color.a;
	METALLIC = 0.3;
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
}
