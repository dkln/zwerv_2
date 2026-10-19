shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_burley;

// kleur per voxel uit de texture-atlas van de bibliotheek (UV); niet ingesteld = wit
uniform sampler2D albedo_atlas : source_color, hint_default_white, filter_nearest_mipmap;

// Laat vlaggen wapperen. Hoe verder een voxel van de mast (het midden van het
// model) zit, hoe meer hij beweegt.
uniform float snelheid = 3.0;
uniform float golflengte = 1.6;
uniform float sterkte = 0.12;
uniform float mast_afstand = 0.15;

void vertex() {
	vec2 d = VERTEX.xz;
	float r = length(d);
	float f = clamp((r - mast_afstand) / 1.2, 0.0, 1.0);
	vec2 dir = r > 0.001 ? d / r : vec2(1.0, 0.0);
	vec2 loodrecht = vec2(-dir.y, dir.x);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float g = sin(TIME * snelheid - r * golflengte * 3.0 + wp.x * 0.3 + wp.z * 0.2);
	VERTEX.xz += loodrecht * g * sterkte * f;
	VERTEX.y += cos(TIME * snelheid * 0.7 - r * 2.0) * sterkte * 0.25 * f;
}

void fragment() {
	ALBEDO = (COLOR.rgb * texture(albedo_atlas, UV).rgb);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
