shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#include "res://addons/vox_tiles/materials/voxel_colour.gdshaderinc"
#include "res://addons/vox_tiles/materials/voxel_editor.gdshaderinc"


uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.35;
uniform float emission_energy = 0.0;
// 1 = this surface follows the tint map and variation (0 for e.g. lamps)
uniform float tintable = 1.0;
// voxel structure: light edges and small brightness differences per voxel
uniform float voxel_edge : hint_range(0.0, 0.5) = 0.0;
uniform float voxel_noise : hint_range(0.0, 0.3) = 0.0;   // the colour variation is in the .vox itself
uniform float voxel_size = 0.125;
// bobbing: floating objects follow the same waves as the water
// (keep wave_height, wave_speed and wave_length equal to voxel_water.tres)
uniform float wave_height = 0.04;
uniform float wave_speed = 0.7;
uniform float wave_length = 6.0;
uniform float roll = 0.035;             // radians: rolling and pitching of the object
uniform float heave = 0.0;              // metres: extra up and down of the whole object
// water plants: every bit bobs in its own place (not as one whole), and everything
// below `from_height` (local y, the bottom and the water of the tile) stays put
uniform float per_place = 0.0;
uniform float from_height = -100.0;

// Global tint settings (see Project > Shader Globals and the TintKaart node).
global uniform sampler2D zwervr_tint_map : filter_nearest, repeat_disable;
global uniform vec4 zwervr_tint_area;      // x0, z0, width, depth (metres)
global uniform float zwervr_variation;     // random colour variation per 4 x 4 m cell (0..1)

varying vec3 wpos;
varying vec3 vpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// the same wave as in voxel_water.gdshader
float wave(vec2 p, float t) {
	float k = 6.2831 / wave_length;
	float g = sin(dot(p, vec2(0.94, 0.34)) * k + t) * 0.35;
	g += sin(dot(p, vec2(-0.42, 0.91)) * k * 1.37 - t * 0.83) * 0.28;
	g += sin(dot(p, vec2(0.68, -0.73)) * k * 0.71 + t * 0.61) * 0.22;
	g += sin(dot(p, vec2(-0.99, -0.12)) * k * 2.13 + t * 1.27) * 0.15;
	return g;
}

void vertex() {
	float t = TIME * wave_speed;
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float moves = step(from_height, VERTEX.y);
	// up and down with the water at this place
	float dy = wave(w.xz, t) * wave_height;
	// slow rolling and pitching around the middle of the object
	vec2 place = mix(origin.xz, floor(w.xz), per_place);
	float phase = place.x * 0.31 + place.y * 0.17;
	float rx = sin(TIME * 0.9 + phase) * roll;
	float rz = sin(TIME * 0.7 + phase * 1.7) * roll * 0.7;
	dy += sin(TIME * 1.1 + phase * 2.3) * heave;
	dy += VERTEX.x * rz + VERTEX.z * rx;
	VERTEX.y += editor_view() ? 0.0 : dy * moves;   // still in the editor
	// shift slightly inwards, so edge voxels fall in the right cell
	wpos = (MODEL_MATRIX * vec4(VERTEX - NORMAL * 0.01, 1.0)).xyz;
	vpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = voxel_albedo(UV, COLOR);
	if (tintable > 0.5) {
		// voxel structure: position within the voxel on this face
		vec3 an = abs(wnorm);
		vec2 uv = an.x > 0.5 ? vpos.zy : (an.y > 0.5 ? vpos.xz : vpos.xy);
		vec2 f = abs(fract(uv / voxel_size) - 0.5) * 2.0;
		float edge = smoothstep(0.78, 1.0, max(f.x, f.y));
		vec3 voxel_cell = floor((vpos - wnorm * 0.02) / voxel_size);
		float r = hash3(voxel_cell) - 0.5;
		c *= (1.0 - edge * voxel_edge) * (1.0 + r * voxel_noise * 2.0);
		// variation and tint per 4 m cell
		vec2 cell = floor(wpos.xz / 4.0);
		float r1 = hash(cell) - 0.5;
		float r2 = hash(cell + 17.3) - 0.5;
		c *= 1.0 + r1 * zwervr_variation * 0.35;
		c = mix(c, c * vec3(1.0 + r2 * 0.3, 1.0, 1.0 - r2 * 0.3), zwervr_variation);
		if (zwervr_tint_area.z > 0.0) {
			vec2 tuv = (wpos.xz - zwervr_tint_area.xy) / zwervr_tint_area.zw;
			if (tuv.x >= 0.0 && tuv.y >= 0.0 && tuv.x < 1.0 && tuv.y < 1.0) {
				vec4 t = texture(zwervr_tint_map, tuv);
				vec3 tint = t.rgb * 2.0;
				c = mix(c, c * tint, t.a);
			}
		}
	}
	if (editor_view()) {
		c *= 1.0 - 0.6 * tile_border(vpos, wnorm);
	}
	ALBEDO = c;
	ROUGHNESS = editor_view() ? 1.0 : roughness;   // editor: matte, no reflections
	METALLIC = editor_view() ? 0.0 : metallic;
	SPECULAR = editor_view() ? 0.0 : specular;
	EMISSION = voxel_albedo(UV, COLOR) * emission_energy;
}
