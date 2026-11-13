// The rim round the player where something hides it (scripts/player/player_model.gd `rim`): the
// same shader for the rim's shells (each part a little bigger, `colour` the bright rim colour,
// drawn first) and for the parts themselves over them (`colour` a flat dark one), both drawn
// over everything (no depth test) but only on the pixels where the scene's depth (the opaque
// things drawn before) stands before the whole figure: a building, a tree, a wall, a bridge,
// whatever it is. Seen through what hides the player: a dark figure ringed bright; where the
// figure is seen, nothing (a figure half behind a wall gets it only on the hidden half).
// "Before the whole figure": nearer to the camera than the nearest the figure can reach (its
// middle `figure_centre`, half its length along `figure_half` and `figure_radius` round that
// axis, set by the model every frame), so the figure's own front never hides its back, its arm
// or its rucksack, also looking straight down from above.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 colour : source_color = vec4(0.07, 0.08, 0.16, 1.0);
uniform vec3 figure_centre = vec3(0.0);
uniform vec3 figure_half = vec3(0.0, 0.9, 0.0);
uniform float figure_radius = 0.45;
/// Metres the scene must stand before the figure's nearest point to count (depth noise).
uniform float margin = 0.05;

void fragment() {
	float raw = textureLod(scene_depth, SCREEN_UV, 0.0).r;
	vec4 at = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float scene_distance = -at.z / at.w;
	// the figure's reach along the view (a cylinder round figure_half): the nearest it gets
	vec3 backwards = normalize(INV_VIEW_MATRIX[2].xyz);
	float along = abs(dot(figure_half, backwards));
	float axis_length = max(length(figure_half), 0.001);
	float tilt = dot(figure_half / axis_length, backwards);
	float reach = along + figure_radius * sqrt(max(1.0 - tilt * tilt, 0.0));
	float centre_distance = -(VIEW_MATRIX * vec4(figure_centre, 1.0)).z;
	float nearest = min(centre_distance - reach, -VERTEX.z);
	if (scene_distance > nearest - margin) {
		discard;   // nothing before the figure here
	}
	ALBEDO = colour.rgb;
	ALPHA = colour.a;
}
