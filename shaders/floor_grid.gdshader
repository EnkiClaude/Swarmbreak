shader_type spatial;
// Flat floor with world-space grid lines, so motion reads under an ortho camera.

uniform vec3 base_color : source_color = vec3(0.15, 0.16, 0.18);
uniform vec3 line_color : source_color = vec3(0.23, 0.25, 0.28);
uniform float cell_size = 2.0;
uniform float line_width = 0.04;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 to_line = abs(fract(world_pos.xz / cell_size + 0.5) - 0.5) * cell_size;
	float d = min(to_line.x, to_line.y);
	float aa = fwidth(d);
	float line = 1.0 - smoothstep(line_width - aa, line_width + aa, d);
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 0.9;
}
