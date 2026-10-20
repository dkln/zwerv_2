shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#include "res://addons/vox_tiles/materials/voxel_colour.gdshaderinc"
#include "res://addons/vox_tiles/materials/voxel_editor.gdshaderinc"

uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.35;
uniform float emission_energy = 0.0;
// 1 = this surface follows the tint map and variation (0 for e.g. lamps)
uniform float tintable = 1.0;
// voxel structure: light edges and small brightness differences per voxel
uniform float voxel_edge : hint_range(0.0, 0.5) = 0.0;
uniform float voxel_noise : hint_range(0.0, 0.3) = 0.0;   // the colour variation is in the .vox itself
uniform float voxel_size = 0.125;
// asphalt: dark grey top faces get grain, wear patches and a slight sheen
uniform float asphalt : hint_range(0.0, 1.0) = 0.0;
uniform float asphalt_roughness : hint_range(0.0, 1.0) = 0.68;
uniform float asphalt_specular : hint_range(0.0, 1.0) = 0.45;
// 1 = only colours that look like asphalt (dark neutral grey), 0 = the whole surface
uniform float asphalt_colour_check : hint_range(0.0, 1.0) = 1.0;
// relief in the lighting (no extra geometry), on the voxel grid of the tile (UV2):
// 0 = off, 1 = blocks (every voxel a stone), 2 = brick (walls: the generator's bond,
// bricks of 3 x 1 voxels, every course shifted by 2; floors = blocks),
// 3 = gravel (small round pebbles), 4 = tiles (floors: tiles of 3 x 3 voxels),
// 5 = cobbles (floors: domed stones of 2 x 2 voxels with joints between them)
uniform int relief_kind = 0;
uniform float relief_strength : hint_range(0.0, 1.0) = 0.5;   // how far the edges round off
uniform float relief_joint : hint_range(0.0, 1.0) = 0.35;     // how dark the joints are
uniform float relief_walls : hint_range(0.0, 1.0) = 1.0;      // strength on vertical faces
// finer than a voxel, in world coordinates: hairline cracks and pits
uniform float cracks : hint_range(0.0, 1.0) = 0.0;
uniform float pits : hint_range(0.0, 1.0) = 0.0;


// Global tint settings (see Project > Shader Globals and the TintKaart node).
global uniform sampler2D zwervr_tint_map : filter_nearest, repeat_disable;
global uniform vec4 zwervr_tint_area;      // x0, z0, width, depth (metres)
global uniform float zwervr_variation;     // random colour variation per 4 x 4 m cell (0..1)
// 0 = day, 1 = night (day cycle): lamps and lit windows are dimmed by day
global uniform float zwervr_night;

varying vec3 wpos;
varying vec3 vpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// hash without sin: stays random at fine scales and large coordinates
float hash_f(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_f(i), hash_f(i + vec2(1.0, 0.0)), u.x),
		mix(hash_f(i + vec2(0.0, 1.0)), hash_f(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 1 for asphalt colours (dark, neutral to slightly bluish grey; also with baked-in AO)
float is_asphalt(vec3 k) {
	float mx = max(k.r, max(k.g, k.b));
	float mn = min(k.r, min(k.g, k.b));
	return step(mx - mn, 0.1 * mx + 0.002) * step(k.r, k.b + 0.001)
		* smoothstep(0.006, 0.012, mx) * (1.0 - smoothstep(0.08, 0.095, mx));
}

// World-space axes of the face along which UV2 (the tile's voxel coordinates) increases,
// from the per-pixel derivatives; so it also works on rotated tiles and merged meshes.
void uv2_axes(vec3 p, vec2 uv2, out vec3 t, out vec3 b) {
	vec3 dp1 = dFdx(p);
	vec3 dp2 = dFdy(p);
	vec2 du1 = dFdx(uv2);
	vec2 du2 = dFdy(uv2);
	t = normalize(dp1 * du2.y - dp2 * du1.y + vec3(1e-6));
	b = normalize(dp2 * du1.x - dp1 * du2.x + vec3(1e-6));
}

// Relief on the voxel grid: tilts the (world) normal at the edges of every stone and
// returns how much darker the colour gets in the joint. uv = UV2 (voxels), t/b = the
// world axes of uv. Fades out once a stone is only a few pixels large.
float relief(vec2 uv, vec3 t, vec3 b, bool wall, inout vec3 n, inout vec3 c) {
	int kind = relief_kind;
	if ((kind == 2 && !wall) || ((kind == 4 || kind == 5) && wall)) {
		kind = 1;
	}
	vec2 size = vec2(1.0);   // size of a stone (voxels)
	float joint = 0.06;      // half the joint width (voxels)
	vec2 q = uv;
	if (kind == 2) {
		size = vec2(3.0, 1.0);
		q.x += mod(floor(uv.y), 2.0) * 2.0;
		joint = 0.07;
	} else if (kind == 3) {
		size = vec2(0.32);
		joint = 0.03;
	} else if (kind == 4) {
		size = vec2(3.0);
		joint = 0.05;
	} else if (kind == 5) {
		// cobbles of 2 x 2 voxels on a grid of 3, every row shifted by 2 (the joint is
		// already sunk in the geometry)
		q.x += mod(floor(uv.y / 3.0), 2.0) * 2.0;
		size = vec2(3.0);
	}
	vec2 cell = floor(q / size);
	vec2 f = fract(q / size) - 0.5;   // -0.5 .. 0.5 within the stone
	float fw = length(fwidth(uv));
	float visible = 1.0 - smoothstep(0.6, 1.5, fw / min(size.x, size.y));
	if (visible <= 0.0) {
		return 0.0;
	}
	float k = relief_strength * visible * (wall ? relief_walls : 1.0);
	vec2 slope;
	float edge = 1.0;   // distance to the joint (voxels)
	if (kind == 3) {
		vec2 o = vec2(hash_f(cell), hash_f(cell + 5.3)) * 0.3 - 0.15;
		vec2 d = f - o;
		slope = d * 2.0;
		edge = (0.5 - length(d)) * size.x;
		c *= 1.0 + (hash_f(cell + 9.1) - 0.5) * 0.3 * visible;
	} else if (kind == 5) {
		vec2 s = fract(q / 3.0) * 3.0;          // 0..3, the stone lies on 0..2
		vec2 d = (s - 1.0) * 0.5;               // -0.5 .. 0.5 across the stone
		bool stone = s.x < 2.0 && s.y < 2.0;
		slope = stone ? d * 1.6 : vec2(0.0);
		edge = stone ? (0.5 - max(abs(d.x), abs(d.y))) * 2.0 : 0.0;
		joint = 0.12;
	} else {
		vec2 e = (0.5 - abs(f)) * size;
		vec2 af = 1.0 - smoothstep(vec2(0.0), vec2(joint * 3.0), e);
		slope = sign(f) * af;
		edge = min(e.x, e.y);
		if (kind == 2 || kind == 4) {
			c *= 1.0 + (hash_f(cell) - 0.5) * 0.08 * visible;
		}
	}
	n = normalize(n + (t * slope.x + b * slope.y) * k);
	// joint: wider and lighter once it gets narrower than a pixel (no flicker)
	float w = max(joint, fw * 0.75);
	return relief_joint * visible * (joint / w) * (1.0 - smoothstep(0.0, w, edge));
}

// Distance (metres) to the nearest cell edge of an irregular cell pattern with cells
// of `cell` metres: the edges become the cracks.
float cell_edge(vec2 p, float cell) {
	vec2 q = p / cell;
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
	return (d2 - d1) * 0.5 * cell;
}

// Hairline cracks and pits on a face (p = position in the face, metres): darkens the
// colour, tilts the normal slightly and returns how much rougher the face gets.
float cracks_and_pits(vec2 p, vec3 t, vec3 b, inout vec3 n, inout vec3 c) {
	float fw = length(fwidth(p));
	float rougher = 0.0;
	if (cracks > 0.0) {
		// only here and there: areas of a few metres, with a distorted line
		float area = smoothstep(0.55, 0.75, noise(p * 0.45 + 3.1));
		vec2 bend = vec2(noise(p * 3.0), noise(p * 3.0 + 8.3)) * 0.12;
		float d = cell_edge(p + bend, 0.7);
		float wide = 0.006;
		float w = max(wide, fw * 0.75);
		float line = (1.0 - smoothstep(0.0, w, d)) * (wide / w) * area * cracks;
		line *= 1.0 - smoothstep(0.04, 0.12, fw);   // not from afar
		c *= 1.0 - 0.55 * line;
		rougher += line * 0.2;
	}
	if (pits > 0.0) {
		vec2 q = p * 55.0;   // cells of ~1.8 cm
		float pit = step(0.975, hash_f(floor(q)));
		float d = length(fract(q) - 0.5);
		float visible = 1.0 - smoothstep(0.025, 0.06, fw);
		float deep = pit * (1.0 - smoothstep(0.15, 0.4, d)) * pits * visible;
		c *= 1.0 - 0.45 * deep;
		vec2 r = (fract(q) - 0.5) * deep;
		n = normalize(n - (t * r.x + b * r.y) * 1.5);
		rougher += deep * 0.1;
	}
	return rougher;
}

void vertex() {
	// shift slightly inwards, so edge voxels fall in the right cell
	wpos = (MODEL_MATRIX * vec4(VERTEX - NORMAL * 0.01, 1.0)).xyz;
	vpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = voxel_albedo(UV, COLOR);   // colour * AO
	vec3 c = base;
	if (tintable > 0.5) {
		// voxel structure: position within the voxel on this face
		vec3 an = abs(wnorm);
		vec2 uv = an.x > 0.5 ? vpos.zy : (an.y > 0.5 ? vpos.xz : vpos.xy);
		vec2 f = abs(fract(uv / voxel_size) - 0.5) * 2.0;
		float edge = smoothstep(0.78, 1.0, max(f.x, f.y));
		vec3 voxel_cell = floor((vpos - wnorm * 0.02) / voxel_size);
		float r = hash3(voxel_cell) - 0.5;
		c *= (1.0 - edge * voxel_edge) * (1.0 + r * voxel_noise * 2.0);
		// variation and tint per 4 m cell
		vec2 cell = floor(wpos.xz / 4.0);
		float r1 = hash(cell) - 0.5;
		float r2 = hash(cell + 17.3) - 0.5;
		c *= 1.0 + r1 * zwervr_variation * 0.35;
		c = mix(c, c * vec3(1.0 + r2 * 0.3, 1.0, 1.0 - r2 * 0.3), zwervr_variation);
		if (zwervr_tint_area.z > 0.0) {
			vec2 tuv = (wpos.xz - zwervr_tint_area.xy) / zwervr_tint_area.zw;
			if (tuv.x >= 0.0 && tuv.y >= 0.0 && tuv.x < 1.0 && tuv.y < 1.0) {
				vec4 t = texture(zwervr_tint_map, tuv);
				vec3 tint = t.rgb * 2.0;
				c = mix(c, c * tint, t.a);
			}
		}
	}
	float rough = roughness;
	float spec = specular;
	vec3 nw = wnorm;            // world-space normal, changed by relief and grain
	bool light = editor_view();   // editor: no costly detail, tile borders instead
	if (relief_kind > 0 && !light) {
		vec3 t;
		vec3 b;
		uv2_axes(vpos, UV2, t, b);
		float joint = relief(UV2, t, b, abs(wnorm.y) < 0.5, nw, c);
		c *= 1.0 - joint;
		rough = min(1.0, rough + joint * 0.3);
	}
	if ((cracks > 0.0 || pits > 0.0) && !light) {
		vec3 an = abs(wnorm);
		vec3 t = an.x > 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		vec3 b = an.y > 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
		rough = min(1.0, rough + cracks_and_pits(vec2(dot(vpos, t), dot(vpos, b)), t, b, nw, c));
	}
	float a = asphalt > 0.0 && !light ? asphalt * mix(1.0, is_asphalt(base), asphalt_colour_check) * smoothstep(0.85, 0.95, wnorm.y) : 0.0;
	if (a > 0.0) {
		vec2 p = vpos.xz;
		// wear patches of a few metres: a bit darker and smoother (tyre tracks, oil)
		float wear = noise(p * 0.35) * 0.65 + noise(p * 1.1 + 7.1) * 0.35;
		c *= 1.0 + (wear - 0.5) * 0.22 * a;
		rough = mix(rough, asphalt_roughness + (wear - 0.5) * 0.16, a);
		spec = mix(spec, asphalt_specular, a);
		// stone grain of ~2 cm; fades once a grain gets smaller than a pixel (else it
		// flickers from afar), the roughness then keeps the average
		float visible = a * (1.0 - smoothstep(0.35, 1.0, length(fwidth(p)) / 0.02));
		if (visible > 0.0) {
			vec2 q = p * 50.0;
			float k = hash_f(floor(q));
			float stone = step(0.92, hash_f(floor(q * 0.5) + 3.7));
			c *= 1.0 + ((k - 0.5) * 0.18 + stone * 0.22) * visible;
			rough -= (stone * 0.25 + (k - 0.5) * 0.1) * visible;
			// small bumps: the sun glints on the grains
			float e = 0.5;
			float hx = noise(q + vec2(e, 0.0)) - noise(q - vec2(e, 0.0));
			float hz = noise(q + vec2(0.0, e)) - noise(q - vec2(0.0, e));
			nw = normalize(nw + vec3(-hx, 0.0, -hz) * 0.35 * visible);
		}
	}
	if (nw != wnorm) {
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
	if (light) {
		c *= 1.0 - 0.6 * tile_border(vpos, wnorm);
	}
	ALBEDO = c;
	ROUGHNESS = light ? 1.0 : clamp(rough, 0.0, 1.0);   // editor: matte, no reflections
	METALLIC = light ? 0.0 : metallic;
	SPECULAR = light ? 0.0 : spec;
	EMISSION = base * emission_energy * mix(0.25, 1.0, zwervr_night);
}
