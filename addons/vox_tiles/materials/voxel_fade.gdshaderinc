// See-through buildings, shared by the voxel shaders: scripts/world/building_fade.gd (the
// Doorkijk node) fades out the buildings that stand between the followed vehicle and the
// camera. The shaders only test it when compiled with ZWERVR_FADE: a shader that can
// discard pixels is much slower on tile-based GPUs (Apple), so building_fade.gd gives
// only the meshes of fading buildings a copy of their material with that define.
// Per 4 x 4 m cell the texture holds how far the building on it has faded (0..1); every
// cell of a building holds the same value, so a building fades as a whole. Faded
// pixels are left out in an even screen-door pattern (the picture stays opaque: no
// sorting, and the upscaler's smoothing turns the pattern into a see-through look).
// The building's shadow stays: the shadow pass (an orthographic projection) is skipped.
// Bay windows, shop fronts, awnings and signs stick out of their building's cell into
// the street; scripts/world/layer_baker.gd gives every vertex of the merged buildings
// (and of the facade details baked into them) the centre of the cell it belongs to in
// CUSTOM0, so it fades with its own building, as a whole. Shaders decode it in vertex()
// with fade_owner_from(CUSTOM0) into a varying; vec4(0.0) = none, then the cell the
// pixel is in is used.
// Nothing below this height fades: the street, and for the Grond layer (whose decks fade,
// building_fade.gd compiles it with a higher floor) also the foundations under buildings.
#ifndef ZWERVR_FADE_FLOOR
#define ZWERVR_FADE_FLOOR 0.3
#endif
global uniform sampler2D zwervr_fade_map : filter_nearest, repeat_disable;
global uniform vec4 zwervr_fade_area;   // x0, z0, width, depth (metres); width 0 = nothing fades

// The cell centre packed in CUSTOM0 (RGBA8: x and z in whole metres + 32768, 16 bits
// each, low byte first) as vec4(x, 0, z, 1); vec4(0.0) if the mesh has none.
vec4 fade_owner_from(vec4 data) {
	if (dot(data, data) == 0.0) {
		return vec4(0.0);
	}
	vec4 bytes = round(data * 255.0);
	return vec4(bytes.r + bytes.g * 256.0 - 32768.0, 0.0, bytes.b + bytes.a * 256.0 - 32768.0, 1.0);
}

// Ordered 4 x 4 dither threshold (0..1) for a screen pixel.
float fade_threshold(vec2 pixel) {
	ivec2 p = ivec2(mod(pixel, 4.0));
	int index = p.x + p.y * 4;
	int pattern[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(pattern[index]) + 0.5) / 16.0;
}

// True if this pixel of a faded building should be left out. view_position and
// view_normal: VERTEX and NORMAL of the fragment (view space); owner: CUSTOM0 of the
// vertex (vec4(0.0) if the shader does not pass it on).
bool faded_out(vec3 view_position, vec3 view_normal, mat4 inv_view, mat4 projection, vec2 pixel, vec4 owner) {
	if (projection[3][3] > 0.5) {
		return false;   // the (orthographic) shadow pass: the shadow stays
	}
	if (zwervr_fade_area.z <= 0.0) {
		return false;   // nothing fades
	}
	// a little inwards, so a wall on a cell border belongs to its own cell
	vec3 world = (inv_view * vec4(view_position - view_normal * 0.02, 1.0)).xyz;
	if (world.y < ZWERVR_FADE_FLOOR) {
		return false;   // the ground and everything below it never fades
	}
	vec2 cell_point = owner.w > 0.5 ? owner.xz : world.xz;
	vec2 uv = (cell_point - zwervr_fade_area.xy) / zwervr_fade_area.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return false;
	}
	float amount = textureLod(zwervr_fade_map, uv, 0.0).r;
	return amount > 0.0 && fade_threshold(pixel) < amount;
}
