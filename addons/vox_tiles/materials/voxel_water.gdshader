shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

#include "res://addons/vox_tiles/materials/voxel_colour.gdshaderinc"
#include "res://addons/vox_tiles/materials/voxel_editor.gdshaderinc"


// Wavy water. The surface bobs with waves from several directions (so not in straight
// lines) and has light, moving patches and glitter. The waves run on in world
// coordinates over neighbouring tiles.
// Reflection: the reflected view ray is followed across the screen in a few steps
// (depth and screen buffer, no ray tracing). What it hits is reflected in the water;
// otherwise the sky is. (Godot's SSR gave no visible reflection here.)

uniform float wave_height : hint_range(0.0, 0.2) = 0.04;   // metres
uniform float wave_speed = 0.7;
uniform float wave_length = 6.0;                            // metres between two crests
uniform float patches : hint_range(0.0, 1.0) = 0.35;       // light moving patches
uniform float glitter : hint_range(0.0, 1.0) = 0.1;
uniform float reflection : hint_range(0.0, 1.0) = 0.17;        // for reflected objects
uniform float sky_reflection : hint_range(0.0, 1.0) = 0.06;    // for the sky
uniform float step_size = 1.0;                              // metres per step
uniform int steps = 12;
uniform float thickness = 2.0;                              // metres: how thick a hit object counts
uniform float ripple = 0.35;                                // distortion of the reflection by the waves

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth : hint_depth_texture, filter_nearest, repeat_disable;

global uniform vec4 zwervr_sky_top : source_color;
global uniform vec4 zwervr_sky_horizon : source_color;

varying float is_top;
varying vec3 wpos;

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// waves from four directions with different lengths: no straight lanes
float wave(vec2 p, float t) {
	float k = 6.2831 / wave_length;
	float g = sin(dot(p, vec2(0.94, 0.34)) * k + t) * 0.35;
	g += sin(dot(p, vec2(-0.42, 0.91)) * k * 1.37 - t * 0.83) * 0.28;
	g += sin(dot(p, vec2(0.68, -0.73)) * k * 0.71 + t * 0.61) * 0.22;
	g += sin(dot(p, vec2(-0.99, -0.12)) * k * 2.13 + t * 1.27) * 0.15;
	return g;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	is_top = step(0.5, NORMAL.y);
	float t = TIME * wave_speed;
	if (!editor_view()) {   // flat, still water in the editor
		VERTEX.y += wave(w.xz, t) * wave_height * is_top;
		// the normal follows the wave, so lighting and reflection move with it
		float e = 0.1;
		float hx = (wave(w.xz + vec2(e, 0.0), t) - wave(w.xz - vec2(e, 0.0), t)) / (2.0 * e) * wave_height;
		float hz = (wave(w.xz + vec2(0.0, e), t) - wave(w.xz - vec2(0.0, e), t)) / (2.0 * e) * wave_height;
		NORMAL = mix(NORMAL, normalize(vec3(-hx, 1.0, -hz)), is_top);
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 to_screen(vec3 w, mat4 view, mat4 proj) {
	vec4 c = proj * (view * vec4(w, 1.0));
	return c.xy / c.w * 0.5 + 0.5;
}

void fragment() {
	float t = TIME * wave_speed;
	// light patches: two layers of noise slowly sliding past each other
	float v1 = noise(wpos.xz * 0.35 + vec2(t * 0.13, t * 0.07));
	float v2 = noise(wpos.xz * 0.9 - vec2(t * 0.09, -t * 0.11));
	float patch = smoothstep(0.45, 0.95, v1 * 0.6 + v2 * 0.4);
	// glitter: small, quickly changing points of light
	float gl = smoothstep(0.86, 0.98, noise(wpos.xz * 3.1 + vec2(t * 0.5, -t * 0.4)) * noise(wpos.xz * 2.3 - vec2(t * 0.3)) * 1.6);
	vec3 base = voxel_albedo(UV, COLOR) * (0.55 + patch * patches * 0.35);

	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 view_dir = -normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	// the waves distort the reflection a bit more than the lighting
	vec3 nr = normalize(mix(vec3(0.0, 1.0, 0.0), n, 1.0 + ripple * 4.0));
	vec3 r = reflect(view_dir, nr);
	r.y = abs(r.y);
	vec3 colour = mix(zwervr_sky_horizon.rgb, zwervr_sky_top.rgb, smoothstep(0.0, 0.7, r.y));
	float hit = 0.0;
	if (is_top > 0.5) {
		for (int i = 1; i <= steps; i++) {
			vec3 q = wpos + r * (float(i) * step_size);
			vec2 uv = to_screen(q, VIEW_MATRIX, PROJECTION_MATRIX);
			if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
				break;
			}
			float d = texture(depth, uv).r;
			vec4 v = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, d, 1.0);
			float behind = v.z / v.w - (VIEW_MATRIX * vec4(q, 1.0)).z;   // > 0: the ray lies behind the geometry
			if (behind > 0.0 && behind < thickness) {
				colour = texture(screen, uv).rgb;
				hit = 1.0;
				break;
			}
		}
	}
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float s = clamp(mix(sky_reflection, reflection, hit) + fres * 0.05, 0.0, 1.0) * is_top;
	ALBEDO = base * (1.0 - s);
	EMISSION = colour * s + vec3(gl * glitter * 0.6) * is_top;
	ROUGHNESS = 0.35;
	SPECULAR = 0.15;
}
