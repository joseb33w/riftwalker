shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, specular_disabled;

uniform float outline = 0.025;
uniform vec4 col : source_color = vec4(0.04, 0.03, 0.05, 1.0);

void vertex() {
	VERTEX += normalize(NORMAL) * outline;
}

void fragment() {
	ALBEDO = col.rgb;
}
