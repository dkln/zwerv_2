shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;

uniform float opacity : hint_range(0.0, 1.0) = 0.38;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = COLOR.rgb * 0.7;
	ROUGHNESS = 0.04;
	METALLIC = 0.25;
	SPECULAR = 0.9;
	ALPHA = clamp(opacity + fres * 0.5, 0.0, 0.95);
}
