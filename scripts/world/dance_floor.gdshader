shader_type spatial;
render_mode unshaded, cull_disabled;

// Beat-driven checker dance floor. `beat` is the shared beat counter; `party` (0..1) is how
// many penguins are dancing. Tile colours step on every beat and pulse on the downbeat.

uniform float beat = 0.0;
uniform float party : hint_range(0.0, 1.0) = 0.3;
uniform float tile = 0.575;

varying vec3 lp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 palette(float t) {
	return 0.55 + 0.45 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 g = floor(lp.xz / tile);
	vec2 f = fract(lp.xz / tile);
	float edge = smoothstep(0.0, 0.06, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
	float step_i = floor(beat);
	float phase = fract(beat);
	float checker = mod(g.x + g.y + step_i, 2.0);
	float flash = 1.0 - phase;
	vec3 col = palette(hash(g) * 0.6 + step_i * 0.11);
	float lit = mix(0.12, 1.0, checker) * (0.45 + 0.55 * flash);
	// a ripple that runs out from the middle on every beat
	float r = length(lp.xz);
	float ripple = 1.0 - smoothstep(0.0, 0.35, abs(r - phase * 3.0));
	lit += ripple * 0.6;
	lit *= mix(0.4, 1.0, party);
	vec3 base = vec3(0.03, 0.04, 0.09);
	col = pow(col, vec3(2.2));  // deeper, more saturated colours; the pastel palette washes out in daylight
	ALBEDO = mix(base, base + col * lit * 1.1, edge);
}
