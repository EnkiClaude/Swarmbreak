shader_type spatial;
// The open world's ground: noisy patches of open ground whose colors come
// from per-region textures (one texel per region), blended across a band at
// each region border so one region fades into the next with no seam.

uniform sampler2D region_base : source_color, filter_nearest;
uniform sampler2D region_alt : source_color, filter_nearest;
uniform sampler2D region_worn : source_color, filter_nearest;
uniform int grid_size = 3;
uniform float region_size = 128.0;
// Fraction of a region on each side of a border where colors blend.
uniform float blend = 0.12;
uniform float noise_amount = 0.25;

varying vec3 world_pos;

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

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int k = 0; k < 4; k++) {
		v += amp * value_noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

// Region colors at grid position g (in regions, 0..grid_size), blended with
// the neighbours only near borders.
vec3 region_color(sampler2D tex, vec2 g) {
	vec2 q = g - 0.5;
	vec2 i = floor(q);
	vec2 f = fract(q);
	vec2 w = smoothstep(vec2(1.0 - blend), vec2(1.0 + blend), f + 0.5);
	int last = grid_size - 1;
	ivec2 a = clamp(ivec2(i), ivec2(0), ivec2(last));
	ivec2 b = clamp(ivec2(i) + ivec2(1), ivec2(0), ivec2(last));
	vec3 c00 = texelFetch(tex, ivec2(a.x, a.y), 0).rgb;
	vec3 c10 = texelFetch(tex, ivec2(b.x, a.y), 0).rgb;
	vec3 c01 = texelFetch(tex, ivec2(a.x, b.y), 0).rgb;
	vec3 c11 = texelFetch(tex, ivec2(b.x, b.y), 0).rgb;
	return mix(mix(c00, c10, w.x), mix(c01, c11, w.x), w.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 g = p / region_size + float(grid_size) * 0.5;
	vec3 base = region_color(region_base, g);
	vec3 alt = region_color(region_alt, g);
	vec3 worn = region_color(region_worn, g);
	float patches = smoothstep(0.35, 0.65, fbm(p * 0.07 + 3.1));
	vec3 col = mix(base, alt, patches);
	col *= 1.0 + (fbm(p * 1.7) - 0.5) * noise_amount * 2.0;
	float bare = smoothstep(0.6, 0.72, fbm(p * 0.22 + 7.0));
	col = mix(col, worn, bare * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.25;
}
