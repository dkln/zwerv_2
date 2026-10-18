shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;

// Eenvoudig golvend water: het bovenvlak beweegt rustig op en neer.
// De golven lopen in wereldcoördinaten door over aangrenzende tiles.

uniform float opacity : hint_range(0.0, 1.0) = 0.85;
uniform float golf_hoogte : hint_range(0.0, 0.2) = 0.04;   // meter
uniform float golf_snelheid = 0.7;
uniform float golf_lengte = 6.0;                            // meter tussen twee toppen

varying float is_top;

float golf(vec2 p, float t) {
	float k = 6.2831 / golf_lengte;
	return sin(p.x * k + t) * 0.6 + sin(p.y * k * 0.8 - t * 0.8) * 0.4;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	is_top = step(0.5, NORMAL.y);
	float t = TIME * golf_snelheid;
	VERTEX.y += golf(w.xz, t) * golf_hoogte * is_top;
	// normaal volgt de golf, zodat de belichting meebeweegt
	float e = 0.1;
	float hx = (golf(w.xz + vec2(e, 0.0), t) - golf(w.xz - vec2(e, 0.0), t)) / (2.0 * e) * golf_hoogte;
	float hz = (golf(w.xz + vec2(0.0, e), t) - golf(w.xz - vec2(0.0, e), t)) / (2.0 * e) * golf_hoogte;
	NORMAL = mix(NORMAL, normalize(vec3(-hx, 1.0, -hz)), is_top);
}

void fragment() {
	ALBEDO = COLOR.rgb * 0.8;
	ROUGHNESS = 0.15;
	SPECULAR = 0.5;
	ALPHA = opacity;
}
