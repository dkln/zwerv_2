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
uniform float voxel_ruis : hint_range(0.0, 0.3) = 0.035;
uniform float voxel_grootte = 0.125;
// deinen: drijvende objecten volgen dezelfde golven als het water
// (houd golf_hoogte, golf_snelheid en golf_lengte gelijk aan voxel_water.tres)
uniform float golf_hoogte = 0.04;
uniform float golf_snelheid = 0.7;
uniform float golf_lengte = 6.0;
uniform float rollen = 0.035;           // radialen: rollen en stampen van het object

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

// dezelfde golf als in voxel_water.gdshader
float golf(vec2 p, float t) {
	float k = 6.2831 / golf_lengte;
	float g = sin(dot(p, vec2(0.94, 0.34)) * k + t) * 0.35;
	g += sin(dot(p, vec2(-0.42, 0.91)) * k * 1.37 - t * 0.83) * 0.28;
	g += sin(dot(p, vec2(0.68, -0.73)) * k * 0.71 + t * 0.61) * 0.22;
	g += sin(dot(p, vec2(-0.99, -0.12)) * k * 2.13 + t * 1.27) * 0.15;
	return g;
}

void vertex() {
	float t = TIME * golf_snelheid;
	vec3 oorsprong = MODEL_MATRIX[3].xyz;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// op en neer met het water op deze plek
	VERTEX.y += golf(w.xz, t) * golf_hoogte;
	// langzaam rollen en stampen rond het midden van het object
	float fase = oorsprong.x * 0.31 + oorsprong.z * 0.17;
	float rx = sin(TIME * 0.9 + fase) * rollen;
	float rz = sin(TIME * 0.7 + fase * 1.7) * rollen * 0.7;
	VERTEX.y += VERTEX.x * rz + VERTEX.z * rx;
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
