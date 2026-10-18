shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

// Golvend water. Het oppervlak deint met golven uit verschillende richtingen
// (daardoor niet rechtlijnig) en heeft lichte, bewegende vlekken en glinsteringen.
// De golven lopen in wereldcoördinaten door over aangrenzende tiles.
// Spiegeling: de gespiegelde kijkstraal wordt in een paar stappen over het
// scherm gevolgd (diepte- en schermbuffer, geen raytracing). Wat hij raakt,
// spiegelt in het water; anders spiegelt de lucht. (De SSR van Godot gaf hier
// geen zichtbare spiegeling.)

uniform float golf_hoogte : hint_range(0.0, 0.2) = 0.04;   // meter
uniform float golf_snelheid = 0.7;
uniform float golf_lengte = 6.0;                            // meter tussen twee toppen
uniform float vlekken : hint_range(0.0, 1.0) = 0.35;       // lichte bewegende vlekken
uniform float glinstering : hint_range(0.0, 1.0) = 0.1;
uniform float spiegeling : hint_range(0.0, 1.0) = 0.17;        // voor gespiegelde objecten
uniform float lucht_spiegeling : hint_range(0.0, 1.0) = 0.06;  // voor de lucht
uniform float stap = 1.0;                                   // meter per stap
uniform int stappen = 12;
uniform float dikte = 2.0;                                  // meter: hoe dik een geraakt object telt
uniform float rimpeling = 0.35;                             // vervorming van de spiegeling door golven

uniform sampler2D scherm : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D diepte : hint_depth_texture, filter_nearest, repeat_disable;

global uniform vec4 zwervr_lucht_boven : source_color;
global uniform vec4 zwervr_lucht_horizon : source_color;

varying float is_top;
varying vec3 wpos;

float ruis(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// golven uit vier richtingen met verschillende lengtes: geen rechte banen
float golf(vec2 p, float t) {
	float k = 6.2831 / golf_lengte;
	float g = sin(dot(p, vec2(0.94, 0.34)) * k + t) * 0.35;
	g += sin(dot(p, vec2(-0.42, 0.91)) * k * 1.37 - t * 0.83) * 0.28;
	g += sin(dot(p, vec2(0.68, -0.73)) * k * 0.71 + t * 0.61) * 0.22;
	g += sin(dot(p, vec2(-0.99, -0.12)) * k * 2.13 + t * 1.27) * 0.15;
	return g;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	is_top = step(0.5, NORMAL.y);
	float t = TIME * golf_snelheid;
	VERTEX.y += golf(w.xz, t) * golf_hoogte * is_top;
	// normaal volgt de golf, zodat belichting en spiegeling meebewegen
	float e = 0.1;
	float hx = (golf(w.xz + vec2(e, 0.0), t) - golf(w.xz - vec2(e, 0.0), t)) / (2.0 * e) * golf_hoogte;
	float hz = (golf(w.xz + vec2(0.0, e), t) - golf(w.xz - vec2(0.0, e), t)) / (2.0 * e) * golf_hoogte;
	NORMAL = mix(NORMAL, normalize(vec3(-hx, 1.0, -hz)), is_top);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 naar_scherm(vec3 w, mat4 view, mat4 proj) {
	vec4 c = proj * (view * vec4(w, 1.0));
	return c.xy / c.w * 0.5 + 0.5;
}

void fragment() {
	float t = TIME * golf_snelheid;
	// lichte vlekken: twee lagen ruis die langzaam langs elkaar schuiven
	float v1 = ruis(wpos.xz * 0.35 + vec2(t * 0.13, t * 0.07));
	float v2 = ruis(wpos.xz * 0.9 - vec2(t * 0.09, -t * 0.11));
	float vlek = smoothstep(0.45, 0.95, v1 * 0.6 + v2 * 0.4);
	// glinsteringen: kleine, snel wisselende lichtpuntjes
	float gl = smoothstep(0.86, 0.98, ruis(wpos.xz * 3.1 + vec2(t * 0.5, -t * 0.4)) * ruis(wpos.xz * 2.3 - vec2(t * 0.3)) * 1.6);
	vec3 basis = COLOR.rgb * (0.55 + vlek * vlekken * 0.35);

	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 kijk = -normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	// golven vervormen de spiegeling iets sterker dan de belichting
	vec3 nr = normalize(mix(vec3(0.0, 1.0, 0.0), n, 1.0 + rimpeling * 4.0));
	vec3 r = reflect(kijk, nr);
	r.y = abs(r.y);
	vec3 kleur = mix(zwervr_lucht_horizon.rgb, zwervr_lucht_boven.rgb, smoothstep(0.0, 0.7, r.y));
	float raak = 0.0;
	if (is_top > 0.5) {
		for (int i = 1; i <= stappen; i++) {
			vec3 q = wpos + r * (float(i) * stap);
			vec2 uv = naar_scherm(q, VIEW_MATRIX, PROJECTION_MATRIX);
			if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
				break;
			}
			float d = texture(diepte, uv).r;
			vec4 v = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, d, 1.0);
			float verschil = v.z / v.w - (VIEW_MATRIX * vec4(q, 1.0)).z;   // > 0: straal ligt achter de geometrie
			if (verschil > 0.0 && verschil < dikte) {
				kleur = texture(scherm, uv).rgb;
				raak = 1.0;
				break;
			}
		}
	}
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float s = clamp(mix(lucht_spiegeling, spiegeling, raak) + fres * 0.05, 0.0, 1.0) * is_top;
	ALBEDO = basis * (1.0 - s);
	EMISSION = kleur * s + vec3(gl * glinstering * 0.6) * is_top;
	ROUGHNESS = 0.35;
	SPECULAR = 0.15;
}
