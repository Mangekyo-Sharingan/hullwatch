shader_type sky;

uniform vec3 top_color : source_color = vec3(0.004, 0.006, 0.012);
uniform vec3 horizon_color : source_color = vec3(0.012, 0.016, 0.024);
uniform float star_threshold : hint_range(0.99, 0.9999) = 0.9975;
uniform float star_brightness : hint_range(0.0, 4.0) = 1.6;
uniform vec3 star_tint : source_color = vec3(0.8, 0.86, 1.0);
uniform vec3 sun_direction = vec3(0.2, 0.5, -0.84);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.75);
uniform float sun_size : hint_range(0.001, 0.05) = 0.012;
uniform vec3 planet_direction = vec3(-0.55, 0.28, 0.62);
uniform vec3 planet_color : source_color = vec3(0.3, 0.38, 0.55);
uniform vec3 planet_band_color : source_color = vec3(0.52, 0.58, 0.72);
uniform float planet_size : hint_range(0.01, 0.2) = 0.055;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float horizon_mix = clamp(dir.y * 0.6 + 0.45, 0.0, 1.0);
	vec3 color = mix(horizon_color, top_color, horizon_mix);
	vec3 cell = floor(dir * 260.0);
	float star_hash = hash13(cell);
	float star = step(star_threshold, star_hash) * star_brightness * (0.5 + 0.5 * hash13(cell + 7.0));
	color += star * star_tint;
	float sun = 1.0 - smoothstep(sun_size * 0.35, sun_size, distance(dir, normalize(sun_direction)));
	color += sun * sun_color * 2.5;
	vec3 planet_axis = normalize(planet_direction);
	float planet = 1.0 - smoothstep(planet_size * 0.93, planet_size, distance(dir, planet_axis));
	if (planet > 0.0) {
		float band = sin((dir.y - planet_axis.y) * 120.0 + hash13(planet_axis) * 6.0) * 0.5 + 0.5;
		vec3 surface = mix(planet_color, planet_band_color, band * 0.6);
		color = mix(color, surface, planet);
	}
	COLOR = color;
}
