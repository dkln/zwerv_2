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
// 3 = gravel (small round pebbles), 4 = tiles (floors: tiles of tile_size voxels),
// 5 = cobbles (floors: domed stones of 2 x 2 voxels with joints between them)
uniform int relief_kind = 0;
uniform float relief_strength : hint_range(0.0, 1.0) = 0.5;   // how far the edges round off
uniform float relief_joint : hint_range(0.0, 1.0) = 0.35;     // how dark the joints are
uniform float relief_walls : hint_range(0.0, 1.0) = 1.0;      // strength on vertical faces
// brick (relief_kind 2): bricks of 3 x 1 voxels times this, every course shifted by 2 x this
uniform float brick_scale = 2.0;
// blocks (relief_kind 1: pavers, stone): stones of this many voxels; wider than high =
// a stretcher bond, every row shifted by half a stone
uniform vec2 block_size = vec2(3.0, 1.5);
// tiles (relief_kind 4, pavement): square tiles of this many voxels
uniform float tile_size = 4.0;
// finer than a voxel, in world coordinates: hairline cracks and pits
uniform float cracks : hint_range(0.0, 1.0) = 0.0;
uniform float pits : hint_range(0.0, 1.0) = 0.0;


// Global tint settings (see Project > Shader Globals and the TintKaart node).
global uniform sampler2D zwervr_tint_map : filter_nearest, repeat_disable;
global uniform vec4 zwervr_tint_area;      // x0, z0, width, depth (metres)
global uniform float zwervr_variation;     // random colour variation per 4 x 4 m cell (0..1)
// 0 = day, 1 = night (day cycle): lamps and lit windows are dimmed by day
global uniform float zwervr_night;
// from afar (zoomed out): strength of a calm noise on the ground (top faces at street
// level), patches of about 12, 4 and 1 m in brightness and (grass, earth) hue, so a
// field of identical tiles doesn't turn into one plain colour; 0 = off
global uniform float zwervr_far_noise;
// grass: strength of the suggested texture on grass (green top faces, recognised by
// their colour): tufts of a few cm with a lit and a shaded side, darker gaps and
// yellowish tips, and clumps of ~25 cm that stay visible further away; colour only (no
// normal), so it never flickers; 0 = off
global uniform float zwervr_grass;
// relief: master strength of everything that suggests depth on stone, brick, tiles,
// cobbles, gravel and asphalt (relief, hairline cracks, pits, asphalt grain); the tour
// switches it off and on to show the difference; 0 = off
global uniform float zwervr_relief;
// undulation: the ground (top faces below 2.5 m) is lit as if it rolled gently, along a
// slow height noise of broad swells of ~18 to 40 m: only the normal tilts (plus a little shade in
// the hollows), the faces stay flat; so a field of identical tiles doesn't look flat.
// Strongest on grass, weaker on paving, hardly on asphalt; 0 = off
global uniform float zwervr_undulation;
// ground type per 4 m cell (scripts/ground_map.gd, the GrondKaart node): R = type
// (material index + 1 + 20 x colour group, grass 200, 0 = none), G = fake height rank / 4
global uniform sampler2D zwervr_ground_types : filter_nearest, repeat_disable;
global uniform vec4 zwervr_ground_area;    // x0, z0, width, depth (metres) of that map
// ground edges: where two kinds of ground meet at street level (asphalt and paving,
// paving and cobbles, ...), a narrow dark joint with a soft contact shadow along the
// shared cell border, so the change of material reads clearly; 0 = off
global uniform float zwervr_ground_edges;

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

// 1 for grass colours: clearly green (green above red and blue), not too dark.
float is_grass(vec3 k) {
	return smoothstep(1.05, 1.25, k.g / max(k.r, 0.001)) * smoothstep(1.2, 1.6, k.g / max(k.b, 0.001))
		* smoothstep(0.01, 0.03, k.g);
}

// Suggested grass texture on a top face (p = world xz in metres, amount 0..1): changes
// only the colour. An even grain (60 and 20 cm), each layer only while it is a few
// pixels big, so there is texture at the usual zoom and no patches from afar; up close,
// gusts drifting over the grass as lighter bands (t = TIME). The blades themselves are
// real geometry (scripts/grass_blades.gd).
void grass_feel(vec2 p, float amount, float t, inout vec3 c) {
	float fw = max(length(fwidth(p)), 1e-4);   // metres per pixel
	// even grain (no patches): soft noise of 60 and 20 cm, each only while it is at least
	// a few pixels big, so it reads as texture without blotches, edges or flicker
	float g1 = (noise(p / 0.6 + 3.1) - 0.5) * smoothstep(2.0, 4.0, 0.6 / fw);
	float g2 = (noise(p / 0.2 + 7.9) - 0.5) * smoothstep(2.0, 4.0, 0.2 / fw);
	c *= 1.0 + (g1 * 0.2 + g2 * 0.16) * amount;
	// gusts of wind: lighter bands (the grass bends and shows its lighter side) drifting
	// slowly in the wind direction, at every distance
	vec2 wind = normalize(vec2(1.0, -0.5));
	vec2 gp = p - wind * t * 2.2;
	float gust = smoothstep(0.6, 0.85, noise(gp * vec2(0.06, 0.03)));
	// the gust shows only up close (lighter blades), so it doesn't make patches from afar
	c *= 1.0 + 0.08 * gust * amount * (1.0 - smoothstep(0.03, 0.08, fw));
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
	float fade_from = 0.6;   // the relief fades once a pixel covers this share of a stone (and is gone at 2.2x)
	if (kind == 1) {
		size = block_size;
		if (size.x > size.y) {
			q.x += mod(floor(uv.y / size.y), 2.0) * size.x * 0.5;
		}
	} else if (kind == 2) {
		size = vec2(3.0, 1.0) * brick_scale;
		q.x += mod(floor(uv.y / brick_scale), 2.0) * 2.0 * brick_scale;
		joint = 0.07;
	} else if (kind == 3) {
		// pebbles of ~12 cm; they stay visible until they are about a pixel small
		size = vec2(1.0);
		joint = 0.03;
		fade_from = 1.2;
	} else if (kind == 4) {
		size = vec2(tile_size);
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
	float visible = (1.0 - smoothstep(fade_from, fade_from * 2.2, fw / min(size.x, size.y))) * zwervr_relief;
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
		// a lit and a shaded side on every pebble, also where the tilted normal is too
		// subtle to read
		c *= 1.0 + dot(d, vec2(-0.7, -0.7)) * 0.8 * relief_strength * visible;
	} else if (kind == 5) {
		vec2 s = fract(q / 3.0) * 3.0;          // 0..3, the stone lies on 0..2
		vec2 d = (s - 1.0) * 0.5;               // -0.5 .. 0.5 across the stone
		bool stone = s.x < 2.0 && s.y < 2.0;
		slope = stone ? d * 1.6 : vec2(0.0);
		edge = stone ? (0.5 - max(abs(d.x), abs(d.y))) * 2.0 : 0.0;
		joint = 0.12;
		// every cobble its own shade (the tiles are flat colours)
		c *= 1.0 + (hash_f(floor(q / 3.0)) - 0.5) * 0.28 * visible;
	} else {
		vec2 e = (0.5 - abs(f)) * size;
		vec2 af = 1.0 - smoothstep(vec2(0.0), vec2(joint * 3.0), e);
		slope = sign(f) * af;
		edge = min(e.x, e.y);
		// every stone its own shade (the tiles are flat colours, palette.py FLAT_GROUPS):
		// bricks and pavers clearly, tiles and blocks subtly; bricks also a little warmer
		// or cooler
		float shade = kind == 2 ? 0.24 : (kind == 1 ? 0.2 : 0.1);
		float hs = hash_f(cell) - 0.5;
		c *= 1.0 + hs * shade * visible;
		if (kind == 2) {
			float hw = hash_f(cell + 7.7) - 0.5;
			c = mix(c, c * vec3(1.0 + hw * 0.15, 1.0, 1.0 - hw * 0.15), visible);
		}
	}
	n = normalize(n + (t * slope.x + b * slope.y) * k);
	// joint: wider and lighter once it gets narrower than a pixel (no flicker)
	float w = max(joint, fw * 0.75);
	return relief_joint * visible * (joint / w) * (1.0 - smoothstep(0.0, w, edge));
}

// Asphalt chippings: an irregular cell pattern (one stone per cell, q in cells).
// Returns (distance to the stone's edge in cells, slope x, slope z of its domed top,
// random 0..1 per stone).
vec4 chippings(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 near = vec2(0.0);
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 pt = o + 0.15 + 0.7 * vec2(hash_f(i + o), hash_f(i + o + 19.7));
			vec2 r = f - pt;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				near = r;
				id = i + o;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float edge = (sqrt(d2) - sqrt(d1)) * 0.5;
	return vec4(edge, near * 1.2, hash_f(id + 3.3));
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
// crack_share scales the cracks only (0 on asphalt, which has its chippings instead).
float cracks_and_pits(vec2 p, vec3 t, vec3 b, inout vec3 n, inout vec3 c, float crack_share) {
	float fw = length(fwidth(p));
	float rougher = 0.0;
	if (cracks > 0.0) {
		// only here and there: areas of a few metres, with a distorted line
		float area = smoothstep(0.4, 0.6, noise(p * 0.45 + 3.1));
		vec2 bend = vec2(noise(p * 3.0), noise(p * 3.0 + 8.3)) * 0.12;
		float d = cell_edge(p + bend, 0.7);
		float wide = 0.012;
		float w = max(wide, fw * 0.75);
		float line = (1.0 - smoothstep(0.0, w, d)) * (wide / w) * area * cracks * zwervr_relief * crack_share;
		line *= 1.0 - smoothstep(0.08, 0.25, fw);   // not from afar
		c *= 1.0 - 0.7 * line;
		rougher += line * 0.2;
	}
	if (pits > 0.0) {
		vec2 q = p * 55.0;   // cells of ~1.8 cm
		float pit = step(0.975, hash_f(floor(q)));
		float d = length(fract(q) - 0.5);
		float visible = 1.0 - smoothstep(0.025, 0.06, fw);
		float deep = pit * (1.0 - smoothstep(0.15, 0.4, d)) * pits * visible * zwervr_relief;
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
		// not on grass: a shade per 4 m cell would make a checkerboard of a meadow
		float cv = zwervr_variation * (1.0 - is_grass(base) * step(0.001, zwervr_grass));
		c *= 1.0 + r1 * cv * 0.35;
		c = mix(c, c * vec3(1.0 + r2 * 0.3, 1.0, 1.0 - r2 * 0.3), cv);
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
	if (zwervr_grass > 0.0 && tintable > 0.5 && !light && wnorm.y > 0.8) {
		float g = is_grass(base) * zwervr_grass;
		if (g > 0.0) {
			grass_feel(vpos.xz, g, TIME, c);
			rough = min(1.0, rough + 0.05 * g);
		}
	}
	if (zwervr_undulation > 0.0 && tintable > 0.5 && !light && wnorm.y > 0.8 && vpos.y < 2.5) {
		vec2 p = vpos.xz;
		float k = zwervr_undulation * mix(0.35, 1.0, is_grass(base)) * smoothstep(2.5, 1.5, vpos.y)
			* (1.0 - 0.8 * asphalt * is_asphalt(base));
		// height (0..1) of broad, slow swells (~18 and 40 m); its world-space slope comes
		// from the screen-space derivatives (cheap: two noise lookups); the tilt stays gentle
		float h = noise(p / 18.0) * 0.7 + noise(p / 40.0 + 9.4) * 0.3;
		vec2 dpx = dFdx(p);
		vec2 dpy = dFdy(p);
		float det = dpx.x * dpy.y - dpx.y * dpy.x;
		vec2 hd = vec2(dFdx(h), dFdy(h));
		float hx = abs(det) > 1e-8 ? (hd.x * dpy.y - hd.y * dpx.y) / det : 0.0;
		float hz = abs(det) > 1e-8 ? (hd.y * dpx.x - hd.x * dpy.x) / det : 0.0;
		vec2 slope = vec2(hx, hz) * 4.0 * k;
		slope /= max(1.0, length(slope) / 0.1);
		nw = normalize(nw - vec3(slope.x, 0.0, slope.y));
		c *= 1.0 - (0.5 - h) * 0.05 * k;   // barely darker in the hollows
	}
	if (zwervr_ground_edges > 0.0 && tintable > 0.5 && !light && wnorm.y > 0.8 && vpos.y < 1.5 && zwervr_ground_area.z > 0.0) {
		// every border between two kinds of ground tiles (grass, road, cycle path, pavement,
		// gravel, ...) reads as a small step (ranks from scripts/ground_map.gd): the higher
		// side gets a rounded, lighter edge (the normal also tilts towards the border, so
		// the sun lights or shades it), the lower side a contact shadow, and a dark joint
		// lies between them
		vec2 cf = (vpos.xz - zwervr_ground_area.xy) / 4.0;   // position in cells
		ivec2 ci = ivec2(floor(cf));
		ivec2 sz = textureSize(zwervr_ground_types, 0);
		if (ci.x >= 0 && ci.y >= 0 && ci.x < sz.x && ci.y < sz.y) {
			vec2 own = texelFetch(zwervr_ground_types, ci, 0).rg;
			int own_type = int(own.r * 255.0 + 0.5);
			vec2 f = fract(cf) * 4.0;   // metres inside the cell
			float edge = 9.0;           // distance (m) to the nearest border with other ground
			float step_up = 0.0;        // rank of the neighbour minus ours there
			vec2 outward = vec2(0.0);   // world direction towards that border
			ivec2 dirs[4] = {ivec2(-1, 0), ivec2(1, 0), ivec2(0, -1), ivec2(0, 1)};
			float dist[4] = {f.x, 4.0 - f.x, f.y, 4.0 - f.y};
			for (int k = 0; k < 4; k++) {
				if (dist[k] < 0.35 && dist[k] < edge) {
					vec2 other = texelFetch(zwervr_ground_types, clamp(ci + dirs[k], ivec2(0), sz - 1), 0).rg;
					int other_type = int(other.r * 255.0 + 0.5);
					if (own_type > 0 && other_type > 0 && other_type != own_type) {
						edge = dist[k];
						step_up = (other.g - own.g) * 4.0;
						outward = vec2(dirs[k]);
					}
				}
			}
			if (edge < 0.35) {
				float g = zwervr_ground_edges;
				float fwe = length(fwidth(vpos.xz));
				float h = clamp(abs(step_up), 0.0, 1.5) / 1.5;   // size of the fake step
				if (step_up < 0.0) {
					// we are higher: a rounded edge of ~6 cm, tilting towards the border
					float bevel = (1.0 - smoothstep(0.0, max(0.06, fwe * 1.5), edge)) * (0.4 + 0.6 * h);
					nw = normalize(nw + vec3(outward.x, 0.0, outward.y) * 0.9 * bevel * g);
					c *= 1.0 + 0.22 * bevel * g;
				} else if (step_up > 0.0) {
					// we are lower: a contact shadow at the foot of the step
					float shade = (1.0 - smoothstep(0.0, 0.08 + 0.2 * h, edge)) * (0.4 + 0.6 * h);
					c *= 1.0 - 0.5 * shade * g;
				}
				float w = max(0.025, fwe * 0.8);
				float joint = (1.0 - smoothstep(0.0, w, edge)) * (0.025 / w);
				c *= 1.0 - 0.65 * joint * g;
				rough = min(1.0, rough + 0.1 * joint * g);
			}
		}
	}
	if (relief_kind == 3 && !light) {
		// gravel: patches of pebbles of a slightly different shade (~15 cm), visible
		// further away than the pebbles themselves
		float fw3 = length(fwidth(vpos.xz));
		float patches = 1.0 - smoothstep(0.05, 0.15, fw3);
		c *= 1.0 + (noise(vpos.xz * 7.0) - 0.5) * 0.18 * patches * relief_strength * zwervr_relief;
	}
	if (relief_kind > 0 && zwervr_relief > 0.0 && !light) {
		vec3 t;
		vec3 b;
		uv2_axes(vpos, UV2, t, b);
		float joint = relief(UV2, t, b, abs(wnorm.y) < 0.5, nw, c);
		c *= 1.0 - joint;
		rough = min(1.0, rough + joint * 0.3);
	}
	float a = asphalt > 0.0 && !light ? asphalt * mix(1.0, is_asphalt(base), asphalt_colour_check) * smoothstep(0.85, 0.95, wnorm.y) : 0.0;
	if ((cracks > 0.0 || pits > 0.0) && zwervr_relief > 0.0 && !light) {
		vec3 an = abs(wnorm);
		vec3 t = an.x > 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		vec3 b = an.y > 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
		// asphalt gets its chippings instead of cracks (below)
		rough = min(1.0, rough + cracks_and_pits(vec2(dot(vpos, t), dot(vpos, b)), t, b, nw, c, 1.0 - a));
	}
	if (a > 0.0) {
		vec2 p = vpos.xz;
		// wear patches of a few metres: a bit darker and smoother (tyre tracks, oil)
		float wear = noise(p * 0.35) * 0.65 + noise(p * 1.1 + 7.1) * 0.35;
		c *= 1.0 + (wear - 0.5) * 0.16 * a;
		// fine, even speckle (the tiles are one flat colour): random grains of 4 and 10 cm,
		// each only while it is at least about a pixel big, so the road has grain at the
		// usual zoom levels without blotches or flicker
		float fwm = max(length(fwidth(p)), 1e-4);
		float s1 = (hash_f(floor(p / 0.04) + 11.0) - 0.5) * smoothstep(0.8, 2.0, 0.04 / fwm);
		float s2 = (hash_f(floor(p / 0.1) + 23.0) - 0.5) * smoothstep(0.8, 2.0, 0.1 / fwm);
		c *= 1.0 + (s1 * 0.2 + s2 * 0.12) * a * zwervr_relief;
		rough = mix(rough, asphalt_roughness + (wear - 0.5) * 0.16, a);
		spec = mix(spec, asphalt_specular, a);
		// the pattern of asphalt itself: chippings of ~4 cm in dark bitumen, each stone
		// its own shade of grey with a slightly domed top the sun glints on; fades once a
		// stone gets smaller than a pixel (else it flickers from afar), the roughness then
		// keeps the average
		float visible = a * zwervr_relief * (1.0 - smoothstep(0.5, 1.2, length(fwidth(p)) / 0.04));
		if (visible > 0.0) {
			// soften the 12.5 cm voxel blocks first (average with neighbouring texels of
			// the same face; the 1-texel border keeps it inside the tile), so the
			// chippings carry the texture instead of the voxel grid
			if (use_atlas) {
				vec2 tx = 0.7 / vec2(textureSize(albedo_atlas, 0));
				vec3 sm = (textureLod(albedo_atlas, UV + vec2(tx.x, 0.0), 0.0).rgb + textureLod(albedo_atlas, UV - vec2(tx.x, 0.0), 0.0).rgb
					+ textureLod(albedo_atlas, UV + vec2(0.0, tx.y), 0.0).rgb + textureLod(albedo_atlas, UV - vec2(0.0, tx.y), 0.0).rgb) * 0.25 * COLOR.a;
				sm = mix(base, sm, is_asphalt(sm));   // not into road markings
				c *= mix(vec3(1.0), (sm + base) * 0.5 / max(base, vec3(0.001)), 0.85 * visible);
			}
			vec4 v = chippings(p / 0.04);
			float stone = 1.0 - smoothstep(0.04, 0.16, v.x);   // 0 on the stone, 1 in the binder
			c *= 1.0 + ((v.w - 0.5) * 0.4 * (1.0 - stone) - stone * 0.45) * visible;
			rough -= ((1.0 - stone) * 0.12 + (v.w - 0.5) * 0.1) * visible;
			nw = normalize(nw + vec3(-v.y, 0.0, -v.z) * 0.6 * (1.0 - stone) * visible);
		}
	}
	// cheap tests first: only ground (faces pointing up, below 2.5 m), not on top of the
	// asphalt's own wear, and only once a pixel covers more than a few cm (up close the
	// voxels carry the detail)
	if (zwervr_far_noise > 0.0 && tintable > 0.5 && !light && wnorm.y > 0.5 && vpos.y < 2.5) {
		float mpp = length(fwidth(vpos.xz));   // metres per pixel
		// grass has its own noise at every distance (grass_feel)
		float far = zwervr_far_noise * smoothstep(0.03, 0.1, mpp) * smoothstep(0.5, 0.9, wnorm.y)
			* smoothstep(2.5, 1.5, vpos.y) * (1.0 - 0.85 * a) * (1.0 - is_grass(base) * step(0.001, zwervr_grass));
		if (far > 0.0) {
			vec2 p = vpos.xz;
			float n = noise(p * 0.08) * 0.6 + noise(p * 0.4 + 3.1) * 0.4;
			c *= 1.0 + (n - 0.5) * 0.45 * far;
			// coloured ground (grass, earth) also shifts in hue: drier and lusher patches
			float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
			float h = noise(p * 0.05 + 11.3) - 0.5;
			c = mix(c, c * vec3(1.0 + h * 0.5, 1.0 + h * 0.1, 1.0 - h * 0.4), far * smoothstep(0.02, 0.12, sat));
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
