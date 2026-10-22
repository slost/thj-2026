shader_type canvas_item;


group_uniforms Instance;

/**
 * Phase offset for this bubble.
 * Use a different value for each instance to prevent synchronized motion.
 */
instance uniform float instance_seed = 0.0;


group_uniforms Breathing;

/**
 * Breathing speed in cycles per second.
 * Higher values make the bubble expand and contract faster.
 */
uniform float breathing_speed : hint_range(0.0, 5.0, 0.01) = 1.0;

/**
 * Breathing deformation strength.
 * Higher values make the bubble expand and contract more.
 */
uniform float breathing_strength : hint_range(0.0, 0.1, 0.001) = 0.025;


group_uniforms Wobble;

/**
 * Wobble animation speed in cycles per second.
 * Higher values make the bubble surface move faster.
 */
uniform float wobble_speed : hint_range(0.0, 5.0, 0.01) = 1.2;

/**
 * Wobble deformation strength.
 * Higher values make the bubble shape move more noticeably.
 */
uniform float wobble_strength : hint_range(0.0, 0.05, 0.001) = 0.012;


group_uniforms Distortion;

/**
 * Internal distortion speed in cycles per second.
 * Higher values make the inner surface movement faster.
 */
uniform float distortion_speed : hint_range(0.0, 5.0, 0.01) = 0.8;

/**
 * Internal distortion strength.
 * Higher values create stronger refraction-like movement.
 */
uniform float distortion_strength : hint_range(0.0, 0.05, 0.001) = 0.008;


group_uniforms Rim;

/**
 * Edge rim brightness.
 * Higher values make the bubble edge more visible.
 */
uniform float rim_strength : hint_range(0.0, 1.0, 0.01) = 0.18;

/**
 * Controls how tightly the rim is concentrated near the edge.
 * Higher values produce a thinner and sharper rim.
 */
uniform float rim_power : hint_range(0.1, 10.0, 0.1) = 2.5;


group_uniforms Highlight;

/**
 * Enables or disables the moving highlight.
 * Disable this for objects that rotate continuously.
 */
uniform bool highlight_enabled = true;

/**
 * Highlight brightness.
 * Higher values make the reflection more visible.
 */
uniform float highlight_strength : hint_range(0.0, 1.0, 0.01) = 0.22;

/**
 * Highlight size.
 * Higher values make the reflection larger and softer.
 */
uniform float highlight_size : hint_range(0.01, 1.0, 0.01) = 0.18;

/**
 * Highlight movement speed in cycles per second.
 * Higher values make the reflection move faster.
 */
uniform float highlight_speed : hint_range(0.0, 2.0, 0.01) = 0.25;

/**
 * Base position of the highlight in local UV space.
 */
uniform vec2 highlight_position = vec2(-0.22, -0.22);


void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float distance_from_center = length(centered_uv) * 2.0;
	float edge_factor = smoothstep(0.2, 1.0, distance_from_center);

	float time = TIME;

	float breathing_phase = instance_seed;
	float wobble_phase = instance_seed * 1.73;
	float distortion_phase = instance_seed * 2.41;
	float highlight_phase = instance_seed * 3.17;

	// Breathing.
	float breathing = sin(
		time * breathing_speed * TAU + breathing_phase
	) * breathing_strength;

	// Organic wobble.
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

	// Internal distortion.
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

	// Radial breathing.
	centered_uv *= 1.0 - breathing;

	vec2 distorted_uv = centered_uv + vec2(0.5);
	vec4 tex = texture(TEXTURE, distorted_uv);

	// Edge rim.
	float rim = pow(
		clamp(edge_factor, 0.0, 1.0),
		rim_power
	);

	// Moving highlight.
	float shine = 0.0;

	if (highlight_enabled) {
		vec2 animated_highlight = highlight_position;

		animated_highlight.x += sin(
			time * highlight_speed * TAU + highlight_phase
		) * 0.04;

		animated_highlight.y += cos(
			time * highlight_speed * 0.7 * TAU + highlight_phase
		) * 0.025;

		float highlight_distance = distance(
			centered_uv,
			animated_highlight
		);

		shine = 1.0 - smoothstep(
			highlight_size * 0.5,
			highlight_size,
			highlight_distance
		);

		shine *= highlight_strength;
	}

	float glow = rim * rim_strength;

	vec3 final_color = tex.rgb;
	final_color += vec3(glow);
	final_color += vec3(shine);

	COLOR = vec4(final_color, tex.a);
}
