// The player seen through what stands before them (scripts/player/player_model.gd `xray`, the
// material_overlay of the player's meshes): where something is drawn nearer to the camera than
// the figure (a tree, a lamp post, a facade), the figure's shape shows over it in one flat
// colour, see-through; where the figure itself is seen, nothing.
// "Nearer than the figure": more than `margin` metres nearer than the figure's own pixel there,
// deeper than the figure itself (body and rucksack), so its own front never counts as standing
// before its back.
// (Wanted: only an outline round the hidden parts; not reliable yet in this renderer.)
shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 colour : source_color = vec4(1.0, 0.86, 0.36, 0.45);
uniform float margin = 0.7;

void fragment() {
	float raw = textureLod(scene_depth, SCREEN_UV, 0.0).r;
	vec4 at = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float scene_distance = -at.z / at.w;
	if (scene_distance > -VERTEX.z - margin) {
		discard;   // nothing before the figure here
	}
	ALBEDO = colour.rgb;
	ALPHA = colour.a;
}
