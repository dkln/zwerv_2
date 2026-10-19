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
// asfalt: donkergrijze bovenvlakken krijgen korrel, slijtplekken en een lichte glans
uniform float asfalt : hint_range(0.0, 1.0) = 0.0;
uniform float asfalt_ruwheid : hint_range(0.0, 1.0) = 0.68;
uniform float asfalt_specular : hint_range(0.0, 1.0) = 0.45;
// 1 = alleen kleuren die op asfalt lijken (donker neutraal grijs), 0 = de hele surface
uniform float asfalt_kleurcheck : hint_range(0.0, 1.0) = 1.0;

// Globale tint-instellingen (zie Project > Shader Globals en de TintKaart-node).
global uniform sampler2D zwervr_tint_kaart : filter_nearest, repeat_disable;
global uniform vec4 zwervr_tint_gebied;      // x0, z0, breedte, diepte (meters)
global uniform float zwervr_variatie;        // willekeurige kleurvariatie per 4x4 m cel (0..1)
// 0 = dag, 1 = nacht (dagcyclus): lampen en verlichte ramen branden overdag gedimd
global uniform float zwervr_nacht;

varying vec3 wpos;
varying vec3 vpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// hash zonder sin: blijft ook op fijne schaal en grote coördinaten willekeurig
float hash_f(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ruis(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_f(i), hash_f(i + vec2(1.0, 0.0)), u.x),
		mix(hash_f(i + vec2(0.0, 1.0)), hash_f(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 1 voor asfaltkleuren (donker, neutraal tot iets blauwig grijs; ook met ingebakken AO)
float is_asfalt(vec3 k) {
	float mx = max(k.r, max(k.g, k.b));
	float mn = min(k.r, min(k.g, k.b));
	return step(mx - mn, 0.1 * mx + 0.002) * step(k.r, k.b + 0.001)
		* smoothstep(0.006, 0.012, mx) * (1.0 - smoothstep(0.08, 0.095, mx));
}

void vertex() {
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
	float ruw = roughness;
	float spec = specular;
	float a = asfalt > 0.0 ? asfalt * mix(1.0, is_asfalt(COLOR.rgb), asfalt_kleurcheck) * smoothstep(0.85, 0.95, wnorm.y) : 0.0;
	if (a > 0.0) {
		vec2 p = vpos.xz;
		// slijtplekken van een paar meter: iets donkerder en gladder (bandensporen, olie)
		float slijt = ruis(p * 0.35) * 0.65 + ruis(p * 1.1 + 7.1) * 0.35;
		c *= 1.0 + (slijt - 0.5) * 0.22 * a;
		ruw = mix(ruw, asfalt_ruwheid + (slijt - 0.5) * 0.16, a);
		spec = mix(spec, asfalt_specular, a);
		// steenkorrel van ~2 cm; vervaagt als een korrel kleiner wordt dan een pixel
		// (anders flikkert het van ver), de ruwheid houdt dan het gemiddelde
		float zicht = a * (1.0 - smoothstep(0.35, 1.0, length(fwidth(p)) / 0.02));
		if (zicht > 0.0) {
			vec2 q = p * 50.0;
			float k = hash_f(floor(q));
			float steen = step(0.92, hash_f(floor(q * 0.5) + 3.7));
			c *= 1.0 + ((k - 0.5) * 0.18 + steen * 0.22) * zicht;
			ruw -= (steen * 0.25 + (k - 0.5) * 0.1) * zicht;
			// kleine bobbels: de zon glinstert op de korrels
			float e = 0.5;
			float hx = ruis(q + vec2(e, 0.0)) - ruis(q - vec2(e, 0.0));
			float hz = ruis(q + vec2(0.0, e)) - ruis(q - vec2(0.0, e));
			vec3 n = normalize(vec3(-hx * 0.35 * zicht, 1.0, -hz * 0.35 * zicht));
			NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		}
	}
	ALBEDO = c;
	ROUGHNESS = clamp(ruw, 0.0, 1.0);
	METALLIC = metallic;
	SPECULAR = spec;
	EMISSION = COLOR.rgb * emission_energy * mix(0.25, 1.0, zwervr_nacht);
}
