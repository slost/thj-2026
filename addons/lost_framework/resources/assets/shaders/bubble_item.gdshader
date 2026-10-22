shader_type canvas_item;


group_uniforms Instance;

/**
 * Phase offset for this item.
 * Use a different value for each instance to prevent synchronized motion.
 */
instance uniform float instance_seed = 0.0;


group_uniforms Blur;

/**
 * Blur radius in pixels.
 * Higher values make the item softer and less defined.
 */
uniform float blur_radius : hint_range(0.0, 4.0, 0.1) = 1.5;


group_uniforms Floating;

/**
 * Floating movement speed in cycles per second.
 * Higher values make the item move faster.
 */
uniform float float_speed : hint_range(0.0, 5.0, 0.01) = 0.7;

/**
 * Vertical floating distance in pixels.
 * Higher values make the item move farther up and down.
 */
uniform float float_height : hint_range(0.0, 8.0, 0.1) = 2.0;

/**
 * Horizontal drifting distance in pixels.
 * Higher values create more side-to-side movement.
 */
uniform float float_width : hint_range(0.0, 8.0, 0.1) = 0.75;

/**
 * Secondary movement speed multiplier.
 * Controls how quickly the horizontal drift changes direction.
 */
uniform float drift_speed : hint_range(0.0, 3.0, 0.01) = 0.6;


group_uniforms Distortion;

/**
 * Subtle UV distortion strength.
 * Higher values make the item appear to move softly inside the bubble.
 */
uniform float distortion_strength : hint_range(0.0, 0.05, 0.001) = 0.006;

/**
 * Distortion animation speed in cycles per second.
 * Higher values make the internal movement faster.
 */
uniform float distortion_speed : hint_range(0.0, 5.0, 0.01) = 0.5;


group_uniforms Opacity;

/**
 * Minimum opacity multiplier.
 * Lower values make the item appear more faded.
 */
uniform float min_opacity : hint_range(0.0, 1.0, 0.01) = 0.82;

/**
 * Opacity breathing strength.
 * Higher values make the item fade in and out more noticeably.
 */
uniform float opacity_strength : hint_range(0.0, 0.5, 0.01) = 0.06;


void vertex() {
	float time = TIME;

	float vertical_motion = sin(
		time * float_speed * TAU + instance_seed
	) * float_height;

	float horizontal_motion = sin(
		time * drift_speed * TAU + instance_seed * 1.73
	) * float_width;

	VERTEX += vec2(
		horizontal_motion,
		vertical_motion
	);
}


void fragment() {
	float time = TIME;

	float distortion_x = sin(
		UV.y * 10.0 +
		time * distortion_speed * TAU +
		instance_seed
	) * distortion_strength;

	float distortion_y = cos(
		UV.x * 8.0 +
		time * distortion_speed * 0.8 * TAU +
		instance_seed * 1.37
	) * distortion_strength;

	vec2 distorted_uv = UV + vec2(
		distortion_x,
		distortion_y
	);

	vec4 color;

	if (blur_radius <= 0.0) {
		color = texture(TEXTURE, distorted_uv);
	} else {
		vec2 offset = TEXTURE_PIXEL_SIZE * blur_radius;

		color = texture(TEXTURE, distorted_uv);

		color += texture(
			TEXTURE,
			distorted_uv + vec2(offset.x, 0.0)
		);

		color += texture(
			TEXTURE,
			distorted_uv - vec2(offset.x, 0.0)
		);

		color += texture(
			TEXTURE,
			distorted_uv + vec2(0.0, offset.y)
		);

		color += texture(
			TEXTURE,
			distorted_uv - vec2(0.0, offset.y)
		);

		color += texture(
			TEXTURE,
			distorted_uv + offset
		);

		color += texture(
			TEXTURE,
			distorted_uv - offset
		);

		color += texture(
			TEXTURE,
			distorted_uv + vec2(offset.x, -offset.y)
		);

		color += texture(
			TEXTURE,
			distorted_uv + vec2(-offset.x, offset.y)
		);

		color /= 9.0;
	}

	float opacity = mix(
		min_opacity,
		1.0,
		0.5 + sin(
			time * float_speed * TAU +
			instance_seed * 2.17
		) * 0.5
	);

	opacity = mix(
		1.0,
		opacity,
		opacity_strength
	);

	color.a *= opacity;

	COLOR = color;
}
