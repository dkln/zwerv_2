// The glow round an item lying in the world (scripts/effects/quest_outline.gd), the next pass
// of the rim (quest_outline.gdshader): the mesh once more, `grow` metres bigger outwards from
// its middle (`centre`), only its back faces, added softly onto what is behind it and pulsing
// with the rim, so a thing you can pick up seems to give off light. Unshaded, so it shows by
// night too; it writes no depth.
shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_draw_never, shadows_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.72, 0.18, 1.0);
uniform vec3 centre = vec3(0.0);
uniform float grow = 0.08;
uniform float strength = 0.55;
uniform float pulse_speed = 3.0;

void vertex() {
	vec3 outward = VERTEX - centre;
	if (dot(outward, outward) > 0.000001) {
		VERTEX += normalize(outward) * grow * (0.85 + 0.15 * sin(TIME * pulse_speed));
	}
}

void fragment() {
	float pulse = 0.6 + 0.4 * sin(TIME * pulse_speed);
	ALBEDO = colour.rgb * strength * pulse;
}
