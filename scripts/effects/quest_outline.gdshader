// The outline round a quest item lying in the world (scripts/effects/quest_outline.gd): the
// mesh drawn once more as an overlay, `grow` metres bigger outwards from its middle (`centre`,
// in the mesh's own space; from the middle, not along the normals, so the hard-edged voxel and
// coin meshes get no cracks at their corners), only its back faces: a flat rim of `colour`
// round the item, pulsing softly so it catches the eye. Unshaded, so it shows by night too.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.72, 0.18, 1.0);
uniform vec3 centre = vec3(0.0);
uniform float grow = 0.03;
uniform float pulse_speed = 3.0;

void vertex() {
	vec3 outward = VERTEX - centre;
	if (dot(outward, outward) > 0.000001) {
		VERTEX += normalize(outward) * grow;
	}
}

void fragment() {
	float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed);
	ALBEDO = colour.rgb * pulse;
}
