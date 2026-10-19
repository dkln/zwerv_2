shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;

#include "res://addons/vox_tiles/materials/voxel_colour.gdshaderinc"


// Glas met een nagebootste spiegeling (goedkoop, geen schermbuffer): de gespiegelde
// kijkrichting kiest tussen lucht, horizon en een donkere stad/straat,
// met lichte schuine strepen. Schuin bekeken spiegelt glas meer (fresnel).

uniform float opacity : hint_range(0.0, 1.0) = 0.38;
uniform float spiegeling : hint_range(0.0, 1.0) = 0.5;
uniform vec3 stad : source_color = vec3(0.24, 0.25, 0.26);

// luchtkleuren komen uit de dagcyclus (Project > Shader Globals)
global uniform vec4 zwervr_lucht_boven : source_color;
global uniform vec4 zwervr_lucht_horizon : source_color;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v, n);
	vec3 omgeving = mix(zwervr_lucht_horizon.rgb, zwervr_lucht_boven.rgb, smoothstep(0.05, 0.6, r.y));
	omgeving = mix(stad, omgeving, smoothstep(-0.6, 0.08, r.y));
	// schuine lichtstrepen die meeschuiven met de kijkhoek
	float streep = smoothstep(0.82, 1.0, sin((wpos.x + wpos.z) * 0.9 + wpos.y * 1.4 + r.x * 3.0) * 0.5 + 0.5);
	omgeving += streep * 0.12;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float s = clamp(spiegeling + fres * 0.4, 0.0, 1.0);
	ALBEDO = voxel_albedo(UV, COLOR) * 0.7 * (1.0 - s);
	EMISSION = omgeving * s;
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = clamp(opacity + s * 0.35 + fres * 0.3, 0.0, 0.95);
}
