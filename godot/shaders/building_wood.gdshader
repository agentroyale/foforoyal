shader_type spatial;

// Wood tier: nailed wooden planks, weathered but solid

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

// Plank pattern on a 2D face: horizontal boards
// uv.x = along plank, uv.y = across planks (vertical on wall)
struct PlankResult {
	float gap;
	float plank_hash;
	float grain;
	float nail;
};

PlankResult calc_planks(vec2 uv) {
	PlankResult r;
	float plank_scale = 4.0;
	float py = uv.y * plank_scale;
	float pid = floor(py);
	float pf = fract(py);

	// Gap between planks
	r.gap = smoothstep(0.0, 0.05, pf) * smoothstep(1.0, 0.95, pf);

	// Per-plank variation
	r.plank_hash = hash(vec2(pid, floor(uv.x * 1.5)));

	// Wood grain — wavy lines along the plank
	float grain_offset = r.plank_hash * 50.0;
	r.grain = sin(uv.x * 30.0 + grain_offset + uv.y * 3.0) * 0.5 + 0.5;
	r.grain = smoothstep(0.3, 0.7, r.grain) * 0.12;

	// Nails at plank edges
	vec2 nail_uv = fract(vec2(uv.x * 3.0, py)) - 0.5;
	float near_edge = step(0.42, abs(pf - 0.5));
	r.nail = (1.0 - smoothstep(0.03, 0.055, length(nail_uv))) * near_edge * 0.25;

	return r;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 blend = triplanar_blend(wn);

	// Triplanar plank calculation
	PlankResult pyz = calc_planks(wp.yz);
	PlankResult pxz = calc_planks(wp.xz);
	PlankResult pxy = calc_planks(wp.xy);

	float gap = pyz.gap * blend.x + pxz.gap * blend.y + pxy.gap * blend.z;
	float plank_hash = pyz.plank_hash * blend.x + pxz.plank_hash * blend.y + pxy.plank_hash * blend.z;
	float grain = pyz.grain * blend.x + pxz.grain * blend.y + pxy.grain * blend.z;
	float nail = pyz.nail * blend.x + pxz.nail * blend.y + pxy.nail * blend.z;

	// Base wood colors
	vec3 light_wood = vec3(0.60, 0.44, 0.26);
	vec3 dark_wood = vec3(0.36, 0.24, 0.13);
	vec3 gap_color = vec3(0.10, 0.07, 0.03);

	vec3 plank_color = mix(dark_wood, light_wood, plank_hash * 0.6 + 0.2);
	plank_color += grain;

	vec3 color = mix(gap_color, plank_color, gap);
	color += nail;

	// Weathering via fbm
	float weather = fbm(wp.xz * 5.0, 2) * 0.07;
	color -= weather;

	// Normal from gap depth
	float bump_strength = 0.8;
	float gap_bump = 1.0 - gap;
	float nx = dFdx(gap_bump) * bump_strength;
	float ny = dFdy(gap_bump) * bump_strength;
	NORMAL_MAP = vec3(0.5 - nx * 3.0, 0.5 - ny * 3.0, 1.0);

	ALBEDO = color;
	ROUGHNESS = 0.80;
	METALLIC = 0.0;
}
