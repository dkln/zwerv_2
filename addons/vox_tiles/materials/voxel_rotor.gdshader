shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;
// Rotor of a helicopter (scripts/vehicles/police_helicopter.gd puts it on a flat square,
// as the wheels' shader, voxel_wheel.gdshader, is put on the wheels): the square itself
// never turns; this shader draws the blades (and the hub) and turns them by the instance
// parameter `turn`. At speed the blades blur into a faint see-through disc (`spin_blur`),
// as a fast rotor does, instead of seeming to stand still or run backwards between frames.
// The square lies in its own x/z plane, from -1 to 1 (UV 0 .. 1), the rotor filling it.

// The number of blades, half the width of a blade (share of the radius), the hub's radius.
uniform int blades = 4;
uniform float blade_half_width = 0.045;
uniform float hub_radius = 0.07;
uniform vec3 blade : source_color = vec3(0.13, 0.135, 0.15);
uniform vec3 hub : source_color = vec3(0.3, 0.31, 0.33);
// How dark the blurred disc gets (its alpha where the blades sweep).
uniform float disc_alpha = 0.3;
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
	float blurred_alpha = max(on_hub, mix(covered, 1.0, 0.15) * disc_alpha);
	float alpha = mix(sharp_alpha, blurred_alpha, spin_blur);
	if (alpha < 0.02) {
		discard;
	}
	ALBEDO = on_hub > 0.5 ? hub : blade;
	ALPHA = alpha;
	ROUGHNESS = 0.6;
	METALLIC = 0.3;
}
