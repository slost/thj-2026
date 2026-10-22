shader_type canvas_item;

// Bubble silhouette distortion from bubble_effect.gdshader, then an outline
// sampled on that distorted shape so the ring breathes and wobbles with it.

group_uniforms Instance;
instance uniform float instance_seed = 0.0;

group_uniforms Breathing;
uniform float breathing_speed : hint_range(0.0, 5.0, 0.01) = 1.0;
uniform float breathing_strength : hint_range(0.0, 0.1, 0.001) = 0.025;

group_uniforms Wobble;
uniform float wobble_speed : hint_range(0.0, 5.0, 0.01) = 1.2;
uniform float wobble_strength : hint_range(0.0, 0.05, 0.001) = 0.012;

group_uniforms Distortion;
uniform float distortion_speed : hint_range(0.0, 5.0, 0.01) = 0.8;
uniform float distortion_strength : hint_range(0.0, 0.05, 0.001) = 0.008;

group_uniforms Outline;
uniform vec4 clr : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int type : hint_range(0, 2) = 2;
uniform float thickness = 1.0;
uniform bool outline_only = true;

const vec2[8] DIRECTIONS = {
	vec2(1.0, 0.0),
	vec2(0.0, 1.0),
	vec2(-1.0, 0.0),
	vec2(0.0, -1.0),
	vec2(1.0, 1.0),
	vec2(-1.0, 1.0),
	vec2(-1.0, -1.0),
	vec2(1.0, -1.0)
};


float gtz(float input) {
	return max(0.0, sign(input));
}


float check(sampler2D tex, vec2 from, vec2 size) {
	float result = 0.0;
	for (int i = 0; i < 4 * type; i++) {
		result += texture(tex, from + DIRECTIONS[i] * size * thickness).a;
	}
	return gtz(result);
}


vec2 bubble_uv(vec2 uv) {
	vec2 centered_uv = uv - vec2(0.5);
	float distance_from_center = length(centered_uv) * 2.0;
	float edge_factor = smoothstep(0.2, 1.0, distance_from_center);
	float time = TIME;

	float breathing_phase = instance_seed;
	float wobble_phase = instance_seed * 1.73;
	float distortion_phase = instance_seed * 2.41;

	float breathing = sin(
		time * breathing_speed * TAU + breathing_phase
	) * breathing_strength;

	float wobble_x = sin(
		centered_uv.y * 7.0 +
		time * wobble_speed * TAU +
		wobble_phase
	) * wobble_strength * edge_factor;

	float wobble_y = cos(
		centered_uv.x * 6.0 +
		time * wobble_speed * 0.8 * TAU +
		wobble_phase
	) * wobble_strength * edge_factor;

	float distortion_x = sin(
		centered_uv.y * 12.0 +
		time * distortion_speed * TAU +
		distortion_phase
	) * distortion_strength * edge_factor;

	float distortion_y = cos(
		centered_uv.x * 11.0 +
		time * distortion_speed * 0.9 * TAU +
		distortion_phase
	) * distortion_strength * edge_factor;

	centered_uv += vec2(
		wobble_x + distortion_x,
		wobble_y + distortion_y
	);
	centered_uv *= 1.0 - breathing;
	return centered_uv + vec2(0.5);
}


void fragment() {
	vec2 distorted_uv = bubble_uv(UV);
	vec4 tex = texture(TEXTURE, distorted_uv);
	float edge = check(TEXTURE, distorted_uv, TEXTURE_PIXEL_SIZE) * (1.0 - gtz(tex.a));

	if (outline_only) {
		COLOR = vec4(clr.rgb, clr.a * edge);
	} else {
		COLOR = mix(tex, vec4(clr.rgb, tex.a), edge);
	}
}
