shader_type spatial;
// Overlay on the local penguin while something covers it: soft teal only where the scene is
// clearly in front of the bird. The penguin's own hat, clothes, beak and flippers are nearer
// than its body by a few cm, so an occluder must be at least `min_gap` m closer (linear view
// depth) to count; otherwise the bird tinted itself standing in the open.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_mix;

uniform vec4 tint : source_color = vec4(0.25, 0.75, 0.78, 0.4);
uniform float min_gap = 0.45;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float scene_dist = -v.z / v.w;   // metres in front of the camera
	float own_dist = -VERTEX.z;
	if (scene_dist > own_dist - min_gap) {
		discard;
	}
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
