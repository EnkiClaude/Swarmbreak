shader_type spatial;
// Zone floor in world space. pattern: 0 = square tiles in a light checker,
// 1 = flagstones in offset rows, 2 = open ground (dirt, sand, grass) in noisy
// patches. Tiles can carry inlay lines framing blocks of tiles.

uniform int pattern = 0;
uniform vec3 base_color : source_color = vec3(0.5, 0.15, 0.1);
uniform vec3 alt_color : source_color = vec3(0.42, 0.12, 0.08);
uniform vec3 grout_color : source_color = vec3(0.2, 0.08, 0.05);
uniform vec3 inlay_color : source_color = vec3(0.85, 0.65, 0.25);
uniform int inlay_every = 0;
uniform float tile_size = 2.0;
uniform float grout_width = 0.06;
uniform float noise_amount = 0.15;
uniform float roughness_value = 0.6;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 col;
	float specular = 0.3;
	if (pattern == 2) {
		float patches = smoothstep(0.35, 0.65, fbm(p * 0.07 + 3.1));
		col = mix(base_color, alt_color, patches);
		col *= 1.0 + (fbm(p * 1.7) - 0.5) * noise_amount * 2.0;
		float worn = smoothstep(0.6, 0.72, fbm(p * 0.22 + 7.0));
		col = mix(col, grout_color, worn * 0.7);
	} else {
		vec2 cp = p / tile_size;
		if (pattern == 1) {
			cp.x += floor(cp.y) * 0.5;
		}
		vec2 cell = floor(cp);
		vec2 f = fract(cp);
		float h = hash(cell);
		float lean = h;
		if (pattern == 0) {
			lean = mod(cell.x + cell.y, 2.0) * 0.7 + h * 0.3;
			specular = 0.6;
		}
		col = mix(base_color, alt_color, lean);
		col *= 1.0 + (fbm(p * 0.6) - 0.5) * noise_amount * 2.0;
		float g = grout_width / tile_size;
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		float aa = fwidth(edge);
		// Bevel: tiles darken a little toward their edges.
		col *= mix(0.86, 1.0, smoothstep(g, g * 3.0, edge));
		if (inlay_every > 0) {
			float block = tile_size * float(inlay_every);
			vec2 bf = fract(p / block);
			float to_edge = min(min(bf.x, 1.0 - bf.x), min(bf.y, 1.0 - bf.y)) * block;
			float baa = fwidth(to_edge);
			float inlay = 1.0 - smoothstep(0.07 - baa, 0.07 + baa, abs(to_edge - 0.3));
			col = mix(col, inlay_color, inlay);
		}
		float grout = 1.0 - smoothstep(g - aa, g + aa, edge);
		col = mix(col, grout_color, grout);
	}
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = specular;
}
