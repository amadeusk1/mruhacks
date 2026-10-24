shader_type canvas_item;
render_mode blend_add;

// Northern lights hanging along the top of the screen at night. The gameplay camera looks
// steeply down, so the sky itself is never in frame; this is the glimpse of it.

uniform float strength = 0.0;
uniform float t = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float x = UV.x;
	float wave = sin(x * 5.0 + t * 0.35) * 0.05 + sin(x * 11.0 - t * 0.5) * 0.025;
	float y = UV.y + wave;
	float band = smoothstep(0.0, 0.05, y) * (1.0 - smoothstep(0.02, 0.36, y));
	float rays = 0.45 + 0.55 * noise(vec2(x * 38.0, t * 0.45));
	rays *= 0.55 + 0.45 * noise(vec2(x * 7.0 + t * 0.12, y * 3.0));
	vec3 green = vec3(0.15, 1.0, 0.55);
	vec3 violet = vec3(0.7, 0.3, 1.0);
	vec3 col = mix(green, violet, smoothstep(0.06, 0.32, y + 0.1 * sin(x * 3.0 + t * 0.2)));
	float a = band * rays * strength;
	COLOR = vec4(col, a);  // additive blending already multiplies the colour by alpha
}
