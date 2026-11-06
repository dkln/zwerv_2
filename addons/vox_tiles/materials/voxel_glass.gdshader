shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

#include "res://addons/vox_tiles/materials/voxel_colour.gdshaderinc"
#include "res://addons/vox_tiles/materials/voxel_editor.gdshaderinc"
#include "res://addons/vox_tiles/materials/voxel_fade.gdshaderinc"


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
// roughness for the sun's highlight: low = a small sharp glint, higher = a broader
// sheen visible over more angles (vehicle windows, scripts/vehicles/vehicle.gd)
uniform float glint_roughness : hint_range(0.0, 1.0) = 0.04;
// brightness of what is behind large glass (lower = darker tinted glass)
uniform float depth : hint_range(0.0, 1.0) = 0.35;
// strength of the diagonal streaks of light (in the faked reflection)
uniform float streaks : hint_range(0.0, 1.0) = 0.12;
// a light sheen in those same streaks, on top of everything: a flat voxel pane has one
// normal, so the sun's highlight is even over it; the sheen makes it read as glass
uniform float sheen : hint_range(0.0, 1.0) = 0.0;
// 0 = the streaks lie still in the world (buildings); 1 = they lie on the object itself,
// finer (vehicles: on a moving car world streaks would slide over the windows)
uniform float streaks_on_object : hint_range(0.0, 1.0) = 0.0;
// vehicles: a faked mirror image of the town, a row of buildings against the sky that slides
// over the glass as it drives. As if the pane leans back (`pane_lean`): seen from above a
// straight pane would only mirror the road.
uniform float passing_surroundings : hint_range(0.0, 1.0) = 0.0;
uniform float pane_lean = 0.6;

// sky colours come from the day cycle (Project > Shader Globals)
global uniform vec4 zwervr_sky_top : source_color;
global uniform vec4 zwervr_sky_horizon : source_color;
global uniform float zwervr_night;

varying vec3 wpos;
varying vec3 object_position;   // the vertex in the object's own space (metres)

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

#ifdef ZWERVR_FADE
// the building a baked facade detail hangs on (voxel_fade.gdshaderinc)
varying vec4 fade_owner;
#endif

// What a leaning vehicle pane mirrors: sky, with buildings of different heights in a row
// along the mirrored direction, darker and with lit windows at night, and the road below.
vec3 passing_town(vec3 normal_world, vec3 view_world, vec3 world_position, float height_on_object, float strength) {
	vec3 mirrored = reflect(-view_world, normalize(normal_world + vec3(0.0, pane_lean, 0.0)));
	vec3 sky = mix(zwervr_sky_horizon.rgb, zwervr_sky_top.rgb, smoothstep(0.05, 0.7, mirrored.y));
	vec2 flat_direction = normalize(mirrored.xz + vec2(0.0001));
	float along_street = dot(world_position.xz, vec2(-flat_direction.y, flat_direction.x)) * 0.6 + atan(mirrored.z, mirrored.x) * 3.0;
	float building = floor(along_street);
	float within = fract(along_street);
	float softness = max(fwidth(along_street) * 1.5, 0.02);
	float blend = smoothstep(0.0, softness, within);
	float height_here = mix(hash2(vec2(building - 1.0, 3.7)), hash2(vec2(building, 3.7)), blend);
	float shade = mix(hash2(vec2(building - 1.0, 9.1)), hash2(vec2(building, 9.1)), blend);
	float roof_line = mix(0.12, 0.62, height_here);
	float looked_at = mirrored.y + height_on_object * 0.05;
	float in_building = 1.0 - smoothstep(roof_line - 0.03, roof_line + 0.03, looked_at);
	vec3 town = city * mix(0.45, 1.1, shade) * mix(1.0, 0.25, zwervr_night);
	vec2 window_cell = vec2(along_street * 5.0, looked_at * 34.0);
	float lit_window = step(0.72, hash2(floor(window_cell))) * zwervr_night;
	town += vec3(1.0, 0.8, 0.55) * lit_window * 0.55;
	vec3 mirrored_scene = mix(sky, town, in_building * strength);
	return mix(city * 0.5, mirrored_scene, smoothstep(-0.25, 0.02, looked_at));
}

void vertex() {
#ifdef ZWERVR_FADE
	fade_owner = fade_owner_from(CUSTOM0);
#endif
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	object_position = VERTEX;
}

void fragment() {
#ifdef ZWERVR_FADE
	if (faded_out(VERTEX, NORMAL, INV_VIEW_MATRIX, PROJECTION_MATRIX, FRAGCOORD.xy, fade_owner)) {
		discard;   // a building in front of the followed vehicle (voxel_fade.gdshaderinc)
	}
#endif
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v, n);
	vec3 surroundings = mix(zwervr_sky_horizon.rgb, zwervr_sky_top.rgb, smoothstep(0.05, 0.6, r.y));
	if (passing_surroundings > 0.0 && !editor_view()) {
		surroundings = passing_town(n, v, wpos, object_position.y, passing_surroundings);
	} else {
		surroundings = mix(city, surroundings, smoothstep(-0.6, 0.08, r.y));
	}
	// diagonal streaks of light that move with the viewing angle
	vec3 streak_position = streaks_on_object > 0.5 ? object_position * 4.0 : wpos;
	float streak = smoothstep(0.82, 1.0, sin((streak_position.x + streak_position.z) * 0.9 + streak_position.y * 1.4 + r.x * 3.0) * 0.5 + 0.5);
	surroundings += streak * streaks;
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
		behind = glass * depth;
	}
	ALBEDO = behind * (1.0 - s);
	EMISSION = surroundings * s + glow * (1.0 - s) + vec3(streak * sheen) * (editor_view() ? 0.0 : 1.0);
	ROUGHNESS = editor_view() ? 1.0 : glint_roughness;
	METALLIC = 0.0;
	SPECULAR = editor_view() ? 0.0 : mix(0.6, 1.0, smoothstep(0.04, 0.3, glint_roughness));
}
