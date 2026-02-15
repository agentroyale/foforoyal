shader_type spatial;

// Metal tier: rusty corrugated sheet metal, industrial survival look

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
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

struct MetalResult {
	float ridge;
	float seam;
	float rivet;
	vec2 panel_frac;
};

MetalResult calc_metal(vec2 uv) {
	MetalResult r;

	// Corrugated ridges
	r.ridge = sin(uv.x * 14.0) * 0.5 + 0.5;
	r.ridge = smoothstep(0.25, 0.75, r.ridge);

	// Panel seams
	float ps = 1.2;
	vec2 puv = vec2(uv.x * ps, uv.y * ps * 0.8);
	r.panel_frac = fract(puv);
	float sx = smoothstep(0.0, 0.015, r.panel_frac.x) * smoothstep(1.0, 0.985, r.panel_frac.x);
	float sy = smoothstep(0.0, 0.02, r.panel_frac.y) * smoothstep(1.0, 0.98, r.panel_frac.y);
	r.seam = sx * sy;

	// Rivets near seams
	vec2 ruv = fract(vec2(uv.x * ps * 4.0, uv.y * ps * 3.2)) - 0.5;
	float near = 1.0 - step(0.05, min(r.panel_frac.x, min(1.0 - r.panel_frac.x, min(r.panel_frac.y, 1.0 - r.panel_frac.y))));
	r.rivet = (1.0 - smoothstep(0.04, 0.065, length(ruv))) * near;

	return r;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 blend = triplanar_blend(wn);

	// Triplanar metal
	MetalResult myz = calc_metal(wp.yz);
	MetalResult mxz = calc_metal(wp.xz);
	MetalResult mxy = calc_metal(wp.xy);

	float ridge = myz.ridge * blend.x + mxz.ridge * blend.y + mxy.ridge * blend.z;
	float seam = myz.seam * blend.x + mxz.seam * blend.y + mxy.seam * blend.z;
	float rivet = myz.rivet * blend.x + mxz.rivet * blend.y + mxy.rivet * blend.z;

	// Rust patches via fbm
	float rust_big = fbm(wp.xz * 4.0 + wp.yy * 2.0, 3);
	float rust_detail = fbm(wp.xz * 12.0, 2);
	float rust = smoothstep(0.35, 0.65, rust_big) * (0.7 + rust_detail * 0.3);

	// Base metal colors
	vec3 clean_metal = vec3(0.44, 0.42, 0.40);
	vec3 dark_metal = vec3(0.28, 0.26, 0.24);
	vec3 rust_color = vec3(0.55, 0.28, 0.12);
	vec3 seam_color = vec3(0.15, 0.13, 0.11);

	vec3 metal = mix(dark_metal, clean_metal, ridge * 0.5 + 0.3);
	metal = mix(seam_color, metal, seam);
	metal += rivet * 0.18;

	vec3 color = mix(metal, rust_color, rust * 0.45);

	// Scratches
	float scratch = fbm(wp.xz * 40.0 + wp.yy * 20.0, 1);
	scratch = (1.0 - smoothstep(0.92, 1.0, scratch)) * 0.12;
	color += scratch;

	// Normal from ridges + seams
	float depth = ridge * 0.3 + (1.0 - seam) * 0.7 + rivet * 0.5;
	float nx = dFdx(depth);
	float ny = dFdy(depth);
	NORMAL_MAP = vec3(0.5 - nx * 5.0, 0.5 - ny * 5.0, 1.0);

	ALBEDO = color;
	ROUGHNESS = mix(0.50, 0.78, rust * 0.8);
	METALLIC = mix(0.80, 0.15, rust * 0.8);
}
