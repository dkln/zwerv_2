// The fabrics of the player figures (scripts/player/player_model.gd, CLOTH: cotton and
// wool, denim, knitwear, nylon, and hair and fur): the colour of each voxel comes from the
// vertex colour (sRGB, graded, with the face shading and the corner occlusion baked in);
// over it a fine pattern of the fabric, so it reads as cloth up close (a weave, the
// diagonal of denim, rows of stitches, strands), faded out where it would be smaller than
// a pixel so it never turns into noise; its own roughness, specular and velvet edge.
// Skin, eyes, leather, plastic, metal and glass have ordinary materials.
shader_type spatial;
render_mode cull_disabled;

// 1 weave (cotton, wool, nylon), 2 twill (denim), 3 knit (rows of stitches), 4 strands (hair, fur)
uniform int pattern = 1;
uniform float pattern_strength : hint_range(0.0, 0.5) = 0.09;
// repeats per voxel
uniform float pattern_scale = 2.0;
uniform float voxel_size = 0.0625;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float specular_value : hint_range(0.0, 1.0) = 0.3;
uniform float rim_value : hint_range(0.0, 1.0) = 0.35;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.6;

varying vec3 voxel_position;
varying vec3 face_normal;

vec3 to_linear(vec3 colour) {
	return mix(colour / 12.92, pow((colour + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), colour));
}

void vertex() {
	voxel_position = VERTEX / voxel_size;
	face_normal = NORMAL;
}

// -0.5 .. 0.5 at this spot of a face
float pattern_at(vec2 spot) {
	if (pattern == 2) {
		// twill: diagonal ribs
		return sin((spot.x + spot.y) * PI * 2.0) * 0.5;
	} else if (pattern == 3) {
		// knit: rows of little Vs
		vec2 inside = fract(spot * vec2(1.0, 0.7));
		return 0.5 - abs(abs(inside.x - 0.5) * 2.0 - inside.y) * 1.2;
	} else if (pattern == 4) {
		// strands running down, slightly wavy
		return sin(spot.x * 5.0 + sin(spot.y * 0.9) * 1.5) * 0.5;
	}
	// plain weave: in each square a thread runs one way, in the next the other
	vec2 cell = floor(spot);
	vec2 inside = fract(spot);
	bool over = mod(cell.x + cell.y, 2.0) < 1.0;
	return (over ? sin(inside.x * PI) : sin(inside.y * PI)) - 0.6;
}

void fragment() {
	vec3 axis = abs(face_normal);
	vec2 spot = (axis.x > 0.5 ? voxel_position.zy : (axis.y > 0.5 ? voxel_position.xz : voxel_position.xy)) * pattern_scale;
	float pixels = max(length(fwidth(spot)), 0.0001);
	float visible = clamp(1.0 - (pixels - 0.25) * 2.5, 0.0, 1.0);
	float relief = pattern_at(spot) * pattern_strength * visible;
	ALBEDO = clamp(to_linear(COLOR.rgb) * (1.0 + relief * 2.0), 0.0, 1.0);
	ROUGHNESS = clamp(roughness_value - relief * 0.3, 0.0, 1.0);
	SPECULAR = specular_value;
	RIM = rim_value;
	RIM_TINT = rim_tint;
}
