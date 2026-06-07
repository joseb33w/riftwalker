shader_type spatial;
render_mode vertex_lighting;

// PSX-flavoured ground: vertex snapping + affine-ish tiling + nearest texel + posterize.
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform float tile = 10.0;
uniform float snap = 110.0;
uniform vec4 tint : source_color = vec4(0.62, 0.6, 0.58, 1.0);
uniform float levels = 6.0;

void vertex() {
	vec4 c = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	c.xyz = floor(c.xyz / c.w * snap) / snap * c.w;
	POSITION = c;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV * tile).rgb * tint.rgb;
	ivec2 p = ivec2(mod(FRAGCOORD.xy, 4.0));
	float bayer = float((p.x + p.y * 4) % 16) / 16.0;
	c = floor(c * levels + bayer) / levels;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
