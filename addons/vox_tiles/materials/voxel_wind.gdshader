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
// wind: the higher up in the model, the more it moves (the foot stands still)
uniform float wind_strength = 0.06;     // metres of sway at the top
uniform float wind_speed = 1.1;
uniform float wind_height = 8.0;        // height (m) above wind_base at which the full sway is reached
uniform float wind_base = 0.0;          // height (m, tile-local) below which nothing sways (the ground of a flower bed)

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

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float f = clamp((VERTEX.y - wind_base) / wind_height, 0.0, 1.0);
	f *= f;
	float t = TIME * wind_speed + phase;
	vec3 local = VERTEX;
	if (!editor_view()) {   // the editor shows the trees standing still
		VERTEX.x += (sin(t) * 0.7 + sin(t * 2.3 + local.y) * 0.3) * wind_strength * f;
		VERTEX.z += (cos(t * 0.8) * 0.6 + sin(t * 1.9 + local.x) * 0.25) * wind_strength * f;
	}
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
