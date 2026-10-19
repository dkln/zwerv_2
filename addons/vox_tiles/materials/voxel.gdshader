shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#include "res://addons/vox_tiles/materials/voxel_colour.gdshaderinc"

uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.35;
uniform float emission_energy = 0.0;
// 1 = deze surface reageert op tint-kaart en variatie (0 voor bv. lampen)
uniform float tintbaar = 1.0;
// voxelstructuur: lichte randen en kleine helderheidsverschillen per voxel
uniform float voxel_rand : hint_range(0.0, 0.5) = 0.0;
uniform float voxel_ruis : hint_range(0.0, 0.3) = 0.0;   // kleurvariatie zit in de .vox zelf
uniform float voxel_grootte = 0.125;
// asfalt: donkergrijze bovenvlakken krijgen korrel, slijtplekken en een lichte glans
uniform float asfalt : hint_range(0.0, 1.0) = 0.0;
uniform float asfalt_ruwheid : hint_range(0.0, 1.0) = 0.68;
uniform float asfalt_specular : hint_range(0.0, 1.0) = 0.45;
// 1 = alleen kleuren die op asfalt lijken (donker neutraal grijs), 0 = de hele surface
uniform float asfalt_kleurcheck : hint_range(0.0, 1.0) = 1.0;
// reliëf in de belichting (geen extra geometrie), op het voxelraster van de tile (UV2):
// 0 = uit, 1 = blokken (elke voxel een steen), 2 = baksteen (staand: het verband van de
// generator, stenen van 3 x 1 voxels, elke laag 2 verspringend; liggend = blokken),
// 3 = grind (kleine ronde steentjes), 4 = tegels (liggend: tegels van 3 x 3 voxels),
// 5 = keien (liggend: bolle stenen van 2 x 2 voxels met voegen ertussen)
uniform int relief_soort = 0;
uniform float relief_sterkte : hint_range(0.0, 1.0) = 0.5;   // hoe ver de randen afronden
uniform float relief_holte : hint_range(0.0, 1.0) = 0.35;    // hoe donker de voegen zijn
uniform float relief_staand : hint_range(0.0, 1.0) = 1.0;    // sterkte op staande vlakken
// fijner dan een voxel, in wereldcoördinaten: haarscheurtjes en putjes
uniform float scheuren : hint_range(0.0, 1.0) = 0.0;
uniform float putjes : hint_range(0.0, 1.0) = 0.0;


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

// Assen van het vlak in wereldruimte waarlangs UV2 (voxelcoördinaten van de tile) oploopt,
// uit de afgeleiden per pixel; werkt dus ook op gedraaide tiles en samengevoegde meshes.
void uv2_assen(vec3 p, vec2 uv2, out vec3 t, out vec3 b) {
	vec3 dp1 = dFdx(p);
	vec3 dp2 = dFdy(p);
	vec2 du1 = dFdx(uv2);
	vec2 du2 = dFdy(uv2);
	t = normalize(dp1 * du2.y - dp2 * du1.y + vec3(1e-6));
	b = normalize(dp2 * du1.x - dp1 * du2.x + vec3(1e-6));
}

// Reliëf op het voxelraster: kantelt de normaal (wereld) aan de randen van elke steen en
// geeft terug hoeveel de kleur in de voeg donkerder wordt. uv = UV2 (voxels), t/b = de
// wereldassen van uv. Vervaagt als een steen nog maar een paar pixels groot is.
float relief(vec2 uv, vec3 t, vec3 b, bool staand, inout vec3 n, inout vec3 c) {
	int soort = relief_soort;
	if ((soort == 2 && !staand) || ((soort == 4 || soort == 5) && staand)) {
		soort = 1;
	}
	vec2 maat = vec2(1.0);   // afmeting van een steen (voxels)
	float voeg = 0.06;       // halve voegbreedte (voxels)
	vec2 q = uv;
	if (soort == 2) {
		maat = vec2(3.0, 1.0);
		q.x += mod(floor(uv.y), 2.0) * 2.0;
		voeg = 0.07;
	} else if (soort == 3) {
		maat = vec2(0.32);
		voeg = 0.03;
	} else if (soort == 4) {
		maat = vec2(3.0);
		voeg = 0.05;
	} else if (soort == 5) {
		// keien van 2 x 2 voxels op een raster van 3, elke rij 2 verspringend (de voeg
		// is in de geometrie al verdiept)
		q.x += mod(floor(uv.y / 3.0), 2.0) * 2.0;
		maat = vec2(3.0);
	}
	vec2 cel = floor(q / maat);
	vec2 f = fract(q / maat) - 0.5;   // -0,5 .. 0,5 binnen de steen
	float fw = length(fwidth(uv));
	float zicht = 1.0 - smoothstep(0.6, 1.5, fw / min(maat.x, maat.y));
	if (zicht <= 0.0) {
		return 0.0;
	}
	float k = relief_sterkte * zicht * (staand ? relief_staand : 1.0);
	vec2 helling;
	float rand = 1.0;   // afstand tot de voeg (voxels)
	if (soort == 3) {
		vec2 o = vec2(hash_f(cel), hash_f(cel + 5.3)) * 0.3 - 0.15;
		vec2 d = f - o;
		helling = d * 2.0;
		rand = (0.5 - length(d)) * maat.x;
		c *= 1.0 + (hash_f(cel + 9.1) - 0.5) * 0.3 * zicht;
	} else if (soort == 5) {
		vec2 s = fract(q / 3.0) * 3.0;          // 0..3, de steen ligt op 0..2
		vec2 d = (s - 1.0) * 0.5;               // -0,5 .. 0,5 over de steen
		bool steen = s.x < 2.0 && s.y < 2.0;
		helling = steen ? d * 1.6 : vec2(0.0);
		rand = steen ? (0.5 - max(abs(d.x), abs(d.y))) * 2.0 : 0.0;
		voeg = 0.12;
	} else {
		vec2 e = (0.5 - abs(f)) * maat;
		vec2 af = 1.0 - smoothstep(vec2(0.0), vec2(voeg * 3.0), e);
		helling = sign(f) * af;
		rand = min(e.x, e.y);
		if (soort == 2 || soort == 4) {
			c *= 1.0 + (hash_f(cel) - 0.5) * 0.08 * zicht;
		}
	}
	n = normalize(n + (t * helling.x + b * helling.y) * k);
	// voeg: breder en lichter als hij smaller wordt dan een pixel (geen flikkering)
	float w = max(voeg, fw * 0.75);
	return relief_holte * zicht * (voeg / w) * (1.0 - smoothstep(0.0, w, rand));
}

// Afstand (meter) tot de dichtstbijzijnde celrand van een onregelmatig celpatroon met
// cellen van `cel` meter: de lijnen worden de scheurtjes.
float celrand(vec2 p, float cel) {
	vec2 q = p / cel;
	vec2 i = floor(q);
	vec2 f = fract(q);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 pt = o + vec2(hash_f(i + o), hash_f(i + o + 19.7));
			float d = length(pt - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return (d2 - d1) * 0.5 * cel;
}

// Haarscheurtjes en putjes op een vlak (p = positie in het vlak, meter): maakt de kleur
// donkerder, kantelt de normaal licht en geeft terug hoeveel ruwer het wordt.
float scheur_en_put(vec2 p, vec3 t, vec3 b, inout vec3 n, inout vec3 c) {
	float fw = length(fwidth(p));
	float ruwer = 0.0;
	if (scheuren > 0.0) {
		// alleen hier en daar: gebieden van een paar meter, met een vervormde lijn
		float gebied = smoothstep(0.55, 0.75, ruis(p * 0.45 + 3.1));
		vec2 krom = vec2(ruis(p * 3.0), ruis(p * 3.0 + 8.3)) * 0.12;
		float d = celrand(p + krom, 0.7);
		float breed = 0.006;
		float w = max(breed, fw * 0.75);
		float lijn = (1.0 - smoothstep(0.0, w, d)) * (breed / w) * gebied * scheuren;
		lijn *= 1.0 - smoothstep(0.04, 0.12, fw);   // van ver niet meer
		c *= 1.0 - 0.55 * lijn;
		ruwer += lijn * 0.2;
	}
	if (putjes > 0.0) {
		vec2 q = p * 55.0;   // cellen van ~1,8 cm
		float put = step(0.975, hash_f(floor(q)));
		float d = length(fract(q) - 0.5);
		float zicht = 1.0 - smoothstep(0.025, 0.06, fw);
		float diep = put * (1.0 - smoothstep(0.15, 0.4, d)) * putjes * zicht;
		c *= 1.0 - 0.45 * diep;
		vec2 r = (fract(q) - 0.5) * diep;
		n = normalize(n - (t * r.x + b * r.y) * 1.5);
		ruwer += diep * 0.1;
	}
	return ruwer;
}

void vertex() {
	// iets naar binnen schuiven, zodat randvoxels in de goede cel vallen
	wpos = (MODEL_MATRIX * vec4(VERTEX - NORMAL * 0.01, 1.0)).xyz;
	vpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 basis = voxel_albedo(UV, COLOR);   // kleur * AO
	vec3 c = basis;
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
	vec3 nw = wnorm;            // normaal in wereldruimte, aangepast door reliëf en korrel
	if (relief_soort > 0) {
		vec3 t;
		vec3 b;
		uv2_assen(vpos, UV2, t, b);
		float holte = relief(UV2, t, b, abs(wnorm.y) < 0.5, nw, c);
		c *= 1.0 - holte;
		ruw = min(1.0, ruw + holte * 0.3);
	}
	if (scheuren > 0.0 || putjes > 0.0) {
		vec3 an = abs(wnorm);
		vec3 t = an.x > 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		vec3 b = an.y > 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
		ruw = min(1.0, ruw + scheur_en_put(vec2(dot(vpos, t), dot(vpos, b)), t, b, nw, c));
	}
	float a = asfalt > 0.0 ? asfalt * mix(1.0, is_asfalt(basis), asfalt_kleurcheck) * smoothstep(0.85, 0.95, wnorm.y) : 0.0;
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
			nw = normalize(nw + vec3(-hx, 0.0, -hz) * 0.35 * zicht);
		}
	}
	if (nw != wnorm) {
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
	ALBEDO = c;
	ROUGHNESS = clamp(ruw, 0.0, 1.0);
	METALLIC = metallic;
	SPECULAR = spec;
	EMISSION = basis * emission_energy * mix(0.25, 1.0, zwervr_nacht);
}
