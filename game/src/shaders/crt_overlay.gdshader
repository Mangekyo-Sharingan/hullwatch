// CRT overlay for diegetic screens: horizontal scanlines, radial vignette, slow
// brightness flicker, hash grain and drifting scratches. Draws black with a
// varying alpha on top of panel content, so the content is darkened, never
// recoloured. `intensity` scales every effect; 0.0 leaves the panel untouched.
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float scanline_amount : hint_range(0.0, 0.5) = 0.12;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.45;
uniform float flicker_amount : hint_range(0.0, 0.2) = 0.03;
uniform float grain_amount : hint_range(0.0, 0.25) = 0.05;
uniform float scratch_amount : hint_range(0.0, 0.1) = 0.03;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	float active = clamp(intensity, 0.0, 1.0);

	// Fixed-frequency horizontal scanlines.
	float scanline = 0.5 + 0.5 * sin(UV.y * 800.0);
	float alpha = scanline_amount * active * scanline;

	// Smoothstep vignette darkening outward from the panel centre.
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered) * 1.41421356;
	alpha += vignette_amount * active * smoothstep(0.5, 1.0, radius);

	// Slow brightness wobble: on a darkening overlay it reads as alpha breathing.
	alpha += flicker_amount * active * (0.5 + 0.5 * sin(TIME * 1.3));

	// Animated hash grain.
	float grain = hash21(UV * vec2(1920.0, 1080.0) + vec2(fract(TIME * 17.31), fract(TIME * 9.73)));
	alpha += grain * grain_amount * active;

	// Two thin bright vertical lines that step to new positions slowly with TIME.
	float scratch_slot = floor(TIME * 0.4);
	float scratch_a = 1.0 - smoothstep(0.0, 0.003, abs(UV.x - (0.05 + 0.9 * hash21(vec2(scratch_slot, 11.3)))));
	float scratch_b = 1.0 - smoothstep(0.0, 0.003, abs(UV.x - (0.05 + 0.9 * hash21(vec2(scratch_slot, 47.9)))));
	alpha -= max(scratch_a, scratch_b) * scratch_amount * active;

	COLOR = vec4(0.0, 0.0, 0.0, clamp(alpha, 0.0, 1.0));
}
