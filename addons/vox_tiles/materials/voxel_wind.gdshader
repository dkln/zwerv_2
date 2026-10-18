shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.35;
uniform float emission_energy = 0.0;
// 1 = deze surface reageert op tint-kaart en variatie (0 voor bv. lampen)
uniform float tintbaar = 1.0;
// voxelstructuur: lichte randen en kleine helderheidsverschillen per voxel
uniform float voxel_rand : hint_range(0.0, 0.5) = 0.0;
uniform float voxel_ruis : hint_range(0.0, 0.3) = 0.05;
uniform float voxel_grootte = 0.125;
// wind: hoe hoger in het model, hoe meer beweging (de voet staat stil)
uniform float wind_sterkte = 0.06;      // meter uitwijking bovenin
uniform float wind_snelheid = 1.1;
uniform float wind_hoogte = 8.0;        // hoogte (m) waarop de volle uitwijking bereikt is

// Globale tint-instellingen (zie Project > Shader Globals en de TintKaart-node).
global uniform sampler2D zwervr_tint_kaart : filter_nearest, repeat_disable;
global uniform vec4 zwervr_tint_gebied;      // x0, z0, breedte, diepte (meters)
global uniform float zwervr_variatie;        // willekeurige kleurvariatie per 4x4 m cel (0..1)

varying vec3 wpos;
varying vec3 vpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	vec3 oorsprong = MODEL_MATRIX[3].xyz;
	float fase = oorsprong.x * 0.37 + oorsprong.z * 0.23;
	float f = clamp(VERTEX.y / wind_hoogte, 0.0, 1.0);
	f *= f;
	float t = TIME * wind_snelheid + fase;
	vec3 lokaal = VERTEX;
	VERTEX.x += (sin(t) * 0.7 + sin(t * 2.3 + lokaal.y) * 0.3) * wind_sterkte * f;
	VERTEX.z += (cos(t * 0.8) * 0.6 + sin(t * 1.9 + lokaal.x) * 0.25) * wind_sterkte * f;
	// iets naar binnen schuiven, zodat randvoxels in de goede cel vallen
	wpos = (MODEL_MATRIX * vec4(VERTEX - NORMAL * 0.01, 1.0)).xyz;
	vpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (tintbaar > 0.5) {
		// voxelstructuur: positie binnen de voxel op dit vlak
		vec3 an = abs(wnorm);
		vec2 uv = an.x > 0.5 ? vpos.zy : (an.y > 0.5 ? vpos.xz : vpos.xy);
		vec2 f = abs(fract(uv / voxel_grootte) - 0.5) * 2.0;
		float rand = smoothstep(0.78, 1.0, max(f.x, f.y));
		vec3 cel_v = floor((vpos - wnorm * 0.02) / voxel_grootte);
		float r = hash3(cel_v) - 0.5;
		c *= (1.0 - rand * voxel_rand) * (1.0 + r * voxel_ruis * 2.0);
		// variatie en tint per cel van 4 m
		vec2 cel = floor(wpos.xz / 4.0);
		float r1 = hash(cel) - 0.5;
		float r2 = hash(cel + 17.3) - 0.5;
		c *= 1.0 + r1 * zwervr_variatie * 0.35;
		c = mix(c, c * vec3(1.0 + r2 * 0.3, 1.0, 1.0 - r2 * 0.3), zwervr_variatie);
		if (zwervr_tint_gebied.z > 0.0) {
			vec2 tuv = (wpos.xz - zwervr_tint_gebied.xy) / zwervr_tint_gebied.zw;
			if (tuv.x >= 0.0 && tuv.y >= 0.0 && tuv.x < 1.0 && tuv.y < 1.0) {
				vec4 t = texture(zwervr_tint_kaart, tuv);
				vec3 tint = t.rgb * 2.0;
				c = mix(c, c * tint, t.a);
			}
		}
	}
	ALBEDO = c;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	EMISSION = COLOR.rgb * emission_energy;
}
