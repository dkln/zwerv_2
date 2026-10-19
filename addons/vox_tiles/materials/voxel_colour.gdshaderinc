// Colour of a voxel face, shared by the voxel shaders.
//
// Textured tiles (use_atlas, set by addons/vox_tiles/atlas.gd): up close the exact voxel
// colour from the library's texture atlas, always at full resolution (no mipmaps, so
// nothing from neighbouring tiles in the atlas bleeds in); from afar, where a texel is
// smaller than a pixel, it fades to the face's average colour stored in the vertex
// colour. Vertex alpha = ambient occlusion.
// Untextured tiles: the vertex colour holds colour * AO.
uniform sampler2D albedo_atlas : source_color, hint_default_white, filter_nearest, repeat_disable;
uniform bool use_atlas = false;

vec3 voxel_albedo(vec2 uv, vec4 color) {
	if (!use_atlas) {
		return color.rgb;
	}
	vec2 texels = uv * vec2(textureSize(albedo_atlas, 0));
	float footprint = max(length(dFdx(texels)), length(dFdy(texels)));   // texels per pixel
	vec3 near = textureLod(albedo_atlas, uv, 0.0).rgb;
	return mix(near, color.rgb, smoothstep(0.6, 1.6, footprint)) * color.a;
}
