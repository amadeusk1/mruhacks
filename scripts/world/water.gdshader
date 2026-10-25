shader_type spatial;
// Stylised water for the sea and the stream (Art Docs/Water and Stream.md). Opaque and depth-texture
// free, so it runs the same in the Compatibility (web) renderer.
//  Sea: shore foam and depth come from Models/world/water_shore.png (R foam, G depth), sampled in
//       world XZ; drifting caustic cells; foam that laps in and out along the shore and round rocks.
//  Stream: UV = (across 0..1, metres downstream), UV2 = (foam 0..1, falls 0/1) from art/blender/world/
//       stream.py; cells and streaks scroll with the flow, white boil under each fall, sheets streak fast.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform bool stream = false;
uniform sampler2D shore_tex : filter_linear, repeat_disable, hint_default_black;   // data, not colour: no sRGB decode
uniform vec2 shore_min = vec2(-50.0, -50.0);   // world XZ of the texture's top-left (north-west) corner
uniform float shore_size = 100.0;
uniform vec3 deep_color : source_color = vec3(0.06, 0.52, 0.72);
uniform vec3 shallow_color : source_color = vec3(0.30, 0.80, 0.86);
uniform vec3 cell_color : source_color = vec3(0.62, 0.93, 0.96);
uniform vec3 foam_color : source_color = vec3(0.96, 0.99, 1.0);
uniform float flow_speed = 0.6;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Distance to the nearest cell border (F2 - F1): thin bright lines like the concepts' water cells.
float cells(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 19.19));
			o = 0.5 + 0.4 * sin(t + 6.2831 * o);
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec3 col;
	float foam = 0.0;
	if (stream) {
		float across = UV.x;
		float s = 1.0 - UV.y;      // glTF stores V flipped
		float fall = 1.0 - UV2.y;
		float edge = abs(across - 0.5) * 2.0;           // 0 mid-channel .. 1 ribbon edge, under the bank
		float speed = flow_speed * (1.0 + fall * 3.5);
		col = mix(shallow_color, deep_color, (1.0 - smoothstep(0.15, 0.8, edge)) * 0.8);
		float c = cells(vec2(across * 2.6, s * 0.9 - t * speed) * 1.5, t * 0.8);
		col = mix(col, cell_color, (1.0 - smoothstep(0.0, 0.09, c)) * 0.4);
		float streak = vnoise(vec2(across * 16.0, s * 1.3 - t * speed * 2.0));
		col = mix(col, cell_color, smoothstep(0.7, 0.9, streak) * 0.3);
		float wobble = (vnoise(vec2(s * 2.5 - t * 1.4, across * 5.0)) - 0.5) * 0.14;
		float bank = smoothstep(0.62, 0.74, edge + wobble);   // the waterline is at about 0.72
		float boil = UV2.x * smoothstep(0.3, 0.62, vnoise(vec2(across * 9.0, s * 3.0 - t * 2.4)) + UV2.x * 0.35);
		float sheet = fall * smoothstep(0.4, 0.66, vnoise(vec2(across * 24.0, s * 5.0 - t * 6.0)));
		col = mix(col, vec3(0.74, 0.93, 0.97), fall * 0.5);
		foam = max(max(bank * 0.8, boil), sheet);
	} else {
		vec4 sh = texture(shore_tex, (world_pos.xz - shore_min) / shore_size);
		float depth = sh.g;
		col = mix(shallow_color, deep_color, smoothstep(0.0, 0.85, depth));
		float c = cells(world_pos.xz * 0.45 + vec2(t * 0.05, t * 0.03), t * 0.6);
		col = mix(col, cell_color, (1.0 - smoothstep(0.0, 0.08, c)) * mix(0.4, 0.14, depth));
		float n = vnoise(world_pos.xz * 0.9 + t * 0.15);
		float lap = sh.r + (n - 0.5) * 0.35 + sin(t * 1.1 + sh.r * 7.0) * 0.07;
		foam = smoothstep(0.62, 0.7, lap);
		float ring = smoothstep(0.4, 0.44, lap) * (1.0 - smoothstep(0.46, 0.5, lap));   // a second, thinner line further out
		foam = max(foam, ring * 0.65);
	}
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, vec3(0.86, 0.97, 1.0), fres * 0.35);
	col = mix(col, foam_color, foam);
	ALBEDO = col;
	ROUGHNESS = mix(0.2, 0.9, foam);
	SPECULAR = 0.35;
	EMISSION = col * 0.08;   // keeps the water clear and bright in shade
}
