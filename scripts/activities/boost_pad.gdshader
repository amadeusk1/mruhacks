shader_type spatial;
// Sled Hill boost pad: glowing chevrons that scroll downhill (local -Z, the plane's -V side).
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform vec4 base : source_color = vec4(0.94, 0.39, 0.36, 0.9);
uniform vec4 glow : source_color = vec4(1.0, 0.9, 0.45, 1.0);

void fragment() {
	vec2 uv = UV;
	float x = abs(uv.x - 0.5) * 2.0;
	float band = fract(uv.y * 3.0 + x * 0.55 + TIME * 1.6);
	float chevron = smoothstep(0.42, 0.5, band) - smoothstep(0.72, 0.8, band);
	float edge = smoothstep(0.86, 0.9, x) + smoothstep(0.04, 0.0, uv.y) + smoothstep(0.96, 1.0, uv.y);
	vec3 c = mix(base.rgb, glow.rgb, chevron);
	c = mix(c, vec3(1.0), clamp(edge, 0.0, 1.0) * 0.8);
	ALBEDO = c;
	ALPHA = base.a;
}
