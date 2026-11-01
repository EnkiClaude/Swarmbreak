shader_type spatial;
// Swarm enemies: one MultiMesh per type. INSTANCE_CUSTOM.r is how fast the
// enemy is going (0..1, which drives the walk) and .g its hit flash (0..1).
// The walk cycle is offset by each enemy's position so a pack doesn't march
// in step.

#include "res://shaders/rig.gdshaderinc"

uniform vec3 flash_color : source_color = vec3(1.0);
uniform float cycle_speed = 9.0;

varying float flash;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = TIME * cycle_speed + origin.x * 0.37 + origin.z * 0.61;
	VERTEX = rig_animate(VERTEX, UV, INSTANCE_CUSTOM.r, phase, 0.0);
	flash = INSTANCE_CUSTOM.g;
}

void fragment() {
	ALBEDO = mix(rig_albedo(COLOR.rgb), flash_color, flash);
	ROUGHNESS = 0.8;
}
