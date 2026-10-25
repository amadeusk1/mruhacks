shader_type canvas_item;
// Radial speed streaks toward the screen edges; strength 0 draws nothing.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 d = UV - vec2(0.5, 0.45);
	float r = length(d);
	float a = atan(d.y, d.x);
	float ray = floor(a * 38.0);
	float seed = hash(ray);
	float t = fract(TIME * (1.6 + seed) + seed);
	float streak = smoothstep(0.0, 0.02, fract(r * 1.4 - t) ) * (1.0 - smoothstep(0.02, 0.14, fract(r * 1.4 - t)));
	float on = step(0.55, seed) * smoothstep(0.32, 0.62, r);
	COLOR = vec4(1.0, 1.0, 1.0, streak * on * strength * 0.55);
}
