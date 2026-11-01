// Walk animation for meshes built by ModelBuilder. UV.x is the limb group
// (0 body, 1 left leg, 2 right leg, 3 left arm, 4 right arm, 5 floating) and
// UV.y the height of the joint the limb swings around (about the X axis, so
// legs and arms swing forward and back). Left leg and right arm move
// together, as people walk. walk is 0 standing to 1 at full speed; phase
// advances the cycle. raise lifts the right arm forward (casting).

uniform float stride_swing = 0.6;
uniform float body_bob = 0.05;

vec3 rig_swing(vec3 v, float joint, float angle) {
	v.y -= joint;
	float c = cos(angle);
	float s = sin(angle);
	v = vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
	v.y += joint;
	return v;
}

vec3 rig_animate(vec3 v, vec2 rig, float walk, float phase, float raise) {
	int limb = int(rig.x + 0.5);
	float joint = rig.y;
	float swing = sin(phase) * stride_swing * walk;
	if (limb == 1 || limb == 4) {
		v = rig_swing(v, joint, swing);
	} else if (limb == 2 || limb == 3) {
		v = rig_swing(v, joint, -swing);
	}
	if (limb == 4 && raise > 0.0) {
		// Positive angles swing toward -Z: the arm comes up in front.
		v = rig_swing(v, joint, raise * 1.4);
	}
	if (limb == 5) {
		v.y += sin(phase * 0.5) * 0.08;
	}
	v.y += abs(sin(phase)) * body_bob * walk;
	return v;
}

// Vertex colors are sRGB; light in linear.
vec3 rig_albedo(vec3 srgb) {
	return pow(srgb, vec3(2.2));
}
