shader_type spatial;
// Overlay on the local penguin while something covers it: soft teal only where the scene's
// depth is in front of the bird, so the visible parts stay untouched.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_mix;

uniform vec4 tint : source_color = vec4(0.25, 0.75, 0.78, 0.4);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

void fragment() {
	float scene = texture(depth_tex, SCREEN_UV).r;
	float own = FRAGCOORD.z;
	// Godot 4 uses reversed Z: larger is nearer. Occluded when the scene is nearer than us.
	if (scene <= own + 0.00002) {
		discard;
	}
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
