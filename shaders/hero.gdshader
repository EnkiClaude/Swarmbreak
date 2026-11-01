shader_type spatial;
// The player's model: walk and phase come from Player each frame; raise
// lifts the casting arm while attacking.

#include "res://shaders/rig.gdshaderinc"

uniform float walk = 0.0;
uniform float phase = 0.0;
uniform float raise = 0.0;

void vertex() {
	VERTEX = rig_animate(VERTEX, UV, walk, phase, raise);
}

void fragment() {
	ALBEDO = rig_albedo(COLOR.rgb);
	ROUGHNESS = 0.6;
}
