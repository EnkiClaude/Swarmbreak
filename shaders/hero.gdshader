shader_type spatial;
// The player's model: walk and phase come from Player each frame; raise
// lifts the casting arm while attacking. Parts painted with vertex alpha
// below 1 glow by (1 - alpha) * glow_power (gems, refined blades).

#include "res://shaders/rig.gdshaderinc"

uniform float walk = 0.0;
uniform float phase = 0.0;
uniform float raise = 0.0;
uniform float glow_power = 1.0;

void vertex() {
	VERTEX = rig_animate(VERTEX, UV, walk, phase, raise);
}

void fragment() {
	vec3 albedo = rig_albedo(COLOR.rgb);
	ALBEDO = albedo;
	ROUGHNESS = 0.6;
	EMISSION = albedo * (1.0 - COLOR.a) * glow_power;
}
