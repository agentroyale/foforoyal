shader_type spatial;

// Armored tier: reinforced steel plates, clean and strong

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

vec3 triplanar_blend(vec3 normal) {
	vec3 blend = abs(normal);
	blend = pow(blend, vec3(4.0));
	blend /= (blend.x + blend.y + blend.z);
	return blend;
}

struct ArmorResult {
	float seam;
	float bolt;
	float panel_hash;
	vec2 panel_frac;
};

ArmorResult calc_armor(vec2 uv) {
	ArmorResult r;
	float ps = 1.0;
	vec2 puv = uv * ps;
	vec2 pid = floor(puv);
	r.panel_frac = fract(puv);
	r.panel_hash = hash(pid);

	// Deep recessed seams
	float sw = 0.03;
	float sx = smoothstep(0.0, sw, r.panel_frac.x) * smoothstep(1.0, 1.0 - sw, r.panel_frac.x);
	float sy = smoothstep(0.0, sw * 1.2, r.panel_frac.y) * smoothstep(1.0, 1.0 - sw * 1.2, r.panel_frac.y);
	r.seam = sx * sy;

	// Bolts at corners
	r.bolt = 0.0;
	float bs = 0.12;
	for (int i = 0; i < 4; i++) {
		vec2 corner = vec2(
			float(i % 2) * (1.0 - bs * 2.0) + bs,
			float(i / 2) * (1.0 - bs * 2.0) + bs
		);
		float d = length(r.panel_frac - corner);
		r.bolt = max(r.bolt, 1.0 - smoothstep(0.02, 0.035, d));
	}

	return r;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 blend = triplanar_blend(wn);

	// Triplanar armor plates
	ArmorResult ayz = calc_armor(wp.yz);
	ArmorResult axz = calc_armor(wp.xz);
	ArmorResult axy = calc_armor(wp.xy);

	float seam = ayz.seam * blend.x + axz.seam * blend.y + axy.seam * blend.z;
	float bolt = ayz.bolt * blend.x + axz.bolt * blend.y + axy.bolt * blend.z;
	float panel_hash = ayz.panel_hash * blend.x + axz.panel_hash * blend.y + axy.panel_hash * blend.z;

	// Cross-hatch reinforcement (subtle diamond plate)
	float hatch_yz = abs(sin((wp.y + wp.z) * 40.0)) * abs(sin((wp.y - wp.z) * 40.0));
	float hatch_xz = abs(sin((wp.x + wp.z) * 40.0)) * abs(sin((wp.x - wp.z) * 40.0));
	float hatch_xy = abs(sin((wp.x + wp.y) * 40.0)) * abs(sin((wp.x - wp.y) * 40.0));
	float hatch = hatch_yz * blend.x + hatch_xz * blend.y + hatch_xy * blend.z;
	hatch = smoothstep(0.92, 1.0, hatch) * 0.05;

	// Brushed direction
	float brushed_yz = value_noise(vec2(wp.y * 200.0, wp.z * 5.0)) * 0.025;
	float brushed_xz = value_noise(vec2(wp.x * 200.0, wp.z * 5.0)) * 0.025;
	float brushed_xy = value_noise(vec2(wp.x * 200.0, wp.y * 5.0)) * 0.025;
	float brushed = brushed_yz * blend.x + brushed_xz * blend.y + brushed_xy * blend.z;

	// Steel colors
	vec3 steel = vec3(0.62, 0.60, 0.58);
	vec3 steel_dark = vec3(0.48, 0.46, 0.44);
	vec3 seam_color = vec3(0.22, 0.20, 0.18);
	vec3 bolt_color = vec3(0.45, 0.43, 0.40);

	vec3 plate_color = mix(steel_dark, steel, panel_hash * 0.3 + 0.5);
	plate_color += brushed;
	plate_color += hatch;

	vec3 color = mix(seam_color, plate_color, seam);
	color = mix(color, bolt_color, bolt * 0.6);

	// Normal from seams + bolts
	float depth = (1.0 - seam) * 0.8 + bolt * 0.4 + hatch * 2.0;
	float nx = dFdx(depth);
	float ny = dFdy(depth);
	NORMAL_MAP = vec3(0.5 - nx * 6.0, 0.5 - ny * 6.0, 1.0);

	ALBEDO = color;
	ROUGHNESS = mix(0.32, 0.45, bolt * 0.5);
	METALLIC = 0.88;
}
