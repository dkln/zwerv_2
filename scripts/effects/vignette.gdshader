shader_type canvas_item;
render_mode blend_mix, unshaded;
// Vignette (scripts/effects/vignette.gd, the Vignet node): darkens the picture towards
// the edges, a little more at the top and bottom than at the sides, so the eye goes to
// the middle. It does not read the screen: it is a transparent overlay that is blended
// over the picture, so there is no screen copy and no blur (one blend per pixel).

// darkness at the very corners (0 = none, 1 = the full colour)
uniform float strength : hint_range(0.0, 1.0) = 0.7;
// distance from the middle (0 = middle, 1 = the edge) where the darkening starts
uniform float inner : hint_range(0.0, 1.5) = 0.75;
// distance over which it grows to its full strength
uniform float softness : hint_range(0.01, 1.5) = 0.55;
// weight of the height compared with the width (more = more at the top and bottom)
uniform float vertical_weight : hint_range(0.5, 2.0) = 1.25;
uniform vec3 shade_colour : source_color = vec3(0.05, 0.06, 0.1);

void fragment() {
	vec2 from_middle = (UV - 0.5) * 2.0 * vec2(1.0, vertical_weight);
	float amount = smoothstep(inner, inner + softness, length(from_middle));
	COLOR = vec4(shade_colour, amount * strength);
}
