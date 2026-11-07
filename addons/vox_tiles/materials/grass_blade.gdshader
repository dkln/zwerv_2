shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Grass blades (scripts/effects/grass_blades.gd): one blocky, stepped blade mesh drawn many times
// with a MultiMesh; the vertex shader bends every blade with the wind, more towards the
// tip, along the same gusts as the grass texture in voxel.gdshader (wind direction and
// speed match). Every square segment has its own flat tint (vertex colour r: 0 = base ..
// 1 = tip), in the voxel style; INSTANCE_CUSTOM.x varies the shade per blade.
// Thinning out: from thin_from to thin_to metres from thin_centre (the camera focus) fewer
// and fewer blades are left, down to the share thin_keep; a blade whose INSTANCE_CUSTOM.z is
// above the share left where it stands shrinks away to its base (no pixels drawn).

uniform vec3 base_color : source_color = vec3(0.26, 0.44, 0.11);
uniform vec3 tip_color : source_color = vec3(0.62, 0.82, 0.26);
uniform float sway = 0.12;          // metres of sway at the tip in a steady breeze
uniform float gust_sway = 0.18;     // extra sway in a gust
uniform float blade_height = 0.28;  // height (m) of the mesh, for the bend along the blade (tall grass bends more)
// 0 = no blades (zoomed out), 1 = full height; grass_blades.gd fades it with the zoom
uniform float grow = 1.0;
uniform vec2 thin_centre = vec2(0.0);
uniform float thin_from = 1e6;
uniform float thin_to = 2e6;
uniform float thin_keep = 1.0;

varying float along;
varying float shade;
varying float tint;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	along = clamp(VERTEX.y / blade_height, 0.0, 1.0);
	shade = INSTANCE_CUSTOM.x;
	tint = COLOR.r;
	VERTEX.y *= grow;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float share_left = mix(1.0, thin_keep, smoothstep(thin_from, thin_to, distance(world.xz, thin_centre)));
	float thin_scale = 1.0 - smoothstep(share_left, share_left + 0.04, INSTANCE_CUSTOM.z);
	// the same wind as voxel.gdshader grass_feel: direction and drifting gusts
	vec2 wind = normalize(vec2(1.0, -0.5));
	vec2 gp = world.xz - wind * TIME * 2.2;
	float gust = smoothstep(0.6, 0.85, noise(gp * vec2(0.06, 0.03)));
	float flutter = sin(TIME * 2.4 + INSTANCE_CUSTOM.y * 6.28 + dot(world.xz, wind) * 0.8);
	float bend = (sway * (0.6 + 0.4 * flutter) + gust_sway * gust) * along * along * grow;
	// the wind in mesh space (the blade is rotated per instance)
	vec3 w = (inverse(MODEL_MATRIX) * vec4(wind.x, 0.0, wind.y, 0.0)).xyz;
	VERTEX.xz += normalize(w.xz) * bend;
	VERTEX.y -= bend * bend * 0.8;   // a bent blade gets a little lower
	VERTEX *= thin_scale;
}

void fragment() {
	vec3 c = mix(base_color, tip_color, tint) * (0.85 + 0.3 * shade);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	// a little light through the blade
	BACKLIGHT = c * 0.4;
}
