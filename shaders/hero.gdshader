shader_type spatial;
// The player's model: walk and phase come from Player each frame; raise
// lifts the casting arm while attacking. Parts painted with vertex alpha
// below 1 glow by (1 - alpha) * glow_power (gems, refined blades).

#include "res://shaders/rig.gdshaderinc"
#include "res://shaders/grime.gdshaderinc"

uniform float walk = 0.0;
uniform float phase = 0.0;
uniform float raise = 0.0;
uniform float glow_power = 1.0;
uniform float detail = 0.6;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	VERTEX = rig_animate(VERTEX, UV, walk, phase, raise);
}

void fragment() {
	vec3 albedo = rig_albedo(COLOR.rgb);
	// Glowing parts stay clean; the rest gets grain and wear.
	ALBEDO = mix(grime_apply(albedo, local_pos, local_pos.y, 14.0, detail), albedo, 1.0 - COLOR.a);
	ROUGHNESS = 0.65;
	EMISSION = albedo * (1.0 - COLOR.a) * glow_power;
}
