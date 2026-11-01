shader_type spatial;
// Swarm enemies: one MultiMesh per type. INSTANCE_CUSTOM.r is how fast the
// enemy is going (0..1, which drives the walk), .g its hit flash (0..1) and
// .b whether a lure is hurrying it: a faint glowing rim on its outline.
// The walk cycle is offset by each enemy's position so a pack doesn't march
// in step.

#include "res://shaders/rig.gdshaderinc"

uniform vec3 flash_color : source_color = vec3(1.0);
uniform float cycle_speed = 9.0;
uniform vec3 lure_color : source_color = vec3(1.0, 0.8, 0.35);
uniform float lure_glow = 0.6;

varying float flash;
varying float lured;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = TIME * cycle_speed + origin.x * 0.37 + origin.z * 0.61;
	VERTEX = rig_animate(VERTEX, UV, INSTANCE_CUSTOM.r, phase, 0.0);
	flash = INSTANCE_CUSTOM.g;
	lured = INSTANCE_CUSTOM.b;
}

void fragment() {
	ALBEDO = mix(rig_albedo(COLOR.rgb), flash_color, flash);
	ROUGHNESS = 0.8;
	// Only the silhouette's edge glows, so the model keeps its colors.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = lure_color * rim * lure_glow * lured;
}
