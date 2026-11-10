// The plain materials of the voxel figures (scripts/player/player_model.gd, MATERIALS: skin,
// eyes, leather, plastic, metal, glass): the vertex colour (sRGB, graded, with the face
// shading and the corner occlusion baked in) with the bevel of each voxel (voxel_bevel)
// and its own roughness, metallic, specular and rim. The fabrics are figure.gdshader.
shader_type spatial;
render_mode cull_disabled;

#include "res://scripts/player/voxel_bevel.gdshaderinc"

uniform float roughness_value : hint_range(0.0, 1.0) = 0.6;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float specular_value : hint_range(0.0, 1.0) = 0.5;
uniform float rim_value : hint_range(0.0, 1.0) = 0.0;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.6;

vec3 to_linear(vec3 colour) {
	return mix(colour / 12.92, pow((colour + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), colour));
}

void fragment() {
	ALBEDO = clamp(to_linear(COLOR.rgb) * voxel_bevel(UV), 0.0, 1.0);
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	SPECULAR = specular_value;
	RIM = rim_value;
	RIM_TINT = rim_tint;
}
