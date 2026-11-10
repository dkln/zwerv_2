// The clouds the camera dives through at the start of the game (scripts/effects/cloud_shroud.gd):
// banks of square cloud blocks (voxels, as the town) drifting over the whole screen. `cover` (0..1) is how much of the screen
// they hide (1: inside the cloud, all white-grey); `dive` (0..1) how far the dive is;
// `magnify` how much the view has zoomed in since the start. The clouds go with that zoom:
// they grow from the middle of the screen, the near layer faster than the far one (NEAR_POWER,
// FAR_POWER: they are closer to the camera than the town), and a hole in the middle of the
// cloud field (HOLE_BLOCKS, in blocks of the cloud itself, so it grows on the screen with
// the zoom) pushes them aside to the edges: you fall through them.
// Each block is lit on top, the side of the block where the one under it is open darker (a
// cube seen from above); at night (zwervr_night) they are dark blue-grey.
shader_type canvas_item;

global uniform float zwervr_night;
uniform float cover : hint_range(0.0, 1.0) = 0.0;
uniform float dive : hint_range(0.0, 1.0) = 0.0;
uniform float magnify = 1.0;
// How the layers grow with the zoom (magnify to this power), how many blocks per screen
// height each has at the start, and the radius (in its own blocks) of the hole they part round.
const float NEAR_POWER = 1.6;
const float FAR_POWER = 1.3;
const float NEAR_START_BLOCKS = 16.0;
const float FAR_START_BLOCKS = 30.0;
const float NEAR_HOLE_BLOCKS = 1.5;
const float FAR_HOLE_BLOCKS = 2.5;
uniform vec3 day_light = vec3(0.96, 0.97, 1.0);
uniform vec3 day_shade = vec3(0.70, 0.74, 0.82);
uniform vec3 night_light = vec3(0.20, 0.23, 0.32);
uniform vec3 night_shade = vec3(0.08, 0.09, 0.14);

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 inside = fract(point);
	vec2 blend = inside * inside * (3.0 - 2.0 * inside);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
			mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

float clouds(vec2 point) {
	float total = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		total += noise(point) * weight;
		point = point * 2.03 + vec2(13.7, 4.1);
		weight *= 0.5;
	}
	return total;
}

// One layer of cloud blocks: `blocks` per screen height (the grid grows from the middle as
// the dive goes on and drifts slowly); a block is cloud where the noise at its middle is over
// `threshold`. Returns (is cloud, its shade 0..1: the top lit, the side under it darker).
// No block within `hole` blocks of the middle of the screen (`drift`: where the middle is in
// the grid), its edge ragged per block.
vec2 block_layer(vec2 centred, float blocks, vec2 drift, vec2 seed, float threshold, float hole) {
	vec2 grid = centred * blocks + drift;
	vec2 cell = floor(grid);
	vec2 inside = fract(grid);
	float from_middle = length(cell + 0.5 - drift);
	if (from_middle < hole * (0.75 + 0.5 * hash(cell + seed))) {
		return vec2(0.0);
	}
	float density = clouds((cell + 0.5) / 6.0 + seed);
	if (density < threshold) {
		return vec2(0.0);
	}
	// the side of the cube where the block under it (on the screen) is open: darker
	float below = clouds((cell + vec2(0.5, 1.5)) / 6.0 + seed);
	float shade = 0.75 + 0.25 * smoothstep(threshold, threshold + 0.25, density);
	if (below < threshold && inside.y > 0.72) {
		shade = 0.25;
	}
	return vec2(1.0, shade);
}

void fragment() {
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 centred = (UV - 0.5) * aspect;
	// two layers of voxel blocks growing with the zoom, the near one faster: falling through them
	float zoom = max(magnify, 1.0);
	float near_blocks = NEAR_START_BLOCKS / pow(zoom, NEAR_POWER);
	float far_blocks = FAR_START_BLOCKS / pow(zoom, FAR_POWER);
	vec2 drift = vec2(TIME * 0.25, TIME * 0.1);
	// the hole opens with the dive (none while it still waits high up)
	float opening = smoothstep(0.0, 0.15, dive);
	// cover 0: nothing, 1: the thickest it gets: loose banks of blocks with the town still
	// showing between them
	vec2 near_block = block_layer(centred, near_blocks, drift, vec2(3.1, 7.2), mix(0.85, 0.5, cover), NEAR_HOLE_BLOCKS * opening);
	vec2 far_block = block_layer(centred, far_blocks, drift * 0.6, vec2(11.4, 2.9), mix(0.9, 0.55, cover), FAR_HOLE_BLOCKS * opening);
	vec2 block = near_block.x > 0.0 ? near_block : vec2(far_block.x, far_block.y * 0.85);
	float alpha = block.x * smoothstep(0.0, 0.08, cover);
	float night = clamp(zwervr_night, 0.0, 1.0);
	vec3 light_colour = mix(day_light, night_light, night);
	vec3 shade_colour = mix(day_shade, night_shade, night);
	COLOR = vec4(mix(shade_colour, light_colour, block.y), alpha);
}
