// The CRT look over the whole picture (scripts/ui/ui_style.gd, make_crt_overlay; the HUD,
// the main menu, the intro and the loading screen): it takes the picture so far (the
// world, the vignette) and draws it again bent like the glass of a tube, with black
// rounded corners, lays the HUD's own picture (ui_texture) over it bent less
// (ui_curvature), and puts scanlines over both. crt_disturbance.gd drives the glitch and
// tracking uniforms now and then.
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D ui_texture : filter_linear, repeat_disable, hint_default_transparent;
uniform float curvature = 0.05;
uniform float ui_curvature = 0.02;
uniform float corner = 0.035;
uniform float scanline_strength = 0.14;
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform float opacity = 1.0;
// a rolling disturbance: a band at this height of the screen (0 top .. 1 bottom; off when
// outside), shifting the picture sideways a little and lighting it, a dark line above it
uniform float glitch_y = -1.0;
uniform float glitch_strength = 1.0;
// VHS tracking trouble (0 = none .. 1): the lines jump sideways at random, most in a frayed
// strip at the bottom, the whole picture wobbles, the colours slip apart, noise
uniform float tracking = 0.0;

void fragment() {
	// from the middle (-1..1); further out the picture is taken from further out, so the
	// edges bend in, most at the corners
	float band = 1.0 - smoothstep(0.0, 0.035, abs(SCREEN_UV.y - glitch_y));
	float leading_line = 1.0 - smoothstep(0.0, 0.004, abs(SCREEN_UV.y - glitch_y + 0.04));
	vec2 screen_uv = SCREEN_UV;
	screen_uv.x += band * glitch_strength * 0.006 * sin(SCREEN_UV.y * 900.0 + TIME * 40.0);
	// tracking: per pair of screen lines a jump that changes 24 times a second
	float line_pair = floor(SCREEN_UV.y * screen_size.y * 0.5);
	float jump = fract(sin(line_pair * 12.9898 + floor(TIME * 24.0) * 78.233) * 43758.5453) - 0.5;
	float frayed = smoothstep(0.78, 0.97, SCREEN_UV.y) + 0.25 * band;
	screen_uv.x += tracking * (jump * 0.03 * frayed + 0.0025 * sin(SCREEN_UV.y * 24.0 + TIME * 6.0));
	vec2 centred = screen_uv * 2.0 - 1.0;
	vec2 bent = centred * (1.0 + curvature * centred.yx * centred.yx);
	vec2 uv = bent * 0.5 + 0.5;
	// the black edge of the tube with rounded corners (in pixels, so round on any window)
	vec2 pixels = (abs(bent) - 1.0) * 0.5 * screen_size;
	float radius = corner * screen_size.y;
	vec2 into_corner = max(pixels + radius, 0.0);
	float outside = length(into_corner) - radius;
	float glass = 1.0 - smoothstep(-1.5, 0.5, outside);
	vec3 picture = texture(screen_texture, clamp(uv, 0.0, 1.0)).rgb * glass;
	// the colours slipping apart in tracking trouble (red one way, blue the other)
	vec2 slip = vec2(0.004 * tracking, 0.0);
	picture.r = mix(picture.r, texture(screen_texture, clamp(uv + slip, 0.0, 1.0)).r * glass, step(0.001, tracking));
	picture.b = mix(picture.b, texture(screen_texture, clamp(uv - slip, 0.0, 1.0)).b * glass, step(0.001, tracking));
	// the HUD over it, bent less (and never cut off by the black corners)
	vec2 ui_uv = centred * (1.0 + ui_curvature * centred.yx * centred.yx) * 0.5 + 0.5;
	vec4 ui = texture(ui_texture, clamp(ui_uv, 0.0, 1.0));
	float ui_inside = step(0.0, ui_uv.x) * step(ui_uv.x, 1.0) * step(0.0, ui_uv.y) * step(ui_uv.y, 1.0);
	picture = mix(picture, ui.rgb, ui.a * ui_inside);
	// one darker line in every three, on the bent picture
	float line = step(mod(uv.y * screen_size.y, 3.0), 1.0);
	picture *= 1.0 - scanline_strength * line;
	// tracking noise, most in the frayed strip
	float speck = fract(sin(dot(floor(SCREEN_UV * screen_size * 0.5), vec2(12.9898, 78.233)) + floor(TIME * 30.0)) * 43758.5453);
	picture += vec3(speck - 0.5) * 0.22 * tracking * (0.25 + frayed);
	// the disturbance: lighter in its band, a dark line running ahead of it
	picture += vec3(0.07, 0.08, 0.09) * band * glitch_strength;
	picture *= 1.0 - 0.35 * leading_line * glitch_strength;
	// a little darker towards the rim, as the glass curves away
	picture *= 1.0 - 0.18 * smoothstep(0.55, 1.4, length(centred * vec2(0.9, 1.0)));
	COLOR = vec4(picture, opacity);
}
