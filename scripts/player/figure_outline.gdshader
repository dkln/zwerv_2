// The hard outline round the characters (the player and the townspeople: PlayerModel.material_for
// with `outlined`, as the next pass of their materials): the figure drawn once more, pushed
// out `width_pixels` pixels on the screen and only its back faces, in `colour`, so a dark rim
// follows its contours (and the edges where a limb lies over the body). It is pushed out
// along the corner's own outward direction (CUSTOM0: from the empty voxels round each corner,
// VoxelFigure._add_face), so the corners of the blocks get no cracks; the meshes without that
// (the vehicles: scripts/effects/outline.gd, as their material_overlay) are pushed out from
// their middle (`from_centre`, `centre`). The same width at every zoom, orthogonal or with
// perspective.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, skip_vertex_transform;

uniform vec4 colour : source_color = vec4(0.043, 0.051, 0.102, 1.0);
uniform float width_pixels = 2.0;
uniform bool from_centre = false;
uniform vec3 centre = vec3(0.0);

void vertex() {
	vec3 outward = from_centre ? VERTEX - centre : CUSTOM0.rgb;
	if (dot(outward, outward) < 0.0001) {
		outward = NORMAL;
	}
	vec4 at = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 way = normalize((MODELVIEW_MATRIX * vec4(outward, 0.0)).xyz);
	// metres a pixel is here: orthogonal (PROJECTION_MATRIX[3][3] = 1) everywhere the same,
	// with perspective more further off
	float depth = PROJECTION_MATRIX[3][3] > 0.5 ? 1.0 : -at.z;
	float pixel = depth * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	at.xyz += way * width_pixels * pixel;
	VERTEX = at.xyz;
	NORMAL = way;
}

void fragment() {
	ALBEDO = colour.rgb;
}
