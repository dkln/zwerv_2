// The screen of a machine in its close-up (machine_screen.gd): the picture of the display
// (its SubViewport) as on a little CRT behind glass, lit by itself. The picture bulges a
// little like the glass of a tube (`curvature`), the corners are rounded and black
// (`corner`, a share of the height), it darkens towards the rim, glows a little (`glow`: the
// bright parts bleed into their neighbours) and flickers faintly. No scanlines.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D picture : source_color, filter_nearest, repeat_disable;
uniform vec2 picture_size = vec2(480.0, 300.0);
uniform float curvature = 0.08;
uniform float corner = 0.08;
uniform float glow = 0.35;
uniform float flicker = 0.02;

vec3 sample_picture(vec2 uv) {
	return texture(picture, clamp(uv, 0.0, 1.0)).rgb;
}

void fragment() {
	vec2 centred = UV * 2.0 - 1.0;
	vec2 bent = centred * (1.0 + curvature * centred.yx * centred.yx);
	vec2 uv = bent * 0.5 + 0.5;
	// the black edge of the tube with rounded corners (in pixels of the picture)
	vec2 pixels = (abs(bent) - 1.0) * 0.5 * picture_size;
	float radius = corner * picture_size.y;
	float outside = length(max(pixels + radius, 0.0)) - radius;
	float glass = 1.0 - smoothstep(-1.5, 0.5, outside);
	vec3 colour = sample_picture(uv);
	// the glow: the bright light of the neighbours (a pixel and two away) bleeding in
	vec2 step_size = 1.5 / picture_size;
	vec3 around = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		vec2 way = vec2(k == 0 ? 1.0 : (k == 1 ? -1.0 : 0.0), k == 2 ? 1.0 : (k == 3 ? -1.0 : 0.0));
		around += sample_picture(uv + way * step_size) + sample_picture(uv + way * step_size * 2.0);
	}
	colour += max(around / 8.0 - 0.25, vec3(0.0)) * glow;
	// darker towards the rim, as the glass curves away; a faint flicker
	colour *= 1.0 - 0.3 * smoothstep(0.45, 1.35, length(centred));
	colour *= 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 61.0));
	ALBEDO = colour * glass;
}
