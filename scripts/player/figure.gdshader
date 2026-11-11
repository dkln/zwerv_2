// The fabrics of the player figures (scripts/player/player_model.gd, CLOTH: cotton and
// wool, denim, knitwear, nylon, and hair and fur): the colour of each voxel comes from the
// vertex colour (sRGB, graded, with the face shading and the corner occlusion baked in);
// over it a fine structure of the fabric, so it reads as woven cloth up close: threads
// that go over and under each other (a plain weave, the diagonal of a twill such as
// denim), rows of stitches for knitwear, strands for hair. Each thread is round (lighter
// on its crown, darker in the gaps between threads) and catches the light through its own
// bumped normal; the crossing threads (the weft) can be lighter than the lengthwise ones
// (the warp), as the white weft of denim, and each thread differs a little in shade (slubs
// in the yarn). Everything fades out where it would be smaller than a pixel, so it never
// turns into noise at play distance. Its own roughness, specular and velvet edge.
// Skin, eyes, leather, plastic, metal and glass: figure_plain.gdshader.
shader_type spatial;
render_mode cull_disabled;


// 1 plain weave (cotton, wool, nylon), 2 twill (denim), 3 knit (rows of stitches),
// 4 strands (hair, fur)
uniform int pattern = 1;
// how much the structure lightens and darkens the colour
uniform float pattern_strength : hint_range(0.0, 0.5) = 0.09;
// threads (or stitches) per voxel
uniform float pattern_scale = 2.0;
uniform float voxel_size = 0.0625;
// how much the threads bump the normal (0 = flat)
uniform float relief_depth : hint_range(0.0, 1.0) = 0.35;
// how much lighter the weft is than the warp where it shows (denim: the white weft)
uniform float weft_lightness : hint_range(-0.5, 0.5) = 0.04;
// how much each thread differs in shade from the next
uniform float slub_strength : hint_range(0.0, 0.3) = 0.05;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float specular_value : hint_range(0.0, 1.0) = 0.3;
uniform float rim_value : hint_range(0.0, 1.0) = 0.35;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.6;

varying vec3 voxel_position;
varying vec3 face_normal;

vec3 to_linear(vec3 colour) {
	return mix(colour / 12.92, pow((colour + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), colour));
}

float hash(float seed) {
	return fract(sin(seed * 127.1 + 311.7) * 43758.5453);
}

void vertex() {
	voxel_position = VERTEX / voxel_size;
	face_normal = NORMAL;
	// the face's own axes, the same ones the pattern is laid out along (see face_spot), so
	// the bumped normal of the threads leans the right way
	vec3 axis = abs(NORMAL);
	if (axis.x > 0.5) {
		TANGENT = vec3(0.0, 0.0, 1.0);
		BINORMAL = vec3(0.0, 1.0, 0.0);
	} else if (axis.y > 0.5) {
		TANGENT = vec3(1.0, 0.0, 0.0);
		BINORMAL = vec3(0.0, 0.0, 1.0);
	} else {
		TANGENT = vec3(1.0, 0.0, 0.0);
		BINORMAL = vec3(0.0, 1.0, 0.0);
	}
}

// The round cross-section of a thread, 0 at its edges and 1 on its crown (`across` 0..1).
float thread_profile(float across) {
	return sqrt(max(sin(clamp(across, 0.0, 1.0) * PI), 0.0));
}

// Is the warp (the thread running along y) on top in this cell of the weave?
bool warp_on_top(vec2 cell) {
	if (pattern == 2) {
		// a 2/1 twill: the warp goes over two wefts and under one, shifted a cell per row,
		// so the floats line up in diagonal ribs
		return mod(cell.x + cell.y, 3.0) < 2.0;
	}
	// plain weave: over one, under one
	return mod(cell.x + cell.y, 2.0) < 1.0;
}

// The height of the fabric at this spot of a face (in threads), 0 (a gap) .. 1 (the crown
// of a thread).
float height_at(vec2 spot) {
	if (pattern == 3) {
		// knit: rows of little Vs
		vec2 inside = fract(spot * vec2(1.0, 0.7));
		return clamp(1.0 - abs(abs(inside.x - 0.5) * 2.0 - inside.y) * 1.2, 0.0, 1.0);
	} else if (pattern == 4) {
		// strands running down, slightly wavy
		return sin(spot.x * 5.0 + sin(spot.y * 0.9) * 1.5) * 0.5 + 0.5;
	}
	vec2 cell = floor(spot);
	vec2 inside = fract(spot);
	if (warp_on_top(cell)) {
		// the warp runs up through the cell, arching over the weft under it
		return thread_profile(inside.x) * (0.7 + 0.3 * sin(inside.y * PI));
	}
	// the weft runs across, arching over the warp
	return thread_profile(inside.y) * (0.7 + 0.3 * sin(inside.x * PI));
}

// The spot on the face (in threads) along the face's own axes (as TANGENT and BINORMAL).
vec2 face_spot(vec3 position, vec3 normal) {
	vec3 axis = abs(normal);
	vec2 spot = axis.x > 0.5 ? position.zy : (axis.y > 0.5 ? position.xz : position.xy);
	return spot * pattern_scale;
}

void fragment() {
	vec2 spot = face_spot(voxel_position, face_normal);
	// how many threads a pixel covers: fade the structure out before it would alias
	float pixels = max(length(fwidth(spot)), 0.0001);
	float visible = clamp(1.0 - (pixels - 0.25) * 2.5, 0.0, 1.0);
	float height = height_at(spot);
	float relief = (height - 0.6) * pattern_strength * visible;
	vec3 colour = to_linear(COLOR.rgb) * (1.0 + relief * 2.0);
	if (pattern == 1 || pattern == 2) {
		vec2 cell = floor(spot);
		bool warp = warp_on_top(cell);
		// the weft lighter (or darker) than the warp where it shows
		colour *= 1.0 + (warp ? 0.0 : weft_lightness) * visible;
		// each thread a little different: the warp by its column, the weft by its row
		float thread_seed = warp ? cell.x : cell.y + 1000.0;
		colour *= 1.0 + (hash(thread_seed) - 0.5) * 2.0 * slub_strength * visible;
	}
	ALBEDO = clamp(colour, 0.0, 1.0);
	// the bumped normal from the slope of the height (a small step in thread units)
	float step_size = 0.04;
	float slope_x = (height_at(spot + vec2(step_size, 0.0)) - height_at(spot - vec2(step_size, 0.0))) / (2.0 * step_size);
	float slope_y = (height_at(spot + vec2(0.0, step_size)) - height_at(spot - vec2(0.0, step_size))) / (2.0 * step_size);
	vec2 lean = clamp(-vec2(slope_x, slope_y) * 0.25, vec2(-1.0), vec2(1.0));
	NORMAL_MAP = vec3(lean * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = relief_depth * visible;
	// the gaps between threads are duller than the crowns
	ROUGHNESS = clamp(roughness_value + (0.6 - height) * 0.15 * visible, 0.0, 1.0);
	SPECULAR = specular_value;
	RIM = rim_value;
	RIM_TINT = rim_tint;
}
