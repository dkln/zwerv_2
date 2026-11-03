shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_burley;

#include "res://addons/vox_tiles/materials/voxel_colour.gdshaderinc"
#include "res://addons/vox_tiles/materials/voxel_editor.gdshaderinc"
#include "res://addons/vox_tiles/materials/voxel_fade.gdshaderinc"


// Makes flags wave. The further a voxel is from the pole (the middle of the model),
// the more it moves.
uniform float speed = 3.0;
uniform float wavelength = 1.6;
uniform float strength = 0.12;
uniform float pole_distance = 0.15;

void vertex() {
	vec2 d = VERTEX.xz;
	float r = length(d);
	float f = clamp((r - pole_distance) / 1.2, 0.0, 1.0);
	vec2 dir = r > 0.001 ? d / r : vec2(1.0, 0.0);
	vec2 across = vec2(-dir.y, dir.x);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float g = sin(TIME * speed - r * wavelength * 3.0 + wp.x * 0.3 + wp.z * 0.2);
	if (!editor_view()) {   // the editor shows the flag hanging still
		VERTEX.xz += across * g * strength * f;
		VERTEX.y += cos(TIME * speed * 0.7 - r * 2.0) * strength * 0.25 * f;
	}
}

void fragment() {
#ifdef ZWERVR_FADE
	if (faded_out(VERTEX, NORMAL, INV_VIEW_MATRIX, PROJECTION_MATRIX, FRAGCOORD.xy, vec4(0.0))) {
		discard;   // a building in front of the followed vehicle (voxel_fade.gdshaderinc)
	}
#endif
	ALBEDO = voxel_albedo(UV, COLOR);
	ROUGHNESS = editor_view() ? 1.0 : 0.85;
	SPECULAR = editor_view() ? 0.0 : 0.2;
}
