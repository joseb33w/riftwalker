shader_type spatial;

uniform vec4 base : source_color = vec4(0.25, 0.85, 0.7, 1.0);
uniform vec4 rim : source_color = vec4(0.4, 1.0, 0.9, 1.0);
uniform float rim_power = 2.5;
uniform float emit_energy = 1.6;
uniform float metallic_v = 0.2;
uniform float roughness_v = 0.5;

void fragment() {
	ALBEDO = base.rgb;
	METALLIC = metallic_v;
	ROUGHNESS = roughness_v;
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	EMISSION = rim.rgb * f * emit_energy;
}
