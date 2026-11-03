shader_type canvas_item;
// Tilt-shift lens (miniature look): the picture is sharp in a horizontal band and
// blurs smoothly towards the top and bottom, with a little extra saturation. In the
// sharp band an unsharp mask crisps up the (upscaled) picture a little. Drawn on
// a full-screen ColorRect (scripts/effects/tilt_shift.gd) over the 3D view.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// height of the middle of the sharp band (0 = top of the screen, 1 = bottom)
uniform float focus_center : hint_range(0.0, 1.0) = 0.55;
// half the height of the sharp band, as a fraction of the screen height
uniform float focus_width : hint_range(0.0, 0.5) = 0.1;
// distance over which the blur grows from nothing to full
uniform float falloff : hint_range(0.01, 1.0) = 0.3;
// blur radius at full blur, as a fraction of the screen height
uniform float max_blur : hint_range(0.0, 0.05) = 0.012;
uniform float saturation : hint_range(0.0, 2.0) = 1.12;
uniform float contrast : hint_range(0.5, 1.5) = 1.04;
// strength of the sharpening in the sharp band (0 = none)
uniform float sharpen : hint_range(0.0, 1.5) = 0.45;

const int TAPS = 24;
const float GOLDEN_ANGLE = 2.39996323;

void fragment() {
	vec2 uv = SCREEN_UV;
	float amount = smoothstep(focus_width, focus_width + falloff, abs(uv.y - focus_center));
	// radius in pixels; a disc of taps (golden-angle spiral) on a mip level that matches the
	// tap spacing, so a few taps give a smooth blur
	float radius = amount * max_blur / SCREEN_PIXEL_SIZE.y;
	vec3 col = texture(screen_tex, uv).rgb;
	if (sharpen > 0.0 && amount < 1.0) {
		// unsharp mask: away from the average of the four neighbours
		vec2 px = SCREEN_PIXEL_SIZE;
		vec3 around = (textureLod(screen_tex, uv + vec2(px.x, 0.0), 0.0).rgb + textureLod(screen_tex, uv - vec2(px.x, 0.0), 0.0).rgb
			+ textureLod(screen_tex, uv + vec2(0.0, px.y), 0.0).rgb + textureLod(screen_tex, uv - vec2(0.0, px.y), 0.0).rgb) * 0.25;
		col = max(col + (col - around) * sharpen * (1.0 - amount), vec3(0.0));
	}
	if (radius > 0.5) {
		float lod = log2(max(radius / sqrt(float(TAPS)) * 1.5, 1.0));
		col = vec3(0.0);
		for (int i = 0; i < TAPS; i++) {
			float a = float(i) * GOLDEN_ANGLE;
			float r = sqrt((float(i) + 0.5) / float(TAPS)) * radius;
			col += textureLod(screen_tex, uv + vec2(cos(a), sin(a)) * r * SCREEN_PIXEL_SIZE, lod).rgb;
		}
		col /= float(TAPS);
	}
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	COLOR = vec4(col, 1.0);
}
