// The edge of each voxel of a figure (scripts/player/player_model.gd, VoxelFigure: every face
// a quad of its own, its UV 0..1 across the voxel), a little darker, the top edge a little
// lighter: as a bevel on every cube, so voxels of one colour next to each other still read
// as separate blocks and the details of the figures (a collar, a sleeve, a pocket) do not
// run into each other. Fades out once a voxel is only a few pixels on the screen, so it
// never turns into noise far off.

uniform float bevel_dark : hint_range(0.0, 0.6) = 0.24;
uniform float bevel_light : hint_range(0.0, 0.4) = 0.10;
// how wide the edge is, in a voxel's width
uniform float bevel_width : hint_range(0.02, 0.4) = 0.14;

// How much this spot of the face (UV) is lightened (> 1) or darkened (< 1).
float voxel_bevel(vec2 face_uv) {
	vec2 edge_distance = min(face_uv, 1.0 - face_uv);
	float nearest = min(edge_distance.x, edge_distance.y);
	// how many voxels a pixel covers: from 1/3 of a voxel a pixel on, fade it out
	float per_pixel = max(length(fwidth(face_uv)), 0.0001);
	float shows = clamp(1.0 - (per_pixel - 0.12) * 5.0, 0.0, 1.0);
	float width = max(bevel_width, per_pixel);
	float on_edge = 1.0 - smoothstep(width * 0.5, width, nearest);
	// the top edge (v near 1 on the sides) catches the light
	float top = 1.0 - smoothstep(width * 0.5, width, 1.0 - face_uv.y);
	return 1.0 + (top * bevel_light - on_edge * (1.0 - top) * bevel_dark) * shows;
}
