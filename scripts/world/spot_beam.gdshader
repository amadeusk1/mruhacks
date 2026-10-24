shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// Soft stage-light cone: bright at the lamp, fading toward the floor.

uniform vec3 tint : source_color = vec3(1.0, 0.4, 0.9);
uniform float intensity = 0.4;

void fragment() {
	// UV.y runs 0 at the wide end to 1 at the lamp on the cylinder side
	float along = clamp(UV.y, 0.0, 1.0);
	float rim = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	ALBEDO = tint;
	ALPHA = intensity * (0.12 + 0.88 * along) * (0.35 + 0.65 * rim);
}
