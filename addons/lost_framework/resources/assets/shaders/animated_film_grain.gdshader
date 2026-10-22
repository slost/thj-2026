shader_type canvas_item;

// Uniforms
uniform sampler2D screen_texture : hint_screen_texture;
uniform float grain_amount : hint_range(0.0, 1.0) = 0.05; // Adjust the amount of grain
uniform float grain_size : hint_range(0.1, 10.0) = 1.0; // Adjust the size of the grain
uniform float speed : hint_range(0.1, 10.0) = 1.0; // Control how fast the grain animates

void fragment() {
    // Sample the original screen texture
    vec4 original_color = texture(screen_texture, SCREEN_UV);

    // Get the current time value
    float time = TIME * speed; // TIME is a built-in Godot uniform

    // Combine UV and time for an animated noise
    // The addition of 'time' makes the noise pattern constantly change (flicker/move)
    float noise = (fract(sin(dot(UV * grain_size, vec2(12.9898, 78.233) * time)) * 43758.5453) - 0.5) * 2.0;

    // Add noise to the original color
    original_color.rgb += noise * grain_amount;

    // Clamp the final color to make sure it stays in the valid range
    COLOR = clamp(original_color, 0.0, 1.0);
}