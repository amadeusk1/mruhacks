shader_type spatial;
render_mode unshaded;

// Mirror-tile ball: every facet flashes its own colour as the ball turns and the beat lands.

uniform float beat = 0.0;
uniform float party : hint_range(0.0, 1.0) = 0.3;

varying vec3 lp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	lp = normalize(VERTEX);
}

void fragment() {
	vec2 ang = vec2(atan(lp.x, lp.z), asin(clamp(lp.y, -1.0, 1.0)));
	vec2 cell = floor(ang * vec2(9.0, 9.0));
	vec2 f = fract(ang * vec2(9.0, 9.0));
	float gap = smoothstep(0.0, 0.1, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
	float h = hash(cell);
	float sparkle = step(0.55, fract(h * 7.0 + beat * 0.5)) * (0.6 + 0.4 * (1.0 - fract(beat)));
	vec3 tint = 0.6 + 0.4 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + h + beat * 0.07));
	vec3 base = vec3(0.55, 0.6, 0.72) * (0.55 + 0.45 * h);
	ALBEDO = mix(vec3(0.08), mix(base, tint * 1.6, sparkle * mix(0.4, 1.0, party)), gap);
}
