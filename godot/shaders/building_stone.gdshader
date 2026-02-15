shader_type spatial;

// Stone tier: heavy stone bricks with mortar, solid and imposing

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

vec3 triplanar_blend(vec3 normal) {
	vec3 blend = abs(normal);
	blend = pow(blend, vec3(4.0));
	blend /= (blend.x + blend.y + blend.z);
	return blend;
}

struct BrickResult {
	float mortar;
	float brick_hash;
	float brick_hash2;
	vec2 brick_frac;
};

BrickResult calc_bricks(vec2 uv) {
	BrickResult r;
	float scale = 2.5;
	vec2 buv = vec2(uv.x * scale, uv.y * scale);
	float row = floor(buv.y);
	buv.x += mod(row, 2.0) * 0.5;

	vec2 bid = floor(buv);
	r.brick_frac = fract(buv);

	// Mortar gaps
	float mw = 0.06;
	float mx = smoothstep(0.0, mw, r.brick_frac.x) * smoothstep(1.0, 1.0 - mw, r.brick_frac.x);
	float my = smoothstep(0.0, mw * 1.5, r.brick_frac.y) * smoothstep(1.0, 1.0 - mw * 1.5, r.brick_frac.y);
	r.mortar = mx * my;

	r.brick_hash = hash(bid);
	r.brick_hash2 = hash(bid + vec2(47.3, 13.1));

	return r;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 blend = triplanar_blend(wn);

	// Triplanar brick calculation
	BrickResult byz = calc_bricks(wp.yz);
	BrickResult bxz = calc_bricks(wp.xz);
	BrickResult bxy = calc_bricks(wp.xy);

	float mortar = byz.mortar * blend.x + bxz.mortar * blend.y + bxy.mortar * blend.z;
	float brick_hash = byz.brick_hash * blend.x + bxz.brick_hash * blend.y + bxy.brick_hash * blend.z;
	float brick_hash2 = byz.brick_hash2 * blend.x + bxz.brick_hash2 * blend.y + bxy.brick_hash2 * blend.z;

	// Stone colors
	vec3 stone_light = vec3(0.58, 0.55, 0.50);
	vec3 stone_dark = vec3(0.38, 0.36, 0.33);
	vec3 stone_warm = vec3(0.52, 0.47, 0.40);
	vec3 mortar_color = vec3(0.32, 0.30, 0.27);

	vec3 brick_color = mix(stone_dark, stone_light, brick_hash * 0.7);
	brick_color = mix(brick_color, stone_warm, brick_hash2 * 0.3);

	// Surface texture via fbm
	float surface = fbm(wp.xz * 15.0 + wp.yy * 8.0, 3) * 0.08;
	brick_color += surface - 0.04;

	// Cracks in some bricks
	vec2 bf = byz.brick_frac * blend.x + bxz.brick_frac * blend.y + bxy.brick_frac * blend.z;
	float crack_chance = step(0.85, brick_hash);
	float crack = abs(sin((bf.x + bf.y * 0.5) * 20.0 + brick_hash * 100.0));
	crack = (1.0 - smoothstep(0.94, 1.0, crack)) * crack_chance * 0.12;
	brick_color -= crack;

	vec3 color = mix(mortar_color, brick_color, mortar);

	// Normal from mortar depth
	float bump_strength = 1.0;
	float mortar_depth = 1.0 - mortar;
	float nx = dFdx(mortar_depth) * bump_strength;
	float ny = dFdy(mortar_depth) * bump_strength;
	NORMAL_MAP = vec3(0.5 - nx * 4.0, 0.5 - ny * 4.0, 1.0);

	ALBEDO = color;
	ROUGHNESS = mix(0.85, 0.92, 1.0 - mortar);
	METALLIC = 0.0;
}
