shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// Wheel of a vehicle (scripts/characters/vehicle.gd puts it on the wheel model,
// props/voertuigen/auto_wiel): the model itself never turns about its axle; this shader
// draws the rubber tyre, the steel rim and the spokes, and turns the spokes by the
// instance parameter `roll`. At speed the spokes blur into an even grey (`spin_blur`), as
// a fast wheel does, instead of seeming to stand still or run backwards between frames.

// Centre of the wheel and its axle in the mesh's own coordinates (set by vehicle.gd).
uniform vec3 centre = vec3(0.0);
uniform vec3 axle = vec3(1.0, 0.0, 0.0);
// Radii (metres): the tyre starts at rim_radius, the hub ends at hub_radius.
uniform float rim_radius = 0.24;
uniform float hub_radius = 0.07;
// Half the width of a spoke (metres) and the number of spokes.
uniform float spoke_half_width = 0.05;
uniform int spokes = 4;
uniform vec3 rubber : source_color = vec3(0.11, 0.11, 0.118);
uniform vec3 rim : source_color = vec3(0.77, 0.776, 0.784);
uniform vec3 spoke : source_color = vec3(0.235, 0.243, 0.259);

// Angle (radians) the wheel has turned, and how blurred the spokes are (0 = sharp,
// 1 = an even blur), per wheel.
instance uniform float roll = 0.0;
instance uniform float spin_blur = 0.0;

varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX - centre;
	local_normal = NORMAL;
}

void fragment() {
	vec3 colour = rubber;
	float rough = 0.9;
	float metal = 0.0;
	// the flat sides of the disc (normal along the axle): rim, spokes and hub
	if (abs(dot(normalize(local_normal), axle)) > 0.7) {
		// two axes across the axle, and the position on them
		vec3 across_a = normalize(cross(axle, abs(axle.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0)));
		vec3 across_b = cross(axle, across_a);
		vec2 p = vec2(dot(local_position, across_a), dot(local_position, across_b));
		float radius = length(p);
		if (radius < rim_radius) {
			// turned by `roll`: the angle within one spoke's sector
			float sector = 6.2831853 / float(spokes);
			float angle = mod(atan(p.y, p.x) + roll, sector) - sector * 0.5;
			float across = abs(sin(angle)) * radius;   // distance to the spoke's middle line
			float edge = fwidth(across) + 0.004;
			float on_spoke = 1.0 - smoothstep(spoke_half_width - edge, spoke_half_width + edge, across);
			on_spoke = max(on_spoke, 1.0 - smoothstep(hub_radius - 0.01, hub_radius + 0.01, radius));
			// blurred: the share of a turn the spokes cover
			float covered = clamp(float(spokes) * spoke_half_width * 2.0 / (6.2831853 * max(radius, 0.01)), 0.0, 1.0);
			on_spoke = mix(on_spoke, max(covered, 1.0 - smoothstep(hub_radius - 0.01, hub_radius + 0.01, radius)), spin_blur);
			colour = mix(rim, spoke, on_spoke);
			rough = 0.35;
			metal = 0.7;
		}
	}
	ALBEDO = colour;
	ROUGHNESS = rough;
	METALLIC = metal;
}
