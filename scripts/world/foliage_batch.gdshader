shader_type spatial;
// Batched trees and shrubs (MultiMesh): the art pack's flat colour + baked shade, a gentle
// per-instance sway for crowns, and a dithered see-through hole around the local penguin
// (these batches can't take the per-object fade of occlusion_fader.gd).

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_shade = false;
uniform float roughness = 0.9;
uniform float sway_deg = 0.0;          // 0 for trunks
uniform float sway_period = 3.0;
uniform float hole_strength = 1.0;     // 0..1, animated per object by occlusion_fader.gd
uniform bool use_emission = false;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy = 0.0;

global uniform vec3 occlusion_target;  // local penguin chest, world space
global uniform float occlusion_radius; // screen-space radius (fraction of viewport height)

varying float v_depth_ok;

void vertex() {
	if (sway_deg > 0.0) {
		vec3 base = MODEL_MATRIX[3].xyz;
		float phase = fract(sin(dot(base.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
		float a = radians(sway_deg) * sin(TIME * 6.2831 / sway_period + phase);
		float b = radians(sway_deg) * 0.5 * sin(TIME * 6.2831 / (sway_period * 1.37) + phase * 1.7);
		// local origin is the crown pivot: bend proportional to height above it
		VERTEX.x += VERTEX.y * a;
		VERTEX.z += VERTEX.y * b;
	}
}

void fragment() {
	vec3 c = albedo.rgb;
	if (use_vertex_shade) {
		c *= COLOR.rgb;
	}
	ALBEDO = c;
	ROUGHNESS = roughness;
	if (use_emission) {
		EMISSION = emission_color.rgb * emission_energy;
	}
	// see-through hole: only fragments nearer the camera than the penguin, near its screen spot
	vec4 t = PROJECTION_MATRIX * VIEW_MATRIX * vec4(occlusion_target, 1.0);
	if (occlusion_radius > 0.0 && hole_strength > 0.0 && t.w > 0.0) {
		vec2 tp = (t.xy / t.w) * 0.5 + 0.5;
		tp.y = 1.0 - tp.y;
		vec2 d = (SCREEN_UV - tp) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		float target_depth = -(VIEW_MATRIX * vec4(occlusion_target, 1.0)).z;
		float r = length(d) / (occlusion_radius * hole_strength);
		if (r < 1.0 && -VERTEX.z < target_depth - 0.4) {
			// 4x4 ordered dither: keep about 30% inside, fading to solid at the rim
			int x = int(FRAGCOORD.x) % 4;
			int y = int(FRAGCOORD.y) % 4;
			float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
			float keep = mix(0.35, 1.0, smoothstep(0.55, 1.0, r));
			if ((bayer[y * 4 + x] + 0.5) / 16.0 > keep) {
				discard;
			}
		}
	}
}
