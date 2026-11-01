shader_type spatial;
// Props, walls and pillars (MultiMesh batches colored per instance): the
// instance color with world-space grain, blotches and grime that darkens
// toward the ground (grime.gdshaderinc), so stone, wood and plaster read
// as weathered rather than flat.

#include "res://shaders/grime.gdshaderinc"

uniform float detail = 0.85;
uniform float scale = 1.6;
uniform float roughness_value = 0.85;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 albedo = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = grime_apply(albedo, world_pos, world_pos.y, scale, detail);
	ROUGHNESS = roughness_value;
}
