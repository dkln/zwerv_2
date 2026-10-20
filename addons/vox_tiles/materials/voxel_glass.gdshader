shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;

#include "res://addons/vox_tiles/materials/voxel_colour.gdshaderinc"
#include "res://addons/vox_tiles/materials/voxel_editor.gdshaderinc"


// Glass with a faked reflection (cheap, no screen buffer): the reflected view direction
// picks between sky, horizon and a dark city/street, with light diagonal streaks. Seen
// at a grazing angle glass reflects more (fresnel).

uniform float opacity : hint_range(0.0, 1.0) = 0.38;
uniform float reflection : hint_range(0.0, 1.0) = 0.5;
uniform vec3 city : source_color = vec3(0.24, 0.25, 0.26);

// sky colours come from the day cycle (Project > Shader Globals)
global uniform vec4 zwervr_sky_top : source_color;
global uniform vec4 zwervr_sky_horizon : source_color;

varying vec3 wpos;

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
	ALBEDO = voxel_albedo(UV, COLOR) * 0.7 * (1.0 - s);
	EMISSION = surroundings * s;
	ROUGHNESS = editor_view() ? 1.0 : 0.04;
	METALLIC = 0.0;
	SPECULAR = editor_view() ? 0.0 : 0.6;
	ALPHA = clamp(opacity + s * 0.35 + fres * 0.3, 0.0, 0.95);
}
