shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;
// Rotor of a helicopter (scripts/vehicles/police_helicopter.gd puts it on a flat square,
// as the wheels' shader, voxel_wheel.gdshader, is put on the wheels): the square itself
// never turns; this shader draws the blades (and the hub) and turns them by the instance
// parameter `turn`. At speed the blades blur into a faint see-through disc (`spin_blur`),
// as a fast rotor does, instead of seeming to stand still or run backwards between frames;
// in that disc the painted blade tips draw a light ring and a few ghost blades turn slowly
// (as a camera catches a rotor), so it can be seen against a dark sky too.
// The square lies in its own x/z plane, from -1 to 1 (UV 0 .. 1), the rotor filling it.

// The number of blades, half the width of a blade (share of the radius), the hub's radius.
uniform int blades = 4;
uniform float blade_half_width = 0.045;
uniform float hub_radius = 0.07;
uniform vec3 blade : source_color = vec3(0.13, 0.135, 0.15);
uniform vec3 hub : source_color = vec3(0.3, 0.31, 0.33);
// How dark the blurred disc gets (its alpha where the blades sweep), and its colour (the
// blades lit by the sky as they sweep: lighter than standing still).
uniform float disc_alpha = 0.5;
uniform vec3 disc : source_color = vec3(0.42, 0.44, 0.48);
// The painted tips: from this share of the radius out, their colour and alpha blurred.
uniform float tip_from = 0.88;
uniform vec3 tip : source_color = vec3(0.92, 0.9, 0.82);
uniform float tip_alpha = 0.75;
// The ghost blades in the blur: how slowly they seem to turn (share of `turn`), how much
// wider than a blade they are, and their alpha.
uniform float ghost_pace = 0.035;
uniform float ghost_widen = 2.5;
uniform float ghost_alpha = 0.4;
// Blades of pixels, as the voxels: the blade edge is cut to steps of this share of the radius.
uniform float pixel = 0.02;

// Angle (radians) the rotor has turned, and how blurred the blades are (0 = sharp,
// 1 = an even disc), per rotor.
instance uniform float turn = 0.0;
instance uniform float spin_blur = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p = (floor(p / pixel) + 0.5) * pixel;
	float radius = length(p);
	if (radius > 1.0) {
		discard;
	}
	float sector = 6.2831853 / float(blades);
	float angle = mod(atan(p.y, p.x) + turn, sector) - sector * 0.5;
	float across = abs(sin(angle)) * radius;   // distance to the blade's middle line
	float on_blade = step(across, blade_half_width);
	float on_hub = step(radius, hub_radius);
	// blurred: the share of a turn the blades cover, a little denser near the hub
	float covered = clamp(float(blades) * blade_half_width * 2.0 / (6.2831853 * max(radius, 0.01)), 0.0, 1.0);
	float sharp_alpha = max(on_blade, on_hub);
	float ghost_angle = mod(atan(p.y, p.x) + turn * ghost_pace, sector) - sector * 0.5;
	float on_ghost = step(abs(sin(ghost_angle)) * radius, blade_half_width * ghost_widen) * step(hub_radius, radius);
	float on_tip = step(tip_from, radius);
	float blurred_alpha = max(max(on_hub, mix(covered, 1.0, 0.25) * disc_alpha), max(on_ghost * ghost_alpha, on_tip * tip_alpha));
	float alpha = mix(sharp_alpha, blurred_alpha, spin_blur);
	if (alpha < 0.02) {
		discard;
	}
	vec3 sharp_colour = on_hub > 0.5 ? hub : (on_tip > 0.5 ? tip : blade);
	vec3 blurred_colour = on_hub > 0.5 ? hub : (on_tip > 0.5 ? tip : mix(disc, blade, on_ghost * 0.6));
	ALBEDO = mix(sharp_colour, blurred_colour, spin_blur);
	// the tips catch a little light even at night
	EMISSION = tip * on_tip * 0.15 * spin_blur;
	ALPHA = alpha;
	ROUGHNESS = 0.6;
	METALLIC = 0.3;
}
