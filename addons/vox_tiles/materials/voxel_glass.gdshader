shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

#include "res://addons/vox_tiles/materials/voxel_colour.gdshaderinc"
#include "res://addons/vox_tiles/materials/voxel_editor.gdshaderinc"


// Glass that only looks like glass: it is opaque (cheaper, and you never see into the
// hollow tiles), and gets its look from the shader:
// - a faked reflection (no screen buffer): the reflected view direction picks between
//   sky, horizon and a dark city/street, with light diagonal streaks; at a grazing angle
//   glass reflects more (fresnel);
// - behind it a faked room per window (dark, a shade per room, lighter towards the
//   ceiling, lit at night in about a third), or for large glass surfaces (halls,
//   canopies: `interior` 0) a dim, tinted depth with the glass colour.

uniform float reflection : hint_range(0.0, 1.0) = 0.5;
uniform vec3 city : source_color = vec3(0.24, 0.25, 0.26);
// 1 = a window of a building (library_builder.gd sets it on tiles with little glass):
// a faked room behind it; 0 = a large glass surface: tinted depth
uniform float interior = 0.0;

// sky colours come from the day cycle (Project > Shader Globals)
global uniform vec4 zwervr_sky_top : source_color;
global uniform vec4 zwervr_sky_horizon : source_color;
global uniform float zwervr_night;

varying vec3 wpos;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v, n);
	vec3 surroundings = mix(zwervr_sky_horizon.rgb, zwervr_sky_top.rgb, smoothstep(0.05, 0.6, r.y));
	surroundings = mix(city, surroundings, smoothstep(-0.6, 0.08, r.y));
	// diagonal streaks of light that move with the viewing angle
	float streak = smoothstep(0.82, 1.0, sin((wpos.x + wpos.z) * 0.9 + wpos.y * 1.4 + r.x * 3.0) * 0.5 + 0.5);
	surroundings += streak * 0.12;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float s = editor_view() ? 0.0 : clamp(reflection + fres * 0.4, 0.0, 1.0);   // editor: no reflection
	vec3 glass = voxel_albedo(UV, COLOR);
	vec3 behind;
	vec3 glow = vec3(0.0);
	if (interior > 0.5) {
		// the room behind the window: one per ~2 m of facade and storey of 3 m
		vec2 room = floor(vec2((wpos.x + wpos.z) * 0.5, wpos.y / 3.0));
		float h1 = hash2(room);
		float h2 = hash2(room + 17.3);
		float up = fract(wpos.y / 3.0);   // height within the storey
		behind = mix(vec3(0.05, 0.045, 0.04), vec3(0.04, 0.045, 0.055), h1) * (0.6 + 0.8 * h2);
		behind *= 0.7 + 0.6 * smoothstep(0.2, 0.95, up);   // lighter towards the ceiling
		behind = mix(behind, glass * 0.3, 0.25);
		// at night about a third of the rooms have the light on
		float lit = step(0.66, h1) * zwervr_night * (editor_view() ? 0.0 : 1.0);
		glow = vec3(1.0, 0.78, 0.5) * (0.6 + 0.6 * h2) * lit;
	} else {
		// large glass: the glass colour, dimmed as if you looked into a deep space
		behind = glass * 0.35;
	}
	ALBEDO = behind * (1.0 - s);
	EMISSION = surroundings * s + glow * (1.0 - s);
	ROUGHNESS = editor_view() ? 1.0 : 0.04;
	METALLIC = 0.0;
	SPECULAR = editor_view() ? 0.0 : 0.6;
}
