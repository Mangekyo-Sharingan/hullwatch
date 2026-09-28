// Analogue-horror post-processing: barrel warp, radial chromatic aberration, warm film grade,
// scanlines, animated grain, dust specks, slow scratches, vignette and flicker.
// Tuned against the Starpath/terminal reference set. 0.0 leaves the frame untouched.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float grain_amount : hint_range(0.0, 0.25) = 0.085;
uniform float aberration : hint_range(0.0, 0.02) = 0.0028;
uniform float scanline_amount : hint_range(0.0, 0.5) = 0.07;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.55;
uniform float desaturation : hint_range(0.0, 1.0) = 0.28;
uniform float warp_amount : hint_range(0.0, 0.1) = 0.015;
uniform float flicker_amount : hint_range(0.0, 0.2) = 0.025;
uniform float scratch_amount : hint_range(0.0, 0.2) = 0.025;
uniform float dust_amount : hint_range(0.0, 0.2) = 0.03;
uniform vec3 warm_tint : source_color = vec3(1.03, 0.985, 0.93);

const vec3 LUMA_WEIGHTS = vec3(0.2126, 0.7152, 0.0722);
const vec3 TEAL_SHADOW_TINT = vec3(0.94, 1.0, 1.05);
const vec3 BLACK_FLOOR = vec3(0.012, 0.013, 0.016);

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	float active = clamp(intensity, 0.0, 1.0);
	vec2 centered = SCREEN_UV - vec2(0.5);
	float radius = length(centered);

	// Subtle barrel warp: the lens bows the frame outward toward the edges.
	vec2 warped_uv = vec2(0.5) + centered * (1.0 + warp_amount * active * radius * radius);

	// Radial chromatic aberration: the R/B split grows with the distance from centre.
	float split = aberration * active * (0.25 + radius * 1.75);
	vec3 color;
	color.r = texture(screen_texture, warped_uv + centered * split).r;
	color.g = texture(screen_texture, warped_uv).g;
	color.b = texture(screen_texture, warped_uv - centered * split).b;

	// Pull the palette toward luma, then warm the highlights like aged stock.
	float luma = dot(color, LUMA_WEIGHTS);
	color = mix(color, vec3(luma), desaturation * active);
	color *= mix(vec3(1.0), warm_tint, active);

	// Faint cool cast in the darks, plus a slight black lift so nothing is pure black.
	float shadow_weight = 1.0 - smoothstep(0.0, 0.45, luma);
	color = mix(color, color * TEAL_SHADOW_TINT, shadow_weight * active * 0.35);
	color = mix(color, BLACK_FLOOR, active * 0.5);

	// Fixed-frequency horizontal scanlines.
	float scanline = 0.5 + 0.5 * sin(warped_uv.y * 900.0);
	color *= 1.0 - scanline_amount * active * scanline;

	// Animated hash grain.
	float grain = hash21(warped_uv * vec2(1920.0, 1080.0) + vec2(fract(TIME * 17.31), fract(TIME * 9.73)));
	color += (grain - 0.5) * grain_amount * active;

	// Sparse dust specks on a coarse grid, resampled slowly.
	vec2 dust_cell = floor(warped_uv * vec2(160.0, 90.0));
	float dust = step(0.9975, hash21(dust_cell + floor(TIME * 0.25)));
	color *= 1.0 - dust * dust_amount * active;

	// One or two drifting vertical scratches.
	float lane = floor(warped_uv.x * 240.0);
	float scratch = step(0.9975, hash21(vec2(lane, floor(TIME * 0.4))));
	float scratch_fade = 0.5 + 0.5 * sin(TIME * 31.0 + lane);
	color += vec3(scratch * scratch_fade * scratch_amount * active);

	// Heavy smoothstep vignette.
	float edge = smoothstep(0.35, 1.05, radius * 1.41421356);
	color *= 1.0 - vignette_amount * active * edge;

	// Slow brightness flicker.
	color *= 1.0 + flicker_amount * active * sin(TIME * 1.3);

	COLOR = vec4(color, 1.0);
}
