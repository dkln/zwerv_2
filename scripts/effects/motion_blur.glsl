#[compute]
#version 450
// Bewegingsonscherpte: middelt de kleur langs de bewegingsvector van elke pixel.
// Pas 0 kopieert het beeld naar een hulptextuur, pas 1 vervaagt daaruit terug.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D kleur;
layout(set = 0, binding = 1) uniform sampler2D bron;
layout(set = 0, binding = 2) uniform sampler2D snelheid;
layout(rgba16f, set = 0, binding = 3) uniform image2D kopie;

layout(push_constant, std430) uniform Params {
	vec2 grootte;
	float sterkte;
	float max_lengte;   // in UV, voorkomt vegen bij een sprong van de camera
	float stappen;
	float pas;
	float pad1;
	float pad2;
} p;

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= int(p.grootte.x) || px.y >= int(p.grootte.y)) {
		return;
	}
	if (p.pas < 0.5) {
		imageStore(kopie, px, imageLoad(kleur, px));
		return;
	}
	vec2 uv = (vec2(px) + 0.5) / p.grootte;
	vec2 v = texture(snelheid, uv).xy * p.sterkte;
	float l = length(v);
	if (l * p.grootte.x < 0.5) {
		return;   // minder dan een halve pixel: niets te doen
	}
	if (l > p.max_lengte) {
		v *= p.max_lengte / l;
	}
	int n = int(p.stappen);
	vec4 som = vec4(0.0);
	for (int i = 0; i < n; i++) {
		float t = (float(i) + 0.5) / float(n) - 0.5;
		som += texture(bron, uv + v * t);
	}
	imageStore(kleur, px, som / float(n));
}
