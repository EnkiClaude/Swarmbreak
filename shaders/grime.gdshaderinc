// Procedural surface detail shared by every lit material, so surfaces read
// as worn stone, cloth and hide instead of flat plastic: value noise and
// fbm, a grain that breaks up flat colors, and grime that darkens toward
// the ground. Cheap: a few hashes per pixel, no textures.

float grime_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float grime_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(grime_hash(i), grime_hash(i + vec3(1, 0, 0)), f.x),
			mix(grime_hash(i + vec3(0, 1, 0)), grime_hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(grime_hash(i + vec3(0, 0, 1)), grime_hash(i + vec3(1, 0, 1)), f.x),
			mix(grime_hash(i + vec3(0, 1, 1)), grime_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float grime_fbm(vec3 p) {
	return grime_noise(p) * 0.6 + grime_noise(p * 2.7 + 11.0) * 0.4;
}

// Albedo with grain (fine and coarse) and darker, dirtier low parts.
// height: how high the point is above the ground (m); scale: noise size.
vec3 grime_apply(vec3 albedo, vec3 p, float height, float scale, float amount) {
	float grain = grime_fbm(p * scale);
	float blotch = grime_noise(p * scale * 0.18 + 3.7);
	vec3 col = albedo * mix(1.0, 0.62 + 0.62 * grain, amount);
	col *= mix(1.0, 0.7 + 0.45 * blotch, amount);
	float low = 1.0 - smoothstep(0.0, 1.2, height);
	col *= 1.0 - low * 0.35 * amount;
	return col;
}
