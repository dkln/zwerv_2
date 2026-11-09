// Thin dark outlines where one thing ends and the next begins (scripts/effects/edge_outline.gd):
// a full-screen quad in front of the camera reads the depth and the normals of the picture and
// darkens a pixel where the depth jumps (the edge of a building against the street, a figure
// against a wall) or the surface turns sharply (a corner, a kerb). Only the nearer side of a
// depth jump gets the line, so it stays one pixel thin. The colour stays as it is: the line is
// drawn over it in ink at `strength`, so nothing is copied from the screen and see-through
// things (water, glass) keep their look.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;
uniform vec3 ink = vec3(0.04, 0.05, 0.1);
// How dark the line (0..1).
uniform float strength = 0.6;
// A depth jump counts as an edge when the neighbour is this share further away.
uniform float depth_jump = 0.012;
// A turn of the surface counts when the normals differ more than this (1 - dot).
uniform float normal_turn = 0.35;
// Beyond this distance (m) the lines fade out, so far away nothing gets busy.
uniform float fade_from = 140.0;
uniform float fade_to = 260.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inverse_projection) {
	float raw = texture(depth_texture, uv).r;
	vec4 view = inverse_projection * vec4(uv * 2.0 - 1.0, raw, 1.0);
	return -view.z / view.w;
}

vec3 normal_at(vec2 uv) {
	return texture(normal_texture, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	float here = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 normal_here = normal_at(SCREEN_UV);
	float edge = 0.0;
	vec2 offsets[4] = vec2[](vec2(pixel.x, 0.0), vec2(-pixel.x, 0.0), vec2(0.0, pixel.y), vec2(0.0, -pixel.y));
	for (int index = 0; index < 4; index++) {
		vec2 uv = SCREEN_UV + offsets[index];
		float there = linear_depth(uv, INV_PROJECTION_MATRIX);
		// the neighbour lies further away: this pixel is the near side of the edge
		if (there - here > here * depth_jump) {
			edge = 1.0;
		}
		if (1.0 - dot(normal_here, normal_at(uv)) > normal_turn && there >= here - here * depth_jump) {
			edge = max(edge, 0.6);
		}
	}
	float distance_fade = 1.0 - smoothstep(fade_from, fade_to, here);
	ALBEDO = ink;
	ALPHA = edge * strength * distance_fade;
}
