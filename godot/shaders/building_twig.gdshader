shader_type spatial;

// Twig tier: rotten sticks, branches, mud — barely held together

// Noise helper
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += a * value_noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

// Triplanar helper
vec3 triplanar_blend(vec3 normal) {
	vec3 blend = abs(normal);
	blend = pow(blend, vec3(4.0));
	blend /= (blend.x + blend.y + blend.z);
	return blend;
}

float triplanar_fbm(vec3 wp, vec3 normal, float scale, int octaves) {
	vec3 blend = triplanar_blend(normal);
	float xy = fbm(wp.xy * scale, octaves);
	float xz = fbm(wp.xz * scale, octaves);
	float yz = fbm(wp.yz * scale, octaves);
	return xy * blend.z + xz * blend.y + yz * blend.x;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;

	// Stick pattern — vertical streaks via triplanar
	vec3 blend = triplanar_blend(wn);
	float bark_yz = hash(floor(wp.yz * vec2(8.0, 2.0)));
	float bark_xz = hash(floor(wp.xz * vec2(8.0, 2.0)));
	float bark_xy = hash(floor(wp.xy * vec2(8.0, 2.0)));
	float bark = bark_yz * blend.x + bark_xz * blend.y + bark_xy * blend.z;

	float streak_yz = abs(fract(wp.y * 6.0 + bark * 0.3) - 0.5) * 2.0;
	float streak_xz = abs(fract(wp.y * 6.0 + bark * 0.3) - 0.5) * 2.0;
	float streak_xy = abs(fract(wp.z * 6.0 + bark * 0.3) - 0.5) * 2.0;
	float streak = streak_yz * blend.x + streak_xz * blend.y + streak_xy * blend.z;
	streak = smoothstep(0.2, 0.8, streak);

	// Rot/decay spots
	float rot = triplanar_fbm(wp, wn, 3.0, 3);
	rot = smoothstep(0.4, 0.7, rot);

	// Mud fill noise
	float mud = triplanar_fbm(wp, wn, 6.0, 2);

	// Colors
	vec3 base_twig = vec3(0.30, 0.22, 0.12);
	vec3 dark_twig = vec3(0.14, 0.10, 0.05);
	vec3 moss = vec3(0.16, 0.22, 0.08);
	vec3 mud_color = vec3(0.22, 0.18, 0.12);

	vec3 color = mix(dark_twig, base_twig, streak);
	color = mix(color, moss, rot * 0.35);
	color = mix(color, mud_color, mud * 0.25);
	color *= 0.85 + bark * 0.3;

	// Normal perturbation
	float bump_strength = 0.6;
	float bx = triplanar_fbm(wp + vec3(0.01, 0.0, 0.0), wn, 10.0, 2) - triplanar_fbm(wp - vec3(0.01, 0.0, 0.0), wn, 10.0, 2);
	float by = triplanar_fbm(wp + vec3(0.0, 0.01, 0.0), wn, 10.0, 2) - triplanar_fbm(wp - vec3(0.0, 0.01, 0.0), wn, 10.0, 2);
	NORMAL_MAP = vec3(0.5 + bx * bump_strength, 0.5 + by * bump_strength, 1.0);

	ALBEDO = color;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
}
