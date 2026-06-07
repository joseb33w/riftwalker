shader_type spatial;

// Triplanar-ish tiled ground that hides seams and keeps mobile cost low.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile = 12.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rough = 0.92;
uniform float metallic_v = 0.0;
uniform float macro_strength = 0.18;

void fragment() {
	vec2 uv = UV * tile;
	vec3 c = texture(albedo_tex, uv).rgb;
	// large-scale value variation so big planes don't look flat-tiled
	float macro = texture(albedo_tex, UV * 1.3).r;
	c *= (1.0 - macro_strength) + macro_strength * macro * 2.0;
	ALBEDO = c * tint.rgb;
	ROUGHNESS = rough;
	METALLIC = metallic_v;
}
