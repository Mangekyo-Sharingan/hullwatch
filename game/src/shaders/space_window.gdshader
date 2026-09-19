shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 space_top : source_color = vec3(0.10, 0.13, 0.20);
uniform vec3 space_bottom : source_color = vec3(0.03, 0.04, 0.07);
uniform vec2 planet_uv = vec2(0.66, 0.56);
uniform float planet_radius : hint_range(0.02, 0.3) = 0.15;
uniform vec3 planet_color : source_color = vec3(0.55, 0.68, 0.88);
uniform vec3 planet_band : source_color = vec3(0.75, 0.82, 0.95);
uniform vec3 star_tint : source_color = vec3(1.0, 1.0, 1.0);

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 color = mix(space_bottom, space_top, uv.y);
	vec2 cell = floor(uv * vec2(160.0, 90.0));
	float star = step(0.995, hash12(cell)) * (0.8 + 1.6 * hash12(cell + 3.7));
	color += star * star_tint;
	float d = distance(uv, planet_uv);
	if (d < planet_radius * 1.18) {
		float band = sin((uv.y - planet_uv.y) * 90.0) * 0.5 + 0.5;
		vec3 surface = mix(planet_color, planet_band, band * 0.65);
		surface += vec3(0.35, 0.5, 0.75) * smoothstep(planet_radius * 1.18, planet_radius, d) * 0.5;
		color = mix(color, surface, smoothstep(planet_radius * 1.18, planet_radius * 0.94, d));
	}
	ALBEDO = color;
	EMISSION = color * 1.3;
}
